import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var account: MicrosoftAccountService
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var ai: AIService
    @ObservedObject private var launcher: MinecraftLauncher
    @ObservedObject private var javaRuntimes: JavaRuntimeService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        self.account = model.account
        self.settings = model.settings
        self.ai = model.ai
        self.launcher = model.launcher
        self.javaRuntimes = model.javaRuntimes
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = AdaptiveHomeLayout(
                size: proxy.size,
                profileSize: CGSize(width: settings.homeProfileWidth, height: settings.homeProfileHeight),
                clockSize: CGSize(width: settings.homeClockWidth, height: settings.homeClockHeight),
                instanceSize: CGSize(width: settings.homeInstanceWidgetWidth, height: settings.homeInstanceWidgetHeight),
                runtimeSize: CGSize(width: settings.homeRuntimeWidgetWidth, height: settings.homeRuntimeWidgetHeight)
            )
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: settings.homeBackgroundHex),
                        Color(hex: settings.homeBackgroundHex).opacity(0.85),
                        Color(hex: settings.homeBackgroundHex)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                AmbientGlow(color: Color(hex: settings.homeAccentHex), size: proxy.size)
                    .allowsHitTesting(false)

                if !reduceMotion {
                    ScanlineOverlay()
                        .opacity(0.035)
                        .allowsHitTesting(false)
                }

                if model.editingHome {
                    HomeAlignmentGrid()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if settings.showHomeProfile {
                    DraggableHomeItem(
                        x: adaptiveBinding($settings.homeProfileX, layout.profile.x, amount: layout.adaptation),
                        y: adaptiveBinding($settings.homeProfileY, layout.profile.y, amount: layout.adaptation),
                        width: adaptiveBinding($settings.homeProfileWidth, layout.profileSize.width, amount: layout.adaptation),
                        height: adaptiveBinding($settings.homeProfileHeight, layout.profileSize.height, amount: layout.adaptation),
                        size: proxy.size, enabled: model.editingHome,
                        onRemove: { settings.showHomeProfile = false }
                    ) { profileReadout }
                }
                if settings.showHomeClock {
                    DraggableHomeItem(
                        x: adaptiveBinding($settings.homeClockX, layout.clock.x, amount: layout.adaptation),
                        y: adaptiveBinding($settings.homeClockY, layout.clock.y, amount: layout.adaptation),
                        width: adaptiveBinding($settings.homeClockWidth, layout.clockSize.width, amount: layout.adaptation),
                        height: adaptiveBinding($settings.homeClockHeight, layout.clockSize.height, amount: layout.adaptation),
                        size: proxy.size, enabled: model.editingHome,
                        onRemove: { settings.showHomeClock = false }
                    ) { HomeClockWidget(accent: Color(hex: settings.homeAccentHex)) }
                }
                if settings.showHomeInstanceWidget {
                    DraggableHomeItem(
                        x: adaptiveBinding($settings.homeInstanceWidgetX, layout.instance.x, amount: layout.adaptation),
                        y: adaptiveBinding($settings.homeInstanceWidgetY, layout.instance.y, amount: layout.adaptation),
                        width: adaptiveBinding($settings.homeInstanceWidgetWidth, layout.instanceSize.width, amount: layout.adaptation),
                        height: adaptiveBinding($settings.homeInstanceWidgetHeight, layout.instanceSize.height, amount: layout.adaptation),
                        size: proxy.size, enabled: model.editingHome,
                        onRemove: { settings.showHomeInstanceWidget = false }
                    ) { InstanceWidget(instance: model.selectedInstance, count: model.instances.count, accent: Color(hex: settings.homeAccentHex)) }
                }
                if settings.showHomeRuntimeWidget {
                    DraggableHomeItem(
                        x: adaptiveBinding($settings.homeRuntimeWidgetX, layout.runtime.x, amount: layout.adaptation),
                        y: adaptiveBinding($settings.homeRuntimeWidgetY, layout.runtime.y, amount: layout.adaptation),
                        width: adaptiveBinding($settings.homeRuntimeWidgetWidth, layout.runtimeSize.width, amount: layout.adaptation),
                        height: adaptiveBinding($settings.homeRuntimeWidgetHeight, layout.runtimeSize.height, amount: layout.adaptation),
                        size: proxy.size, enabled: model.editingHome,
                        onRemove: { settings.showHomeRuntimeWidget = false }
                    ) {
                        RuntimeWidget(
                            runtime: javaRuntimes.runtimes.first(where: { $0.path == settings.javaPath }),
                            requiredJava: JavaRuntimeService.requiredMajor(for: model.selectedInstance?.gameVersion),
                            memoryMB: Int(settings.memoryMB),
                            accent: Color(hex: settings.homeAccentHex)
                        )
                    }
                }
                DraggableHomeItem(
                    x: adaptiveBinding($settings.homeGreetingX, layout.greeting.x, amount: layout.adaptation),
                    y: adaptiveBinding($settings.homeGreetingY, layout.greeting.y, amount: layout.adaptation),
                    size: proxy.size,
                    enabled: model.editingHome
                ) {
                    greeting
                        .frame(width: layout.greetingWidth, height: layout.compact ? 36 : 48)
                        .clipped()
                }
                DraggableHomeItem(
                    x: adaptiveBinding($settings.homeLogoX, layout.logo.x, amount: layout.adaptation),
                    y: adaptiveBinding($settings.homeLogoY, layout.logo.y, amount: layout.adaptation),
                    size: proxy.size,
                    enabled: model.editingHome
                ) {
                    let accent = Color(hex: settings.homeAccentHex)
                    GlitchBlock(loader: model.selectedInstance?.loader ?? .vanilla, animated: !reduceMotion && !model.editingHome, accent: accent)
                        .frame(width: layout.logoSize, height: layout.logoSize)
                        .background {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [accent.opacity(0.16), accent.opacity(0.045), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: layout.logoSize * 0.66
                                    )
                                )
                                .frame(width: layout.logoSize * 1.42, height: layout.logoSize * 1.42)
                                .allowsHitTesting(false)
                        }
                }
                DraggableHomeItem(
                    x: adaptiveBinding($settings.homeBrandX, layout.brand.x, amount: layout.adaptation),
                    y: adaptiveBinding($settings.homeBrandY, layout.brand.y, amount: layout.adaptation),
                    size: proxy.size,
                    enabled: model.editingHome
                ) {
                    Text("MIORE // HOME")
                        .font(.miore(size: 9, weight: .medium, design: .monospaced))
                        .tracking(3.2)
                        .foregroundColor(Color(hex: settings.homeAccentHex).opacity(0.8))
                        .frame(width: layout.centerWidth, height: 24)
                }
                DraggableHomeItem(
                    x: adaptiveBinding($settings.homeVersionX, layout.version.x, amount: layout.adaptation),
                    y: adaptiveBinding($settings.homeVersionY, layout.version.y, amount: layout.adaptation),
                    size: proxy.size,
                    enabled: model.editingHome
                ) {
                    HomeVersionPicker(
                        selection: Binding(get: { model.selectedInstanceID ?? "" }, set: { model.selectInstance($0) }),
                        instances: model.instances,
                        accent: Color(hex: settings.homeAccentHex),
                        width: layout.centerWidth,
                        compact: layout.compact
                    )
                }
                DraggableHomeItem(
                    x: adaptiveBinding($settings.homeLaunchX, layout.launch.x, amount: layout.adaptation),
                    y: adaptiveBinding($settings.homeLaunchY, layout.launch.y, amount: layout.adaptation),
                    size: proxy.size,
                    enabled: model.editingHome
                ) { launchControls(pickerWidth: layout.pickerWidth) }
            }
        }
        .onDisappear {
            if model.editingHome { model.editingHome = false }
        }
    }

    private func adaptiveBinding(_ source: Binding<Double>, _ fallback: CGFloat, amount: CGFloat) -> Binding<Double> {
        Binding(
            get: {
                source.wrappedValue * Double(1 - amount) + Double(fallback * amount)
            },
            set: { source.wrappedValue = $0 }
        )
    }

    private var profileReadout: some View {
        Button {
            if !model.editingHome {
                if account.profile == nil { model.beginMicrosoftLogin() } else { model.section = .settings }
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(account.profile == nil ? L10n.t("home.local") : L10n.t("home.microsoft"))
                    .font(.miore(size: 9, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(MioreTheme.subtle)
                HStack(spacing: 7) {
                    Image(systemName: account.profile == nil ? "person.crop.circle" : "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: settings.homeAccentHex))
                    Text(account.profile?.name ?? model.settings.username)
                        .font(.miore(size: 12, weight: .medium))
                }
                Text(account.profile == nil ? L10n.t("home.signin") : (account.isSessionValid ? L10n.t("home.connected") : L10n.t("home.expired")))
                    .font(.miore(size: 9))
                    .foregroundColor(MioreTheme.subtle)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(WidgetSurface(accent: Color(hex: settings.homeAccentHex)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(account.profile == nil ? L10n.t("home.signin") : L10n.t("home.manage_account"))
    }

    @ViewBuilder private var greeting: some View {
        if let last = ai.messages.last(where: { $0.role == .assistant }) {
            Text(last.text)
                .font(.miore(size: 12))
                .foregroundColor(MioreTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: last.text)
        } else {
            Text(L10n.t("home.welcome"))
                .font(.miore(size: 12))
                .foregroundColor(MioreTheme.subtle)
                .transition(.opacity)
        }
    }

    private func launchControls(pickerWidth: CGFloat) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                if launcher.state.isActive {
                    Button(L10n.t("home.stop")) { launcher.stop() }
                        .buttonStyle(GhostButtonStyle())
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
                Button(action: model.launchSelected) {
                    HStack(spacing: 9) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(model.instances.isEmpty ? L10n.t("home.configure") : L10n.t("home.launch"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(hex: settings.homeAccentHex)))
                .disabled(launcher.state == .preparing)
                .scaleEffect(launcher.state == .preparing ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: launcher.state == .preparing)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: launcher.state)
    }

}

private struct AdaptiveHomeLayout {
    let adaptation: CGFloat
    let profile: CGPoint
    let clock: CGPoint
    let instance: CGPoint
    let runtime: CGPoint
    let greeting: CGPoint
    let brand: CGPoint
    let logo: CGPoint
    let version: CGPoint
    let launch: CGPoint
    let greetingWidth: CGFloat
    let profileSize: CGSize
    let clockSize: CGSize
    let instanceSize: CGSize
    let runtimeSize: CGSize
    let logoSize: CGFloat
    let centerWidth: CGFloat
    let pickerWidth: CGFloat
    let compact: Bool

    init(size: CGSize, profileSize: CGSize, clockSize: CGSize, instanceSize: CGSize, runtimeSize: CGSize) {
        let widthAdaptation = Self.smoothstep(edge0: 720, edge1: 640, value: size.width)
        let heightAdaptation = Self.smoothstep(edge0: 540, edge1: 418, value: size.height)
        adaptation = max(widthAdaptation, heightAdaptation)
        compact = adaptation > 0.58
        let topWidgetGap = size.width - profileSize.width - clockSize.width - 52
        greetingWidth = adaptation > 0 ? min(500, max(180, topWidgetGap)) : min(500, max(220, size.width - 80))
        centerWidth = min(280, max(180, size.width - 100))
        pickerWidth = min(260, max(200, size.width - 80))

        let availablePairWidth = max(236, size.width - 30)
        let topScale = min(1, availablePairWidth / max(profileSize.width + clockSize.width + 12, 1))
        let bottomScale = min(1, availablePairWidth / max(instanceSize.width + runtimeSize.width + 12, 1))
        self.profileSize = CGSize(width: profileSize.width * topScale, height: profileSize.height)
        self.clockSize = CGSize(width: clockSize.width * topScale, height: clockSize.height)
        self.instanceSize = CGSize(width: instanceSize.width * bottomScale, height: instanceSize.height)
        self.runtimeSize = CGSize(width: runtimeSize.width * bottomScale, height: runtimeSize.height)
        let expandedLogoSize = min(250, size.height * 0.34)
        let compactLogoSize = min(128, max(96, size.height * 0.25))
        let preferredLogoSize = expandedLogoSize * (1 - adaptation) + compactLogoSize * adaptation

        let halfWidth = max(size.width / 2, 1)
        let halfHeight = max(size.height / 2, 1)
        let margin: CGFloat = size.width < 720 ? 10 : 16
        let topMargin: CGFloat = 12
        let bottomMargin: CGFloat = 12
        let leftX = -halfWidth + margin + self.profileSize.width / 2
        let rightX = halfWidth - margin - self.clockSize.width / 2
        let topY = -halfHeight + topMargin + max(self.profileSize.height, self.clockSize.height) / 2
        let lowerY = halfHeight - bottomMargin - max(self.instanceSize.height, self.runtimeSize.height) / 2

        profile = CGPoint(x: leftX / halfWidth, y: topY / halfHeight)
        clock = CGPoint(x: rightX / halfWidth, y: topY / halfHeight)
        instance = CGPoint(x: (-halfWidth + margin + self.instanceSize.width / 2) / halfWidth, y: lowerY / halfHeight)
        runtime = CGPoint(x: (halfWidth - margin - self.runtimeSize.width / 2) / halfWidth, y: lowerY / halfHeight)

        let topWidgetsBottom = topY + max(self.profileSize.height, self.clockSize.height) / 2
        let launchHeight: CGFloat = compact ? 94 : 104
        let compactStackTop = -halfHeight + 6
        let stackTop = compact ? compactStackTop : topWidgetsBottom + 4
        let stackBottom = halfHeight - (compact ? 6 : 8)
        let availableHeight = max(1, stackBottom - stackTop)
        let greetingHeight: CGFloat = compact ? 32 : 48
        let brandHeight: CGFloat = 24
        let versionHeight: CGFloat = compact ? 34 : 46
        let minimumGaps: CGFloat = compact ? 14 : 18
        let fixedHeight = greetingHeight + brandHeight + versionHeight + launchHeight + minimumGaps
        let fittedLogoSize = max(compact ? 64 : 88, availableHeight - fixedHeight)
        logoSize = min(preferredLogoSize, fittedLogoSize)
        let naturalHeight = fixedHeight + preferredLogoSize + 24
        let compression = min(1, availableHeight / naturalHeight)
        let logoGap: CGFloat = compact ? 5 : 11 + 7 * compression
        let brandGap: CGFloat = compact ? 0 : 2 + 2 * compression
        let versionGap: CGFloat = compact ? 0 : 1 + compression
        let launchGap: CGFloat = compact ? 3 : 6 + 7 * compression
        let totalHeight = greetingHeight + logoGap + logoSize + brandGap + brandHeight + versionGap + versionHeight + launchGap + launchHeight
        let stackStart = stackTop + max(0, (availableHeight - totalHeight) / 2)
        let greetingCenterY = stackStart + greetingHeight / 2
        let logoCenterY = stackStart + greetingHeight + logoGap + logoSize / 2
        let brandCenterY = stackStart + greetingHeight + logoGap + logoSize + brandGap + brandHeight / 2
        let versionCenterY = stackStart + greetingHeight + logoGap + logoSize + brandGap + brandHeight + versionGap + versionHeight / 2
        let launchCenterY = versionCenterY + versionHeight / 2 + launchGap + launchHeight / 2

        greeting = CGPoint(x: 0, y: greetingCenterY / halfHeight)
        brand = CGPoint(x: 0, y: brandCenterY / halfHeight)
        logo = CGPoint(x: 0, y: logoCenterY / halfHeight)
        version = CGPoint(x: 0, y: versionCenterY / halfHeight)
        launch = CGPoint(x: 0, y: launchCenterY / halfHeight)
    }

    private static func smoothstep(edge0: CGFloat, edge1: CGFloat, value: CGFloat) -> CGFloat {
        let t = min(1, max(0, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

private struct HomeVersionPicker: View {
    @Binding var selection: String
    let instances: [GameInstance]
    let accent: Color
    let width: CGFloat
    let compact: Bool

    private var selected: GameInstance? {
        instances.first(where: { $0.id == selection }) ?? instances.first
    }

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            Text(selected?.loader.rawValue.uppercased() ?? "NO INSTANCE")
                .font(.miore(size: 9, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundColor(accent.opacity(0.82))
            if instances.isEmpty {
                Text(L10n.t("home.no_instance"))
                    .font(.miore(size: compact ? 11 : 13, weight: .medium))
                    .foregroundColor(MioreTheme.muted)
                    .frame(width: width, height: 24)
            } else {
                Picker("", selection: $selection) {
                    ForEach(instances) { instance in
                        Text("\(instance.gameVersion) · \(instance.name)").tag(instance.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.miore(size: compact ? 11 : 13, weight: .medium))
                .frame(width: width, height: 24)
                .help("Choose a Minecraft version")
            }
        }
        .frame(width: width, height: compact ? 42 : 48)
    }
}

private struct GlitchBlock: View {
    let loader: LoaderKind
    let animated: Bool
    let accent: Color
    @State private var active = false

    var body: some View {
        ZStack {
            if active {
                PixelCube(loader: loader, accent: accent).opacity(0.10).offset(x: -6, y: 2)
                PixelCube(loader: loader, accent: accent).opacity(0.12).offset(x: 7, y: -2)
            }
            PixelCube(loader: loader, accent: accent)
            if active {
                VStack(spacing: 17) {
                    Rectangle().fill(MioreTheme.background).frame(height: 3).offset(x: -8)
                    Rectangle().fill(accent.opacity(0.8)).frame(width: 112, height: 2).offset(x: 16)
                    Rectangle().fill(MioreTheme.background).frame(height: 5).offset(x: 10)
                }
                .frame(width: 190)
            }
        }
        .task(id: animated) {
            active = false
            guard animated else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 7_500_000_000)
                    active = true
                    try await Task.sleep(nanoseconds: 120_000_000)
                    active = false
                } catch {
                    active = false
                    break
                }
            }
        }
    }
}

private struct PixelCube: View {
    let loader: LoaderKind
    let accent: Color
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var top = Path(); top.move(to: CGPoint(x: w * 0.5, y: h * 0.08)); top.addLine(to: CGPoint(x: w * 0.88, y: h * 0.28)); top.addLine(to: CGPoint(x: w * 0.5, y: h * 0.48)); top.addLine(to: CGPoint(x: w * 0.12, y: h * 0.28)); top.closeSubpath()
            var left = Path(); left.move(to: CGPoint(x: w * 0.12, y: h * 0.28)); left.addLine(to: CGPoint(x: w * 0.5, y: h * 0.48)); left.addLine(to: CGPoint(x: w * 0.5, y: h * 0.91)); left.addLine(to: CGPoint(x: w * 0.12, y: h * 0.70)); left.closeSubpath()
            var right = Path(); right.move(to: CGPoint(x: w * 0.5, y: h * 0.48)); right.addLine(to: CGPoint(x: w * 0.88, y: h * 0.28)); right.addLine(to: CGPoint(x: w * 0.88, y: h * 0.70)); right.addLine(to: CGPoint(x: w * 0.5, y: h * 0.91)); right.closeSubpath()
            context.fill(top, with: .color(accent))
            context.fill(left, with: .color(accent.opacity(0.72)))
            context.fill(right, with: .color(accent.opacity(0.46)))
            let pixel = max(4, w / 28)
            let seed = loader.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            for i in 0..<19 {
                let x = CGFloat((i * 37 + seed) % 15) * pixel + w * 0.22
                let y = CGFloat((i * 23 + seed / 3) % 14) * pixel + h * 0.25
                let rect = CGRect(x: x, y: y, width: pixel * CGFloat(i % 3 + 1), height: pixel)
                context.fill(Path(rect), with: .color(MioreTheme.contrastText(for: accent).opacity(i % 2 == 0 ? 0.42 : 0.18)))
            }
            var outline = Path(); outline.addPath(top); outline.addPath(left); outline.addPath(right)
            context.stroke(outline, with: .color(accent.opacity(0.95)), lineWidth: 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct DraggableHomeItem<Content: View>: View {
    @Binding var x: Double
    @Binding var y: Double
    let width: Binding<Double>?
    let height: Binding<Double>?
    let size: CGSize
    let enabled: Bool
    let extraYOffset: CGFloat
    let onRemove: (() -> Void)?
    let content: Content
    @State private var moveStart: CGPoint?
    @State private var contentSize: CGSize = .zero
    @State private var resizing = false

    init(x: Binding<Double>, y: Binding<Double>, width: Binding<Double>? = nil, height: Binding<Double>? = nil, size: CGSize, enabled: Bool, extraYOffset: CGFloat = 0, onRemove: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        _x = x; _y = y; self.width = width; self.height = height
        self.size = size; self.enabled = enabled; self.extraYOffset = extraYOffset; self.onRemove = onRemove
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if enabled { decorated.gesture(moveGesture) } else { decorated }
    }

    private var decorated: some View {
        ZStack(alignment: .bottomTrailing) {
            fittedContent
                .allowsHitTesting(!enabled)
            if enabled, let width, let height {
                ResizeHandle(width: width, height: height, resizing: $resizing)
                    .offset(x: 8, y: 8)
            }
        }
        .frame(width: width.map { CGFloat($0.wrappedValue) }, height: height.map { CGFloat($0.wrappedValue) })
        .contentShape(Rectangle())
        .padding(enabled ? 4 : 0)
        .overlay(Rectangle().stroke(enabled ? MioreTheme.foreground.opacity(0.7) : .clear, style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
        .overlay(alignment: .topTrailing) {
            if enabled, let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(MioreTheme.background)
                        .overlay(Circle().stroke(MioreTheme.foreground.opacity(0.7), lineWidth: 1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .help(L10n.t("widget.remove"))
            }
        }
        .background(GeometryReader { proxy in Color.clear.preference(key: HomeItemSizeKey.self, value: proxy.size) })
        .onPreferenceChange(HomeItemSizeKey.self) { contentSize = $0 }
        .offset(safeOffset)
    }

    @ViewBuilder private var fittedContent: some View {
        if width != nil || height != nil {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content
        }
    }

    private var moveGesture: some Gesture {
        DragGesture().onChanged { value in
            guard !resizing else { return }
            if moveStart == nil { moveStart = CGPoint(x: x, y: y) }
            guard let moveStart else { return }
            let rawX = min(0.9, max(-0.9, moveStart.x + value.translation.width / max(size.width / 2, 1)))
            let rawY = min(0.88, max(-0.88, moveStart.y + value.translation.height / max(size.height / 2, 1)))
            x = snapped(rawX, pixels: size.width / 2)
            y = snapped(rawY, pixels: size.height / 2)
        }.onEnded { _ in moveStart = nil }
    }

    private func snapped(_ value: Double, pixels: CGFloat) -> Double {
        guard pixels > 0 else { return value }
        let grid: CGFloat = 8
        return Double((CGFloat(value) * pixels / grid).rounded() * grid / pixels)
    }

    private var safeOffset: CGSize {
        let requestedX = x * size.width / 2
        let requestedY = y * size.height / 2 + extraYOffset
        let maxX = max(0, (size.width - contentSize.width) / 2 - 10)
        let maxY = max(0, (size.height - contentSize.height) / 2 - 10)
        return CGSize(width: min(maxX, max(-maxX, requestedX)), height: min(maxY, max(-maxY, requestedY)))
    }
}

private struct ResizeHandle: View {
    @Binding var width: Double
    @Binding var height: Double
    @Binding var resizing: Bool
    @State private var startSize: CGSize?

    var body: some View {
        ZStack {
            Rectangle().fill(MioreTheme.background)
            Path { path in
                path.move(to: CGPoint(x: 4, y: 14)); path.addLine(to: CGPoint(x: 14, y: 4))
                path.move(to: CGPoint(x: 8, y: 14)); path.addLine(to: CGPoint(x: 14, y: 8))
            }
            .stroke(MioreTheme.foreground, lineWidth: 1)
        }
        .frame(width: 18, height: 18)
        .overlay(Rectangle().stroke(MioreTheme.foreground, lineWidth: 1))
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { value in
            resizing = true
            if startSize == nil { startSize = CGSize(width: width, height: height) }
            guard let startSize else { return }
            let grid: CGFloat = 8
            let proposedWidth = (startSize.width + value.translation.width) / grid
            let proposedHeight = (startSize.height + value.translation.height) / grid
            width = min(420, max(118, proposedWidth.rounded() * grid))
            height = min(260, max(72, proposedHeight.rounded() * grid))
        }.onEnded { _ in
            startSize = nil
            resizing = false
        })
        .help("Resize freely")
    }
}

private struct HomeItemSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct AmbientGlow: View {
    let color: Color
    let size: CGSize

    var body: some View {
        Rectangle()
            .fill(RadialGradient(
                colors: [color.opacity(0.09), color.opacity(0.03), color.opacity(0.008), .clear],
                center: .center,
                startRadius: 0,
                endRadius: min(size.width, size.height) * 0.48
            ))
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.035), .clear], center: .center, startRadius: 0, endRadius: min(size.width, size.height) * 0.30))
                    .frame(width: min(size.width, size.height) * 0.62)
                    .offset(x: -size.width * 0.18, y: -size.height * 0.22)
            }
    }
}

private struct HomeClockWidget: View {
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Text(L10n.t("home.clock")).font(.miore(size: 8, weight: .medium, design: .monospaced)).tracking(1.1)
                }
                Text(format(context.date, template: "j:mm"))
                    .font(.miore(size: 23, weight: .light, design: .monospaced))
                    .tracking(-1)
                Text(format(context.date, template: "EEE, MMM d"))
                    .font(.miore(size: 8, weight: .medium))
                    .foregroundColor(MioreTheme.muted)
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(WidgetSurface(accent: accent))
        }
    }

    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch L10n.language.resolved {
        case .zhHans: return Locale(identifier: "zh_CN")
        case .zhHant: return Locale(identifier: "zh_TW")
        case .ja: return Locale(identifier: "ja_JP")
        default: return Locale(identifier: "en_US")
        }
    }
}

private struct InstanceWidget: View {
    let instance: GameInstance?
    let count: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetLabel(symbol: "square.stack.3d.up", title: L10n.t("home.current_instance"), accent: accent)
            Text(instance?.name ?? L10n.t("home.no_instance_short"))
                .font(.miore(size: 11, weight: .semibold)).lineLimit(1)
            HStack {
                Text(instance?.loader.subtitle ?? L10n.t("loader.vanilla"))
                Spacer()
                Text(instance?.gameVersion ?? "—")
            }
            .font(.miore(size: 8, design: .monospaced)).foregroundColor(MioreTheme.subtle)
            Text(L10n.t("home.instances_count", count)).font(.miore(size: 8)).foregroundColor(MioreTheme.muted)
        }
        .padding(11).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(WidgetSurface(accent: accent))
    }
}

private struct RuntimeWidget: View {
    let runtime: JavaRuntime?
    let requiredJava: Int
    let memoryMB: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetLabel(symbol: "memorychip", title: L10n.t("home.runtime"), accent: accent)
            Text(runtime.map { "Java \($0.major)" } ?? L10n.t("home.java_recommended", requiredJava))
                .font(.miore(size: 11, weight: .semibold)).lineLimit(1)
            Text(runtime?.source ?? "OpenJDK")
                .font(.miore(size: 8, design: .monospaced)).foregroundColor(MioreTheme.subtle).lineLimit(1)
            HStack {
                Text(L10n.t("home.memory"))
                Spacer()
                Text("\(memoryMB) MB")
            }
            .font(.miore(size: 8, design: .monospaced)).foregroundColor(MioreTheme.muted)
        }
        .padding(11).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(WidgetSurface(accent: accent))
    }
}

