// MARK: - Location & Weather Services
// Production Runner - Call Sheet Module
// Services for fetching nearest hospital and weather data

import Foundation
import CoreLocation
import MapKit

// MARK: - Hospital Result

struct HospitalResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let phone: String
    let distance: Double // in miles
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Weather Result

struct WeatherResult {
    let high: String
    let low: String
    let conditions: String
    let humidity: String
    let windSpeed: String
    let sunrise: String
    let sunset: String
}

// MARK: - Location Weather Service

class LocationWeatherService: ObservableObject {
    static let shared = LocationWeatherService()

    @Published var isLoadingHospital = false
    @Published var isLoadingWeather = false
    @Published var hospitalError: String?
    @Published var weatherError: String?

    private let geocoder = CLGeocoder()

    private init() {}

    // MARK: - Find Nearest Hospital using Apple MapKit

    func findNearestHospital(
        latitude: Double,
        longitude: Double,
        completion: @escaping (HospitalResult?) -> Void
    ) {
        isLoadingHospital = true
        hospitalError = nil

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 50000, // 50km search radius
            longitudinalMeters: 50000
        )

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "hospital emergency room"
        request.region = region
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isLoadingHospital = false

                if let error = error {
                    self?.hospitalError = error.localizedDescription
                    completion(nil)
                    return
                }

                guard let response = response, let firstItem = response.mapItems.first else {
                    self?.hospitalError = "No hospitals found nearby"
                    completion(nil)
                    return
                }

                // Calculate distance
                let locationA = CLLocation(latitude: latitude, longitude: longitude)
                let locationB = CLLocation(
                    latitude: firstItem.placemark.coordinate.latitude,
                    longitude: firstItem.placemark.coordinate.longitude
                )
                let distanceMeters = locationA.distance(from: locationB)
                let distanceMiles = distanceMeters / 1609.34

                // Format address
                let placemark = firstItem.placemark
                var addressComponents: [String] = []
                if let street = placemark.thoroughfare {
                    if let number = placemark.subThoroughfare {
                        addressComponents.append("\(number) \(street)")
                    } else {
                        addressComponents.append(street)
                    }
                }
                if let city = placemark.locality {
                    addressComponents.append(city)
                }
                if let state = placemark.administrativeArea {
                    addressComponents.append(state)
                }
                if let zip = placemark.postalCode {
                    addressComponents.append(zip)
                }

                let result = HospitalResult(
                    name: firstItem.name ?? "Hospital",
                    address: addressComponents.joined(separator: ", "),
                    phone: firstItem.phoneNumber ?? "",
                    distance: distanceMiles,
                    coordinate: firstItem.placemark.coordinate
                )

                completion(result)
            }
        }
    }

    // MARK: - Find Nearest Hospital from Address

    func findNearestHospital(
        address: String,
        completion: @escaping (HospitalResult?) -> Void
    ) {
        guard !address.isEmpty else {
            hospitalError = "No address provided"
            completion(nil)
            return
        }

        isLoadingHospital = true
        hospitalError = nil

        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoadingHospital = false
                    self?.hospitalError = "Could not geocode address: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                DispatchQueue.main.async {
                    self?.isLoadingHospital = false
                    self?.hospitalError = "Could not find location for address"
                    completion(nil)
                }
                return
            }

            self?.findNearestHospital(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                completion: completion
            )
        }
    }

    // MARK: - Fetch Weather using Open-Meteo (free, no API key required)

    func fetchWeather(
        latitude: Double,
        longitude: Double,
        date: Date,
        completion: @escaping (WeatherResult?) -> Void
    ) {
        isLoadingWeather = true
        weatherError = nil

        // Format date for API
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        // Open-Meteo API (free, no key required)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&daily=temperature_2m_max,temperature_2m_min,weathercode,sunrise,sunset&hourly=relativehumidity_2m,windspeed_10m&temperature_unit=fahrenheit&windspeed_unit=mph&timezone=auto&start_date=\(dateString)&end_date=\(dateString)"

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isLoadingWeather = false
                self.weatherError = "Invalid URL"
                completion(nil)
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoadingWeather = false

                if let error = error {
                    self?.weatherError = error.localizedDescription
                    completion(nil)
                    return
                }

                guard let data = data else {
                    self?.weatherError = "No data received"
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let daily = json["daily"] as? [String: Any],
                       let hourly = json["hourly"] as? [String: Any] {

                        // Extract daily data
                        let highTemp = (daily["temperature_2m_max"] as? [Double])?.first ?? 0
                        let lowTemp = (daily["temperature_2m_min"] as? [Double])?.first ?? 0
                        let weatherCode = (daily["weathercode"] as? [Int])?.first ?? 0
                        let sunriseStr = (daily["sunrise"] as? [String])?.first ?? ""
                        let sunsetStr = (daily["sunset"] as? [String])?.first ?? ""

                        // Extract hourly averages (use noon values)
                        let humidities = hourly["relativehumidity_2m"] as? [Int] ?? []
                        let windSpeeds = hourly["windspeed_10m"] as? [Double] ?? []

                        // Get noon values (index 12) or average
                        let humidity = humidities.count > 12 ? humidities[12] : (humidities.first ?? 0)
                        let windSpeed = windSpeeds.count > 12 ? windSpeeds[12] : (windSpeeds.first ?? 0)

                        // Format sunrise/sunset times
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                        let outputFormatter = DateFormatter()
                        outputFormatter.dateFormat = "h:mm a"

                        var sunriseFormatted = ""
                        var sunsetFormatted = ""

                        if let sunriseDate = timeFormatter.date(from: sunriseStr) {
                            sunriseFormatted = outputFormatter.string(from: sunriseDate)
                        }
                        if let sunsetDate = timeFormatter.date(from: sunsetStr) {
                            sunsetFormatted = outputFormatter.string(from: sunsetDate)
                        }

                        let result = WeatherResult(
                            high: "\(Int(round(highTemp)))°F",
                            low: "\(Int(round(lowTemp)))°F",
                            conditions: self?.weatherCodeToCondition(weatherCode) ?? "Unknown",
                            humidity: "\(humidity)%",
                            windSpeed: "\(Int(round(windSpeed))) mph",
                            sunrise: sunriseFormatted,
                            sunset: sunsetFormatted
                        )

                        completion(result)
                    } else {
                        self?.weatherError = "Could not parse weather data"
                        completion(nil)
                    }
                } catch {
                    self?.weatherError = "JSON parsing error: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }.resume()
    }

    // MARK: - Fetch Weather from Address

    func fetchWeather(
        address: String,
        date: Date,
        completion: @escaping (WeatherResult?) -> Void
    ) {
        guard !address.isEmpty else {
            weatherError = "No address provided"
            completion(nil)
            return
        }

        isLoadingWeather = true
        weatherError = nil

        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoadingWeather = false
                    self?.weatherError = "Could not geocode address: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                DispatchQueue.main.async {
                    self?.isLoadingWeather = false
                    self?.weatherError = "Could not find location for address"
                    completion(nil)
                }
                return
            }

            self?.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                date: date,
                completion: completion
            )
        }
    }

    // MARK: - Weather Code to Condition String

    private func weatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }
}
