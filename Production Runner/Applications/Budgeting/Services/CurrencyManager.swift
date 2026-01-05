import Foundation
import Combine

/// Manages multi-currency support including conversion rates and formatting
final class CurrencyManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var baseCurrency: String = "USD"
    @Published private(set) var availableCurrencies: [CurrencyInfo] = []
    @Published private(set) var exchangeRates: [String: Double] = [:]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private Properties

    private let storageKey = "budgetCurrencySettings"
    private let ratesStorageKey = "budgetExchangeRates"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadSettings()
        loadCachedRates()
        setupAvailableCurrencies()
    }

    // MARK: - Currency Configuration

    private func setupAvailableCurrencies() {
        // Common currencies for film production
        availableCurrencies = [
            CurrencyInfo(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸"),
            CurrencyInfo(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺"),
            CurrencyInfo(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧"),
            CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "C$", flag: "🇨🇦"),
            CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺"),
            CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
            CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
            CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳"),
            CurrencyInfo(code: "MXN", name: "Mexican Peso", symbol: "$", flag: "🇲🇽"),
            CurrencyInfo(code: "BRL", name: "Brazilian Real", symbol: "R$", flag: "🇧🇷"),
            CurrencyInfo(code: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷"),
            CurrencyInfo(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "🇳🇿"),
            CurrencyInfo(code: "CHF", name: "Swiss Franc", symbol: "CHF", flag: "🇨🇭"),
            CurrencyInfo(code: "SEK", name: "Swedish Krona", symbol: "kr", flag: "🇸🇪"),
            CurrencyInfo(code: "NOK", name: "Norwegian Krone", symbol: "kr", flag: "🇳🇴"),
            CurrencyInfo(code: "DKK", name: "Danish Krone", symbol: "kr", flag: "🇩🇰"),
            CurrencyInfo(code: "ZAR", name: "South African Rand", symbol: "R", flag: "🇿🇦"),
            CurrencyInfo(code: "AED", name: "UAE Dirham", symbol: "د.إ", flag: "🇦🇪"),
            CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
            CurrencyInfo(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$", flag: "🇭🇰")
        ]

        // Set default rates (USD as base = 1.0)
        if exchangeRates.isEmpty {
            exchangeRates = [
                "USD": 1.0,
                "EUR": 0.92,
                "GBP": 0.79,
                "CAD": 1.36,
                "AUD": 1.53,
                "JPY": 149.50,
                "CNY": 7.24,
                "INR": 83.12,
                "MXN": 17.15,
                "BRL": 4.97,
                "KRW": 1325.0,
                "NZD": 1.64,
                "CHF": 0.88,
                "SEK": 10.42,
                "NOK": 10.65,
                "DKK": 6.87,
                "ZAR": 18.75,
                "AED": 3.67,
                "SGD": 1.34,
                "HKD": 7.82
            ]
        }
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONDecoder().decode(CurrencySettings.self, from: data) {
            baseCurrency = settings.baseCurrency
        }
    }

    func saveSettings() {
        let settings = CurrencySettings(baseCurrency: baseCurrency)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadCachedRates() {
        if let data = UserDefaults.standard.data(forKey: ratesStorageKey),
           let cached = try? JSONDecoder().decode(CachedRates.self, from: data) {
            exchangeRates = cached.rates
            lastUpdated = cached.timestamp
        }
    }

    private func cacheRates() {
        let cached = CachedRates(rates: exchangeRates, timestamp: Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: ratesStorageKey)
        }
    }

    // MARK: - Currency Operations

    /// Set the base currency for the budget
    func setBaseCurrency(_ code: String) {
        guard availableCurrencies.contains(where: { $0.code == code }) else {
            BudgetLogger.warning("Invalid currency code: \(code)", category: BudgetLogger.general)
            return
        }

        baseCurrency = code
        saveSettings()
        BudgetLogger.info("Base currency set to \(code)", category: BudgetLogger.general)
    }

    /// Convert amount from one currency to another
    func convert(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double {
        guard let sourceRate = exchangeRates[sourceCurrency],
              let targetRate = exchangeRates[targetCurrency],
              sourceRate > 0 else {
            BudgetLogger.warning("Missing exchange rate for \(sourceCurrency) or \(targetCurrency)", category: BudgetLogger.calculation)
            return amount
        }

        // Convert to USD (base), then to target
        let usdAmount = amount / sourceRate
        return usdAmount * targetRate
    }

    /// Convert amount to base currency
    func convertToBase(_ amount: Double, from sourceCurrency: String) -> Double {
        return convert(amount, from: sourceCurrency, to: baseCurrency)
    }

    /// Convert amount from base currency
    func convertFromBase(_ amount: Double, to targetCurrency: String) -> Double {
        return convert(amount, from: baseCurrency, to: targetCurrency)
    }

    // MARK: - Formatting

    /// Format amount in specified currency
    func format(_ amount: Double, currency: String? = nil) -> String {
        let currencyCode = currency ?? baseCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(amount)"
    }

    /// Format amount with conversion indicator
    func formatWithConversion(_ amount: Double, from sourceCurrency: String, to targetCurrency: String? = nil) -> String {
        let target = targetCurrency ?? baseCurrency

        if sourceCurrency == target {
            return format(amount, currency: target)
        }

        let converted = convert(amount, from: sourceCurrency, to: target)
        return "\(format(converted, currency: target)) (\(format(amount, currency: sourceCurrency)))"
    }

    /// Get currency symbol
    func symbol(for code: String) -> String {
        availableCurrencies.first { $0.code == code }?.symbol ?? code
    }

    /// Get currency info
    func currencyInfo(for code: String) -> CurrencyInfo? {
        availableCurrencies.first { $0.code == code }
    }

    // MARK: - Rate Management

    /// Manually update an exchange rate
    func updateRate(for currency: String, rate: Double) {
        guard rate > 0 else {
            BudgetLogger.warning("Invalid exchange rate: \(rate)", category: BudgetLogger.calculation)
            return
        }

        exchangeRates[currency] = rate
        lastUpdated = Date()
        cacheRates()

        BudgetLogger.info("Updated \(currency) rate to \(rate)", category: BudgetLogger.calculation)
    }

    /// Update multiple rates at once
    func updateRates(_ rates: [String: Double]) {
        for (currency, rate) in rates where rate > 0 {
            exchangeRates[currency] = rate
        }
        lastUpdated = Date()
        cacheRates()

        BudgetLogger.info("Updated \(rates.count) exchange rates", category: BudgetLogger.calculation)
    }

    /// Get the exchange rate between two currencies
    func getRate(from sourceCurrency: String, to targetCurrency: String) -> Double? {
        guard let sourceRate = exchangeRates[sourceCurrency],
              let targetRate = exchangeRates[targetCurrency],
              sourceRate > 0 else {
            return nil
        }

        return targetRate / sourceRate
    }
}

// MARK: - Supporting Types

struct CurrencyInfo: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let symbol: String
    let flag: String

    var id: String { code }

    var displayName: String {
        "\(flag) \(code) - \(name)"
    }
}

struct CurrencySettings: Codable {
    let baseCurrency: String
}

struct CachedRates: Codable {
    let rates: [String: Double]
    let timestamp: Date
}

// MARK: - Currency Extension for Double

extension Double {
    /// Format as currency with specified currency code
    func asCurrency(code: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }

    /// Format with currency manager
    func formatted(using manager: CurrencyManager) -> String {
        manager.format(self)
    }
}
