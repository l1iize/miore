import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var launcher: MinecraftLauncher
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) { self.model = model; self.settings = model.settings; self.launcher = model.launcher }

    var body: some View {
        ZStack {
            MioreTheme.background.ignoresSafeArea()

            AmbientGrid()
                .opacity(0.045)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Hairline()
                Group {
                    switch model.section {
                    case .home: HomeView(model: model)
                    case .instances: InstancesView(model: model)
                    case .content: ContentView(model: model)
                    case .console: ConsoleView(model: model)
                    case .assistant: AssistantView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                .id(model.section)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .offset(x: 18).combined(with: .opacity),
                    removal: .offset(x: -12).combined(with: .opacity)
                ))
                .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.86), value: model.section)
                .clipped()
            }
            if let notice = model.notice {
                NoticeView(text: notice) { model.notice = nil }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.notice != nil)
            }
        }
        .environment(\.font, MioreFont.font(size: 12))
        .foregroundColor(MioreTheme.foreground)
        .preferredColorScheme(MioreTheme.colorScheme)
        .sheet(isPresented: $model.showAccountLogin) {
            MicrosoftLoginSheet(service: model.account, isPresented: $model.showAccountLogin) { model.section = .settings }
        }
    }

    private var topBar: some View {
        GeometryReader { proxy in
            ZStack {
                HStack {
                    Text("MIORE").font(.miore(size: 10, weight: .medium, design: .monospaced)).tracking(1.4).foregroundColor(MioreTheme.muted)
                    Spacer()
                    Text(launcher.state.label.uppercased()).font(.miore(size: 9, design: .monospaced)).tracking(1).foregroundColor(MioreTheme.subtle)
                }
                .padding(.horizontal, 22)
                .opacity(proxy.size.width >= 760 ? 1 : 0)
                .allowsHitTesting(proxy.size.width >= 760)
                if model.editingHome {
                    HomeEditControls(model: model)
                } else {
                    HStack(spacing: 8) {
                        ForEach(AppSection.allCases) { item in
                            HoverNavButton(item: item, selected: model.section == item) { model.section = item }
                        }
                    }
                }
            }
        }
        .frame(height: 62)
    }
}

private struct HomeEditControls: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore

    init(model: AppModel) {
        self.model = model
        settings = model.settings
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if !settings.showHomeProfile {
                    Button { settings.showHomeProfile = true } label: { Label(L10n.t("widget.profile"), systemImage: "person.crop.circle") }
                }
                if !settings.showHomeClock {
                    Button { settings.showHomeClock = true } label: { Label(L10n.t("widget.clock"), systemImage: "clock") }
                }
                if !settings.showHomeInstanceWidget {
                    Button { settings.showHomeInstanceWidget = true } label: { Label(L10n.t("widget.instance"), systemImage: "square.stack.3d.up") }
                }
                if !settings.showHomeRuntimeWidget {
                    Button { settings.showHomeRuntimeWidget = true } label: { Label(L10n.t("widget.runtime"), systemImage: "memorychip") }
                }
                if allWidgetsVisible { Text(L10n.t("widget.all_added")) }
            } label: {
                Label(L10n.t("widget.add"), systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(L10n.t("common.reset")) { settings.resetHomeLayout() }
                .buttonStyle(GhostButtonStyle())
            Button(L10n.t("common.done")) { model.editingHome = false }
                .buttonStyle(PrimaryButtonStyle(compact: true, color: Color(hex: settings.homeAccentHex)))
        }
    }

    private var allWidgetsVisible: Bool {
        settings.showHomeProfile && settings.showHomeClock && settings.showHomeInstanceWidget && settings.showHomeRuntimeWidget
    }
}

private struct HoverNavButton: View {
    let item: AppSection
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .frame(height: 18)
                    .scaleEffect(hovered && !selected ? 1.15 : 1.0)
                Text(item.title)
                    .font(.miore(size: 9, weight: .medium))
                    .frame(height: 11)
                    .opacity(hovered || selected ? 1 : 0)
            }
            .frame(width: 48, height: 43)
            .foregroundColor(selected ? MioreTheme.foreground : MioreTheme.muted)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? MioreTheme.foreground.opacity(0.07) : (hovered ? MioreTheme.foreground.opacity(0.03) : Color.clear))

                    if selected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MioreTheme.accent.opacity(0.15),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? MioreTheme.accent : Color.clear)
                    .frame(height: selected ? 3 : 0)
                    .shadow(color: selected ? MioreTheme.accent.opacity(0.28) : .clear, radius: 5, x: 0, y: 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(item.title)
    }
}

private struct NoticeView: View {
    let text: String
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Text("MIORE").font(.miore(size: 10, design: .monospaced)).tracking(2).foregroundColor(MioreTheme.muted)
            Text(text).font(.miore(size: 13)).multilineTextAlignment(.center).frame(maxWidth: 320)
            Button(L10n.t("common.ok"), action: dismiss).buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .padding(26).background(MioreTheme.background).overlay(Rectangle().stroke(MioreTheme.foreground.opacity(0.36), lineWidth: 1))
        .shadow(color: .black.opacity(0.8), radius: 30)
    }
}

private struct AmbientGrid: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 48) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 48) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(MioreTheme.foreground.opacity(0.12)), lineWidth: 0.5)
        }
    }
}
