import SwiftUI

struct ProjectCardView: View {
    let status: ProjectStatus
    let title: String
    let user: String?
    let role: String
    let modified: Date?

    let isSelected: Bool

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                if #available(macOS 13.0, *) {
                    Image(systemName: status.icon).font(.title2).bold()
                } else {
                    // Fallback on earlier versions
                }
                Text(title.uppercased()).font(.headline).bold()
            }
            .foregroundColor(.white)
            .padding(.leading, 16)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack { Text("User:").bold(); Text(user ?? "—") }
                HStack { Text("Role:").bold(); Text(role) }
                HStack { Text("Modified:").bold(); Text(formatted(modified)) }
            }
            .font(.caption).foregroundColor(.white)
            .padding(.trailing, 16)
        }
        .frame(width: 520, height: 72)
        .background(status.color.opacity(isSelected ? 0.85 : 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
    }

    private func formatted(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: d)
    }
}
