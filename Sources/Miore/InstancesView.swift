import SwiftUI

struct InstancesView: View {
    @ObservedObject var model: AppModel
    @State private var activeInstaller: InstallerSheetKind?
    @State private var pendingDeletion: GameInstance?
    @State private var deleteError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                SectionTitle(kicker: "Library", title: L10n.t("instances.title"), detail: L10n.t("instances.detail"))
                Spacer()
                Button(L10n.t("instances.install_vanilla")) { activeInstaller = .vanilla; model.installer.loadManifest() }.buttonStyle(PrimaryButtonStyle(compact: true))
                Button(L10n.t("instances.install_loader")) { activeInstaller = .loader }.buttonStyle(GhostButtonStyle())
                Button(L10n.t("common.refresh")) { model.refresh() }.buttonStyle(GhostButtonStyle())
            }
            Hairline()
            if model.instances.isEmpty { emptyState } else { instanceList }
        }
        .padding(32).frame(maxWidth: 1100, maxHeight: .infinity, alignment: .top).frame(maxWidth: .infinity)
        .alert(L10n.t("instances.delete_title"), isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button(L10n.t("common.cancel"), role: .cancel) { pendingDeletion = nil }
            Button(L10n.t("instances.delete"), role: .destructive) {
                guard let instance = pendingDeletion else { return }
                do { try model.deleteInstance(instance) }
                catch { deleteError = error.localizedDescription }
                pendingDeletion = nil
            }
        } message: {
            Text(L10n.t("instances.delete_detail", pendingDeletion?.name ?? ""))
        }
        .alert(L10n.t("instances.delete_failed"), isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button(L10n.t("common.close"), role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .overlay {
            if let kind = activeInstaller {
                let visible = Binding(get: { activeInstaller != nil }, set: { if !$0 { activeInstaller = nil } })
                InstallerOverlay(isPresented: visible) {
                    if kind == .vanilla { InstallerSheet(model: model, isPresented: visible) }
                    else { LoaderInstallerSheet(model: model, isPresented: visible) }
                }
            }
        }
    }

    private var instanceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.instances) { instance in
                    HStack(spacing: 8) {
                        Button {
                            model.selectInstance(instance.id); model.section = .home
                        } label: {
                            HStack(spacing: 18) {
                                LoaderMark(loader: instance.loader).frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(instance.name).font(.miore(size: 14, weight: .medium))
                                    Text(instance.versionDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                        .font(.miore(size: 10, design: .monospaced)).foregroundColor(MioreTheme.subtle).lineLimit(1)
                                }
                                Spacer()
                                Text(instance.loader.rawValue).font(.miore(size: 9, design: .monospaced)).tracking(1.2).foregroundColor(MioreTheme.muted)
                                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundColor(MioreTheme.subtle)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            pendingDeletion = instance
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(MioreTheme.subtle)
                        .help(L10n.t("instances.delete"))
                    }
                    .padding(.horizontal, 16).frame(height: 70)
                    Hairline()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash").font(.system(size: 30, weight: .thin)).foregroundColor(MioreTheme.muted)
            Text(L10n.t("instances.empty")).font(.miore(size: 14, weight: .medium))
            Text(L10n.t("instances.empty_detail")).font(.miore(size: 12)).foregroundColor(MioreTheme.muted)
            Button(L10n.t("instances.choose_folder")) { model.chooseGameDirectory() }.buttonStyle(PrimaryButtonStyle(compact: true))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Replaces macOS sheets so both installers close consistently via the X button,
/// Escape, or any click on the dimmed area outside the installer.
private struct InstallerOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Button { isPresented = false } label: {
                MioreTheme.background.opacity(0.72)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            content
                .shadow(color: .black.opacity(0.45), radius: 32, y: 14)
        }
        .ignoresSafeArea()
    }
}

private struct InstallerHeader<Trailing: View>: View {
    let title: String
    let detail: String
    let dismiss: () -> Void
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.miore(size: 20, weight: .medium))
                Text(detail).font(.miore(size: 11)).foregroundColor(MioreTheme.muted)
            }
            Spacer()
            trailing
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundColor(MioreTheme.muted)
            .background(Circle().fill(MioreTheme.background))
            .overlay(Circle().stroke(MioreTheme.border, lineWidth: 1))
            .help(L10n.t("common.close"))
            .keyboardShortcut(.cancelAction)
        }
    }
}

private enum InstallerSheetKind: String, Identifiable {
    case vanilla, loader
    var id: String { rawValue }
}

