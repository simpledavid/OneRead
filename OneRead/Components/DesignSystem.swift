import SwiftUI
import UIKit

/// Resolve a light/dark pair at render time so the app follows the chosen
/// appearance (System / Light / Dark).
private func adaptive(
    light: (Double, Double, Double, Double),
    dark: (Double, Double, Double, Double)
) -> Color {
    Color(uiColor: UIColor { trait in
        let c = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
    })
}

enum Palette {
    static let background = adaptive(light: (0.960, 0.962, 0.972, 1), dark: (0.045, 0.049, 0.062, 1))
    static let surface = adaptive(light: (1.000, 1.000, 1.000, 1), dark: (0.097, 0.107, 0.132, 1))
    static let surfaceRaised = adaptive(light: (0.929, 0.933, 0.945, 1), dark: (0.116, 0.126, 0.155, 1))
    static let ink = adaptive(light: (0.105, 0.115, 0.135, 1), dark: (0.955, 0.960, 0.972, 1))
    static let muted = adaptive(light: (0.420, 0.445, 0.495, 1), dark: (0.620, 0.640, 0.690, 1))
    static let border = adaptive(light: (0.855, 0.865, 0.895, 1), dark: (0.165, 0.185, 0.235, 1))
    static let accent = Color(red: 1.000, green: 0.390, blue: 0.070)
    static let accentSoft = Color(red: 1.000, green: 0.390, blue: 0.070).opacity(0.16)
    static let amber = Color(red: 1.000, green: 0.660, blue: 0.220)
    static let blue = Color(red: 0.310, green: 0.610, blue: 1.000)
    static let glass = adaptive(light: (0, 0, 0, 0.05), dark: (1, 1, 1, 0.075))
    static let glassStrong = adaptive(light: (0, 0, 0, 0.08), dark: (1, 1, 1, 0.125))
}

enum Spacing {
    static let page: CGFloat = 20
    static let cardRadius: CGFloat = 8
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system: return "Follow your device appearance"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Spacing.cardRadius, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 10)
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}

struct IconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .foregroundStyle(Palette.ink)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
    }
}

struct LensBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                adaptive(light: (0.975, 0.977, 0.985, 1), dark: (0.040, 0.044, 0.056, 1)),
                adaptive(light: (0.955, 0.958, 0.970, 1), dark: (0.050, 0.056, 0.072, 1)),
                Palette.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
