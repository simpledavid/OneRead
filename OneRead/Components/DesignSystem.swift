import SwiftUI

enum Palette {
    static let background = Color(red: 0.045, green: 0.049, blue: 0.062)
    static let surface = Color(red: 0.097, green: 0.107, blue: 0.132)
    static let surfaceRaised = Color(red: 0.116, green: 0.126, blue: 0.155)
    static let ink = Color(red: 0.955, green: 0.960, blue: 0.972)
    static let muted = Color(red: 0.620, green: 0.640, blue: 0.690)
    static let border = Color(red: 0.165, green: 0.185, blue: 0.235)
    static let accent = Color(red: 1.000, green: 0.390, blue: 0.070)
    static let accentSoft = Color(red: 1.000, green: 0.390, blue: 0.070).opacity(0.16)
    static let amber = Color(red: 1.000, green: 0.660, blue: 0.220)
    static let blue = Color(red: 0.310, green: 0.610, blue: 1.000)
    static let glass = Color.white.opacity(0.075)
    static let glassStrong = Color.white.opacity(0.125)
}

enum Spacing {
    static let page: CGFloat = 20
    static let cardRadius: CGFloat = 8
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
                Color(red: 0.040, green: 0.044, blue: 0.056),
                Color(red: 0.050, green: 0.056, blue: 0.072),
                Palette.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