private struct LoaderInstallerSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var installer: LoaderInstaller
    @Binding var isPresented: Bool
    init(model: AppModel, isPresented: Binding<Bool>) {
        self.model = model; self.installer = model.loaderInstaller; self._isPresented = isPresented
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            InstallerHeader(
                title: L10n.t("instances.install_loader"),
                detail: L10n.t("installer.target", model.selectedInstance?.gameVersion ?? L10n.t("installer.not_selected")),
                dismiss: { isPresented = false }
            ) { EmptyView() }
            Hairline()
            ForEach(InstallableLoader.allCases) { loader in
                HStack(spacing: 14) {
                    LoaderMark(loader: loader == .fabric ? .fabric : loader == .quilt ? .quilt : loader == .forge ? .forge : loader == .neoForge ? .neoForge : .modpack).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loader.rawValue).font(.miore(size: 13, weight: .medium))
                        Text(loader.detail).font(.miore(size: 10)).foregroundColor(MioreTheme.muted)
                    }
                    Spacer()
                    if installer.installing == loader { ProgressView().controlSize(.small); Text(installer.status).font(.miore(size: 9)).foregroundColor(MioreTheme.muted) }
                    else {
                        Button(loader == .optiFine ? L10n.t("installer.download") : L10n.t("common.install")) {
                            installer.install(loader, gameVersion: model.selectedInstance?.gameVersion, gameDirectory: model.settings.gameDirectory, javaPath: model.settings.javaPath) { model.refresh() }
                        }.buttonStyle(PrimaryButtonStyle(compact: true)).disabled(installer.installing != nil)
                    }
                }.frame(height: 58)
                Hairline()
            }
            if let error = installer.error { Text(error).font(.miore(size: 10)).foregroundColor(MioreTheme.muted) }
            Spacer()
        }.padding(24).frame(width: 620).frame(maxHeight: 440).background(MioreTheme.background).foregroundColor(MioreTheme.foreground)
    }
}

private struct InstallerSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var installer: VersionInstaller
    @Binding var isPresented: Bool
    @State private var includeSnapshots = false

    init(model: AppModel, isPresented: Binding<Bool>) {
        self.model = model; self.installer = model.installer; self._isPresented = isPresented
    }

    var displayed: [RemoteVersion] {
        Array(installer.versions.filter { includeSnapshots || $0.type == "release" }.prefix(80))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstallerHeader(
                title: L10n.t("installer.minecraft"),
                detail: L10n.t("installer.minecraft_detail"),
                dismiss: { isPresented = false }
            ) {
                Toggle(L10n.t("installer.snapshots"), isOn: $includeSnapshots).toggleStyle(.checkbox).font(.miore(size: 11))
            }
            Hairline()
            if installer.loadingManifest {
                ProgressView(L10n.t("installer.loading_manifest")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = installer.error, installer.versions.isEmpty {
                VStack(spacing: 12) {
                    Text(error).font(.miore(size: 12)).foregroundColor(MioreTheme.muted)
                    Button(L10n.t("common.retry")) { installer.loadManifest() }.buttonStyle(PrimaryButtonStyle(compact: true))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayed) { version in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(version.id).font(.miore(size: 13, weight: .medium, design: .monospaced))
                                    Text(version.type.uppercased()).font(.miore(size: 8, design: .monospaced)).tracking(1).foregroundColor(MioreTheme.subtle)
                                }
                                Spacer()
                                if installer.installingID == version.id {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        ProgressView(value: installer.progress).frame(width: 140)
                                        Text(installer.status).font(.miore(size: 9)).foregroundColor(MioreTheme.muted)
                                    }
                                } else {
                                    Button(L10n.t("common.install")) {
                                        installer.install(version, gameDirectory: model.settings.gameDirectory) {
                                            model.refresh()
                                            isPresented = false
                                        }
                                    }.buttonStyle(GhostButtonStyle()).disabled(installer.installingID != nil)
                                }
                            }.padding(.horizontal, 12).frame(height: 58)
                            Hairline()
                        }
                    }
                }.overlay(Rectangle().stroke(MioreTheme.border, lineWidth: 1))
            }
        }
        .padding(24).frame(width: 620).frame(maxHeight: 560).background(MioreTheme.background).foregroundColor(MioreTheme.foreground)
    }
}

struct LoaderMark: View {
    let loader: LoaderKind
    var body: some View {
        ZStack {
            Rectangle().stroke(MioreTheme.border, lineWidth: 1)
            Text(String(loader.rawValue.prefix(1))).font(.miore(size: 17, weight: .medium, design: .monospaced))
            Rectangle().fill(MioreTheme.accent).frame(width: 8, height: 1).offset(x: 15, y: -15)
        }
        .clipped()
    }
}