private struct WidgetLabel: View {
    let symbol: String
    let title: String
    let accent: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 9)).foregroundColor(accent)
            Text(title.uppercased()).font(.miore(size: 8, weight: .medium, design: .monospaced)).tracking(0.8)
        }.foregroundColor(MioreTheme.muted)
    }
}

private struct WidgetSurface: View {
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(MioreTheme.background.opacity(0.82))

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            MioreTheme.foreground.opacity(0.075),
                            MioreTheme.foreground.opacity(0.018),
                            MioreTheme.foreground.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.09), accent.opacity(0.025), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 190
                    )
                )

            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.30), accent.opacity(0.06), MioreTheme.glassStroke],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: accent.opacity(0.08), radius: 9, x: 0, y: 4)
    }
}

private struct HomeAlignmentGrid: View {
    var body: some View {
        Canvas { context, size in
            var minor = Path()
            var major = Path()
            var dots = Path()
            let step: CGFloat = 8
            let columns = Int(ceil(size.width / step / 2))
            let rows = Int(ceil(size.height / step / 2))

            for index in -columns...columns where index != 0 {
                let x = size.width / 2 + CGFloat(index) * step
                if index.isMultiple(of: 8) {
                    major.move(to: CGPoint(x: x, y: 0)); major.addLine(to: CGPoint(x: x, y: size.height))
                } else {
                    minor.move(to: CGPoint(x: x, y: 0)); minor.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            for index in -rows...rows where index != 0 {
                let y = size.height / 2 + CGFloat(index) * step
                if index.isMultiple(of: 8) {
                    major.move(to: CGPoint(x: 0, y: y)); major.addLine(to: CGPoint(x: size.width, y: y))
                } else {
                    minor.move(to: CGPoint(x: 0, y: y)); minor.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            let startX = (size.width / 2).truncatingRemainder(dividingBy: step)
            let startY = (size.height / 2).truncatingRemainder(dividingBy: step)
            for x in stride(from: startX, through: size.width, by: step * 2) {
                for y in stride(from: startY, through: size.height, by: step * 2) {
                    dots.addEllipse(in: CGRect(x: x - 0.65, y: y - 0.65, width: 1.3, height: 1.3))
                }
            }
            context.stroke(minor, with: .color(MioreTheme.foreground.opacity(0.022)), lineWidth: 0.4)
            context.stroke(major, with: .color(MioreTheme.accent.opacity(0.13)), lineWidth: 0.7)
            context.fill(dots, with: .color(MioreTheme.foreground.opacity(0.075)))

            var axes = Path()
            axes.move(to: CGPoint(x: size.width / 2, y: 0))
            axes.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            axes.move(to: CGPoint(x: 0, y: size.height / 2))
            axes.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(axes, with: .color(MioreTheme.accent.opacity(0.30)), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

            let inset: CGFloat = 16
            let guideRect = CGRect(x: inset, y: inset, width: max(0, size.width - inset * 2), height: max(0, size.height - inset * 2))
            context.stroke(Path(guideRect), with: .color(MioreTheme.foreground.opacity(0.12)), style: StrokeStyle(lineWidth: 0.75, dash: [2, 4]))
        }
        .background(MioreTheme.background.opacity(0.12))
    }
}

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for y in stride(from: 0, to: size.height, by: 6) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(MioreTheme.foreground.opacity(0.025)), lineWidth: 0.5)
        }
    }
}
