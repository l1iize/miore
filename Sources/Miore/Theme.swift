import SwiftUI

enum MioreTheme {
    static var backgroundHex: String { LocalConfigStore.shared.string(forKey: "homeBackgroundHex") ?? "#070708" }
    static var accentHex: String { LocalConfigStore.shared.string(forKey: "homeAccentHex") ?? "#FFFFFF" }
    static var background: Color { Color(hex: backgroundHex) }
    static var accent: Color { Color(hex: accentHex) }
    static var isLightBackground: Bool { isLight(hex: backgroundHex) }
    static var foreground: Color { isLightBackground ? .black : .white }
    static var colorScheme: ColorScheme { isLightBackground ? .light : .dark }
    static var surface: Color { foreground.opacity(0.055) }
    static var field: Color { foreground.opacity(0.065) }
    static var border: Color { foreground.opacity(0.18) }
    static var muted: Color { foreground.opacity(0.62) }
    static var subtle: Color { foreground.opacity(0.40) }

    static var glassSurface: Color { foreground.opacity(0.03) }
    static var glassStroke: Color { foreground.opacity(0.12) }
    static var glowAccent: Color { accent.opacity(0.15) }

    static func contrastText(for color: Color) -> Color {
        guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return .black }
        let luminance = 0.2126 * ns.redComponent + 0.7152 * ns.greenComponent + 0.0722 * ns.blueComponent
        return luminance > 0.56 ? .black : .white
    }

    private static func isLight(hex: String) -> Bool {
        let value = Color(hex: hex)
        guard let ns = NSColor(value).usingColorSpace(.deviceRGB) else { return false }
        return 0.2126 * ns.redComponent + 0.7152 * ns.greenComponent + 0.0722 * ns.blueComponent > 0.56
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(MioreTheme.border).frame(height: 1) }
}

struct SectionTitle: View {
    let kicker: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker.uppercased()).font(.miore(size: 10, weight: .medium, design: .monospaced)).tracking(1.7).foregroundColor(MioreTheme.muted)
            Text(title).font(.miore(size: 30, weight: .medium, design: .default)).tracking(-1)
            Text(detail).font(.miore(size: 13)).foregroundColor(MioreTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct Panel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MioreTheme.foreground.opacity(0.02))

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MioreTheme.foreground.opacity(0.12),
                                    MioreTheme.foreground.opacity(0.04),
                                    MioreTheme.foreground.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            MioreTheme.accent.opacity(0.05),
                                            .clear
                                        ],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 300
                                    )
                                )
                        )

                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    MioreTheme.glassStroke.opacity(0.9),
                                    MioreTheme.glassStroke.opacity(0.2),
                                    MioreTheme.glassStroke.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var compact = false
    var color: Color = MioreTheme.accent
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.miore(size: compact ? 12 : 13, weight: .semibold))
            .foregroundColor(MioreTheme.contrastText(for: color))
            .padding(.horizontal, compact ? 16 : 32)
            .frame(height: compact ? 36 : 46)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.25),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                color.opacity(0.8),
                                color.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: configuration.isPressed ? 2 : 1.5
                    )
            )
            .shadow(color: color.opacity(isHovered ? 0.28 : 0.12), radius: isHovered ? 9 : 5, x: 0, y: isHovered ? 3 : 2)
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct GhostButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.miore(size: 12, weight: .medium))
            .foregroundColor(MioreTheme.foreground.opacity(configuration.isPressed ? 0.55 : (isHovered ? 0.95 : 0.9)))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(configuration.isPressed ? MioreTheme.foreground.opacity(0.08) : (isHovered ? MioreTheme.glassSurface : .clear))
                    if isHovered && !configuration.isPressed {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MioreTheme.foreground.opacity(0.05),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                MioreTheme.border.opacity(isHovered ? 0.6 : 0.4),
                                MioreTheme.border.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    let hint: String?
    let content: Content
    init(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label; self.hint = hint; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.miore(size: 11, weight: .medium)).foregroundColor(MioreTheme.foreground.opacity(0.84))
            content
            if let hint { Text(hint).font(.miore(size: 10)).foregroundColor(MioreTheme.subtle) }
        }
    }
}

extension View {
    func mioreTextField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.miore(size: 12, design: .monospaced))
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(MioreTheme.field)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MioreTheme.foreground.opacity(0.02),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                MioreTheme.border.opacity(0.5),
                                MioreTheme.border
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        if cleaned.count == 6 {
            self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
        } else {
            self = .white
        }
    }

    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}
