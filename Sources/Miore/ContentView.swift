import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var service: ModrinthService
    @State private var query = ""
    @State private var kind: ContentKind = .mod

    init(model: AppModel) { self.model = model; self.service = model.contentService }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                SectionTitle(kicker: "Modrinth", title: L10n.t("content.title"), detail: L10n.t("content.detail"))
                Spacer()
                if !model.instances.isEmpty {
                    Picker(L10n.t("content.target"), selection: Binding(get: { model.selectedInstanceID ?? "" }, set: { model.selectInstance($0); runSearch() })) {
                        ForEach(model.instances) { Text("\($0.name) · \($0.loader.subtitle)").tag($0.id) }
                    }.frame(width: 260)
                }
            }
            Hairline()
            HStack(spacing: 10) {
                Picker("", selection: $kind) { ForEach(ContentKind.allCases) { Text($0.title).tag($0) } }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 260).onChange(of: kind) { _ in runSearch() }
                TextField(L10n.t("content.placeholder"), text: $query).mioreTextField().onSubmit(runSearch)
                Button(L10n.t("common.search"), action: runSearch).buttonStyle(PrimaryButtonStyle(compact: true)).disabled(service.searching)
            }
            if let error = service.error { Text(error).font(.miore(size: 10)).foregroundColor(MioreTheme.muted) }
            if kind == .mod, model.selectedInstance?.loader == .vanilla {
                Text(L10n.t("content.vanilla_warning"))
                    .font(.miore(size: 10)).foregroundColor(MioreTheme.muted)
            }
            if service.searching {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .controlSize(.large)
                    Text(L10n.t("content.searching"))
                        .font(.miore(size: 11))
                        .foregroundColor(MioreTheme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
            else if service.results.isEmpty { emptyState }
            else { results }
        }
        .padding(32).frame(maxWidth: 1100, maxHeight: .infinity).frame(maxWidth: .infinity)
        .onAppear { if service.results.isEmpty { runSearch() } }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(service.results) { project in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(MioreTheme.border, lineWidth: 1)
                            Text(String(project.title.prefix(1)))
                                .font(.miore(size: 17, weight: .medium))
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(project.title)
                                    .font(.miore(size: 13, weight: .medium))
                                Text("by \(project.author)")
                                    .font(.miore(size: 9))
                                    .foregroundColor(MioreTheme.subtle)
                            }
                            Text(project.description)
                                .font(.miore(size: 10))
                                .foregroundColor(MioreTheme.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(Self.count(project.downloads))
                            .font(.miore(size: 9, design: .monospaced))
                            .foregroundColor(MioreTheme.subtle)
                            .frame(minWidth: 50, alignment: .trailing)

                        if service.installingProjectID == project.id {
                            VStack(alignment: .trailing, spacing: 4) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.9)
                                Text(service.status)
                                    .font(.miore(size: 8))
                                    .foregroundColor(MioreTheme.muted)
                            }
                            .frame(width: 130)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        } else {
                            Button(L10n.t("common.install")) { install(project) }
                                .buttonStyle(GhostButtonStyle())
                                .disabled(model.selectedInstance == nil || service.installingProjectID != nil || (kind == .mod && model.selectedInstance?.loader == .vanilla))
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 70)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.installingProjectID)

                    Hairline()
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(MioreTheme.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 28, weight: .thin))
                .foregroundColor(MioreTheme.muted)
            Text(model.selectedInstance == nil ? L10n.t("content.select_instance") : L10n.t("content.none"))
                .font(.miore(size: 13, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private func runSearch() {
        service.search(query: query, kind: kind, gameVersion: model.selectedInstance?.gameVersion, loader: model.selectedInstance?.loader)
    }

    private func install(_ project: ModrinthProject) {
        service.install(project: project, kind: kind, gameVersion: model.selectedInstance?.gameVersion, loader: model.selectedInstance?.loader, gameDirectory: model.settings.gameDirectory) { modpackPlan in
            guard let modpackPlan else { model.refresh(); return }
            model.loaderInstaller.install(modpackPlan.loader, gameVersion: modpackPlan.gameVersion, gameDirectory: model.settings.gameDirectory, javaPath: model.settings.javaPath) { model.refresh() }
        }
    }

    private static func count(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return String(value)
    }
}
