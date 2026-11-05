import FeniceCore
import SwiftUI

extension Color {
    /// fiamma del sito La Fenice
    static let fenice = Color(red: 226 / 255, green: 83 / 255, blue: 29 / 255)
    static let feniceDeep = Color(red: 184 / 255, green: 57 / 255, blue: 15 / 255)
    static let night = Color(red: 0.11, green: 0.08, blue: 0.10)
}

struct AvatarView: View {
    let user: User
    var size: CGFloat = 28

    var body: some View {
        Text(user.initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
    }

    private var color: Color {
        switch user.role {
        case .student: return .fenice
        case .tutor: return .indigo
        case .admin: return .teal
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

extension BookingStatus {
    var color: Color {
        switch self {
        case .confirmed: return .blue
        case .completed: return .green
        case .cancelled: return .secondary
        }
    }
}

extension CancellationStatus {
    var color: Color {
        switch self {
        case .pending: return .orange
        case .forwarded: return .purple
        case .approved: return .green
        case .rejected: return .red
        case .expired: return .secondary
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 6, y: 2)
            .padding(.bottom, 24)
    }
}

struct PlaceholderView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer", description: Text("Ci sto lavorando."))
    }
}
