import SwiftUI

struct ConsoleView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var launcher: MinecraftLauncher
    @State private var follow = true

    init(model: AppModel) { self.model = model; self.launcher = model.launcher }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                SectionTitle(kicker: "Runtime", title: L10n.t("console.title"), detail: launcher.state.label)
                Spacer()
                if launcher.state.isActive {
                    Button(L10n.t("common.stop")) { launcher.stop() }.buttonStyle(GhostButtonStyle())
                }
                Button(L10n.t("common.clear")) { launcher.clearOutput() }.buttonStyle(GhostButtonStyle())
                Button(L10n.t("console.diagnose")) {
                    model.ai.diagnose(log: launcher.output); model.section = .assistant
                }.buttonStyle(PrimaryButtonStyle(compact: true)).disabled(launcher.output.isEmpty)
            }
            Hairline()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(launcher.output.isEmpty ? "[Miore] \(L10n.t("console.waiting"))" : launcher.output)
                        .font(.miore(size: 11, design: .monospaced)).foregroundColor(MioreTheme.foreground.opacity(0.76))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
                    Color.clear.frame(height: 1).id("END")
                }
                .background(MioreTheme.field).overlay(Rectangle().stroke(MioreTheme.border, lineWidth: 1))
                .onChange(of: launcher.output) { _ in if follow { proxy.scrollTo("END", anchor: .bottom) } }
            }
            Toggle(L10n.t("console.autoscroll"), isOn: $follow).toggleStyle(.checkbox).font(.miore(size: 11)).foregroundColor(MioreTheme.muted)
        }
        .padding(32).frame(maxWidth: 1200, maxHeight: .infinity).frame(maxWidth: .infinity)
    }
}
