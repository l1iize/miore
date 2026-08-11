import Foundation
import AppKit
import SwiftUI

struct MicrosoftProfile: Codable, Equatable {
    let id: String
    let name: String
}

struct MinecraftCredentials {
    let username: String
    let uuid: String
    let accessToken: String
}

struct DeviceLoginInfo: Equatable {
    let userCode: String
    let verificationURL: URL
    let message: String
}

enum AccountError: LocalizedError {
    case missingClientID, invalidClientID, unapprovedClientID, invalidResponse, server(String), noMinecraft, noOfficialAccount
    var errorDescription: String? {
        switch self {
        case .missingClientID: return L10n.t("account.missing_client")
        case .invalidClientID: return L10n.t("account.invalid_client")
        case .unapprovedClientID: return L10n.t("account.unapproved")
        case .invalidResponse: return L10n.t("account.invalid_response")
        case .server(let message): return message
        case .noMinecraft: return L10n.t("account.no_minecraft")
        case .noOfficialAccount: return L10n.t("account.no_official")
        }
    }
}

@MainActor
final class MicrosoftAccountService: ObservableObject {
    @Published private(set) var profile: MicrosoftProfile?
    @Published private(set) var deviceInfo: DeviceLoginInfo?
    @Published private(set) var isWorking = false
    @Published private(set) var status = ""
    @Published var error: String?

    private let settings: SettingsStore
    private let config = LocalConfigStore.shared
    private let secrets = SecureStore.shared
    private var loginTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
        secrets.migrate(key: "minecraftAccessToken", from: config)
        secrets.migrate(key: "microsoftRefreshToken", from: config)
        if let id = config.string(forKey: "microsoftProfileID"), let name = config.string(forKey: "microsoftProfileName") {
            profile = MicrosoftProfile(id: id, name: name)
        }
        if profile != nil { refreshIfNeeded() }
    }

    var credentials: MinecraftCredentials? {
        guard let profile, let token = secrets.string(forKey: "minecraftAccessToken"),
              (config.double(forKey: "minecraftTokenExpiry") ?? 0) > Date().timeIntervalSince1970 + 60 else { return nil }
        return MinecraftCredentials(username: profile.name, uuid: profile.id, accessToken: token)
    }

    var isSessionValid: Bool { credentials != nil }
    var canUseDeviceLogin: Bool { UUID(uuidString: settings.microsoftClientID.trimmingCharacters(in: .whitespacesAndNewlines)) != nil }

    func beginLogin() {
        cancelLogin()
        let clientID = settings.microsoftClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else { error = AccountError.missingClientID.localizedDescription; return }
        guard UUID(uuidString: clientID) != nil else { error = AccountError.invalidClientID.localizedDescription; return }
        isWorking = true; status = L10n.t("account.request_code"); error = nil; deviceInfo = nil
        loginTask = Task {
            do {
                let device = try await requestDeviceCode(clientID: clientID)
                guard !Task.isCancelled else { return }
                deviceInfo = DeviceLoginInfo(userCode: device.userCode, verificationURL: device.verificationURL, message: device.message)
                status = L10n.t("account.wait_browser")
                let microsoftToken = try await pollForToken(device: device, clientID: clientID)
                guard !Task.isCancelled else { return }
                status = L10n.t("account.connect_xbox")
                try await completeMinecraftLogin(microsoftAccessToken: microsoftToken.accessToken, refreshToken: microsoftToken.refreshToken, clientID: clientID)
                status = L10n.t("account.login_done"); isWorking = false; deviceInfo = nil
            } catch is CancellationError {
                isWorking = false
            } catch {
                self.error = error.localizedDescription; status = L10n.t("account.login_failed"); isWorking = false
            }
        }
    }

    func openVerificationPage() {
        if let url = deviceInfo?.verificationURL { NSWorkspace.shared.open(url) }
    }

    func openApprovalPage() {
        if let url = URL(string: "https://aka.ms/mce-reviewappid") { NSWorkspace.shared.open(url) }
    }

    func importOfficialLauncher() {
        cancelLogin(); isWorking = true; status = L10n.t("account.read_official"); error = nil
        importTask = Task {
            do {
                let candidates = [
                    URL(fileURLWithPath: settings.gameDirectory).appendingPathComponent("launcher_accounts.json"),
                    URL(fileURLWithPath: SettingsStore.officialGameDirectory).appendingPathComponent("launcher_accounts.json"),
                    URL(fileURLWithPath: NSString(string: "~/.minecraft/launcher_accounts.json").expandingTildeInPath)
                ]
                var imported: (token: String, profile: MicrosoftProfile)?
                for file in candidates where FileManager.default.fileExists(atPath: file.path) {
                    guard let data = try? Data(contentsOf: file),
                          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let accounts = root["accounts"] as? [String: [String: Any]] else { continue }
                    for account in accounts.values {
                        guard let token = account["accessToken"] as? String, !token.isEmpty else { continue }
                        do {
                            let profileData = try await authorizedGET(URL(string: "https://api.minecraftservices.com/minecraft/profile")!, token: token)
                            if let json = try JSONSerialization.jsonObject(with: profileData) as? [String: Any],
                               let id = json["id"] as? String, let name = json["name"] as? String {
                                imported = (token, MicrosoftProfile(id: id, name: name)); break
                            }
                        } catch { continue }
                    }
                    if imported != nil { break }
                }
                guard let imported else { throw AccountError.noOfficialAccount }
                try Task.checkCancellation()
                saveProfile(imported.profile, accessToken: imported.token, expiresIn: 86400)
                secrets.remove("microsoftRefreshToken")
                config.removeObject(forKey: "microsoftAuthClientID")
                status = L10n.t("account.import_done"); isWorking = false
            } catch is CancellationError {
                self.isWorking = false
            } catch {
                self.error = error.localizedDescription; self.status = L10n.t("account.import_failed"); self.isWorking = false
            }
            self.importTask = nil
        }
    }

    func copyCode() {
        guard let code = deviceInfo?.userCode else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string)
    }

    func cancelLogin() {
        loginTask?.cancel(); loginTask = nil
        importTask?.cancel(); importTask = nil
        refreshTask?.cancel(); refreshTask = nil
        isWorking = false; deviceInfo = nil
    }

    func signOut() {
        cancelLogin()
        ["microsoftRefreshToken", "minecraftAccessToken", "microsoftProfileID", "microsoftProfileName", "minecraftTokenExpiry", "microsoftAuthClientID"].forEach {
            config.removeObject(forKey: $0)
        }
        secrets.remove("microsoftRefreshToken")
        secrets.remove("minecraftAccessToken")
        profile = nil; error = nil; status = ""
    }

    func refreshIfNeeded() {
        let clientID = config.string(forKey: "microsoftAuthClientID") ?? settings.microsoftClientID
        guard credentials == nil, let refresh = secrets.string(forKey: "microsoftRefreshToken"),
              !clientID.isEmpty, !isWorking else { return }
        isWorking = true; status = L10n.t("account.refreshing")
        refreshTask = Task {
            do {
                let token = try await refreshMicrosoftToken(refresh, clientID: clientID)
                try Task.checkCancellation()
                try await completeMinecraftLogin(microsoftAccessToken: token.accessToken, refreshToken: token.refreshToken, clientID: clientID)
                try Task.checkCancellation()
                status = L10n.t("account.refreshed"); isWorking = false
            } catch is CancellationError {
                isWorking = false
            } catch {
                self.error = "Account refresh failed: \(error.localizedDescription)"; isWorking = false
            }
            self.refreshTask = nil
        }
    }

    private struct DeviceCode {
        let deviceCode: String, userCode: String, message: String
        let verificationURL: URL
        let expiresIn: Int, interval: Int
    }

    private struct MicrosoftToken { let accessToken: String, refreshToken: String }

    private func requestDeviceCode(clientID: String) async throws -> DeviceCode {
        let data = try await formRequest(
            url: URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!,
            values: ["client_id": clientID, "scope": "XboxLive.signin offline_access"]
        ).data
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String, let userCode = json["user_code"] as? String,
              let address = json["verification_uri"] as? String, let url = URL(string: address) else { throw AccountError.invalidResponse }
        return DeviceCode(deviceCode: deviceCode, userCode: userCode, message: json["message"] as? String ?? "", verificationURL: url,
                          expiresIn: json["expires_in"] as? Int ?? 900, interval: json["interval"] as? Int ?? 5)
    }

    private func pollForToken(device: DeviceCode, clientID: String) async throws -> MicrosoftToken {
        let deadline = Date().addingTimeInterval(TimeInterval(device.expiresIn))
        var interval = max(device.interval, 2)
        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            let response = try await formRequest(
                url: URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!,
                values: ["grant_type": "urn:ietf:params:oauth:grant-type:device_code", "client_id": clientID, "device_code": device.deviceCode],
                allowErrorResponse: true
            )
            guard let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else { throw AccountError.invalidResponse }
            if (200..<300).contains(response.status), let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String {
                return MicrosoftToken(accessToken: access, refreshToken: refresh)
            }
            switch json["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case let value?: throw AccountError.server((json["error_description"] as? String) ?? value)
            default: throw AccountError.invalidResponse
            }
        }
        throw AccountError.server(L10n.t("account.expired_code"))
    }

    private func refreshMicrosoftToken(_ token: String, clientID: String) async throws -> MicrosoftToken {
        let response = try await formRequest(
            url: URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!,
            values: ["client_id": clientID, "grant_type": "refresh_token", "refresh_token": token, "scope": "XboxLive.signin offline_access"]
        )
        guard let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String else { throw AccountError.invalidResponse }
        return MicrosoftToken(accessToken: access, refreshToken: refresh)
    }

    private func completeMinecraftLogin(microsoftAccessToken: String, refreshToken: String, clientID: String) async throws {
        let xbox = try await jsonRequest(
            url: URL(string: "https://user.auth.xboxlive.com/user/authenticate")!,
            body: ["Properties": ["AuthMethod": "RPS", "SiteName": "user.auth.xboxlive.com", "RpsTicket": "d=\(microsoftAccessToken)"],
                   "RelyingParty": "http://auth.xboxlive.com", "TokenType": "JWT"]
        )
        guard let xboxToken = xbox["Token"] as? String,
              let claims = xbox["DisplayClaims"] as? [String: Any],
              let users = claims["xui"] as? [[String: Any]], let userHash = users.first?["uhs"] as? String else { throw AccountError.invalidResponse }

        let xsts = try await jsonRequest(
            url: URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!,
            body: ["Properties": ["SandboxId": "RETAIL", "UserTokens": [xboxToken]],
                   "RelyingParty": "rp://api.minecraftservices.com/", "TokenType": "JWT"]
        )
        guard let xstsToken = xsts["Token"] as? String else { throw AccountError.invalidResponse }
        let minecraft = try await jsonRequest(
            url: URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!,
            body: ["identityToken": "XBL3.0 x=\(userHash);\(xstsToken)"]
        )
        guard let minecraftToken = minecraft["access_token"] as? String else { throw AccountError.invalidResponse }
        let profileData = try await authorizedGET(URL(string: "https://api.minecraftservices.com/minecraft/profile")!, token: minecraftToken)
        guard let profileJSON = try JSONSerialization.jsonObject(with: profileData) as? [String: Any],
              let id = profileJSON["id"] as? String, let name = profileJSON["name"] as? String else { throw AccountError.noMinecraft }
        let profile = MicrosoftProfile(id: id, name: name)
        try Task.checkCancellation()
        saveProfile(profile, accessToken: minecraftToken, expiresIn: minecraft["expires_in"] as? Int ?? 86400)
        config.set(clientID, forKey: "microsoftAuthClientID")
        _ = secrets.set(refreshToken, forKey: "microsoftRefreshToken")
    }

    private func formRequest(url: URL, values: [String: String], allowErrorResponse: Bool = false) async throws -> (data: Data, status: Int) {
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents(); components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AccountError.invalidResponse }
        if !allowErrorResponse && !(200..<300).contains(http.statusCode) { throw Self.serverError(data) }
        return (data, http.statusCode)
    }

    private func jsonRequest(url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw Self.serverError(data) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AccountError.invalidResponse }
        return json
    }

    private func authorizedGET(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AccountError.invalidResponse }
        if http.statusCode == 404 { throw AccountError.noMinecraft }
        guard (200..<300).contains(http.statusCode) else { throw Self.serverError(data) }
        return data
    }

    private func saveProfile(_ profile: MicrosoftProfile, accessToken: String, expiresIn: Int) {
        self.profile = profile
        config.set(profile.id, forKey: "microsoftProfileID"); config.set(profile.name, forKey: "microsoftProfileName")
        config.set(Date().addingTimeInterval(TimeInterval(expiresIn)).timeIntervalSince1970, forKey: "minecraftTokenExpiry")
        _ = secrets.set(accessToken, forKey: "minecraftAccessToken")
    }

    private static func serverError(_ data: Data) -> AccountError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = (json?["error_description"] as? String) ?? (json?["errorMessage"] as? String) ?? (json?["Message"] as? String) ?? "The authentication service declined the request."
        if message.localizedCaseInsensitiveContains("Invalid app registration") || message.localizedCaseInsensitiveContains("AppRegInfo") { return .unapprovedClientID }
        if message.contains("AADSTS70002") || message.localizedCaseInsensitiveContains("public client") {
            return .server(L10n.t("account.public_client"))
        }
        if let xerr = json?["XErr"] as? Int {
            switch xerr {
            case 2148916233: return .noMinecraft
            case 2148916235: return .server("This Xbox account is unavailable in its current region.")
            case 2148916236, 2148916237: return .server("This account must complete age verification on Xbox first.")
            case 2148916238: return .server(L10n.t("account.child"))
            default: break
            }
        }
        return .server(message)
    }
}

struct MicrosoftLoginSheet: View {
    @ObservedObject var service: MicrosoftAccountService
    @Binding var isPresented: Bool
    let onConfigure: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(L10n.t("login.title")).font(.miore(size: 20, weight: .medium))
            if let profile = service.profile, service.isSessionValid, !service.isWorking {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 32))
                Text(profile.name).font(.miore(size: 14, weight: .medium))
                Button(L10n.t("common.done")) { isPresented = false }.buttonStyle(PrimaryButtonStyle(compact: true))
            } else if let info = service.deviceInfo {
                Text(L10n.t("login.enter_code")).font(.miore(size: 11)).foregroundColor(MioreTheme.muted)
                Button(action: service.copyCode) {
                    Text(info.userCode).font(.miore(size: 27, weight: .semibold, design: .monospaced)).tracking(3)
                }.buttonStyle(.plain).help(L10n.t("login.copy"))
                Button(L10n.t("login.open_page")) { service.openVerificationPage() }.buttonStyle(PrimaryButtonStyle(compact: true))
                ProgressView().controlSize(.small)
                Text(service.status).font(.miore(size: 10)).foregroundColor(MioreTheme.muted)
            } else if service.isWorking {
                ProgressView().controlSize(.small)
                Text(service.status).font(.miore(size: 11)).foregroundColor(MioreTheme.muted)
            } else {
                VStack(spacing: 11) {
                    Button(L10n.t("login.import")) { service.importOfficialLauncher() }.buttonStyle(PrimaryButtonStyle(compact: true))
                    Text(L10n.t("login.import_hint"))
                        .font(.miore(size: 9)).foregroundColor(MioreTheme.muted).multilineTextAlignment(.center)
                    Hairline().padding(.vertical, 4)
                    Button(L10n.t("login.approved")) { service.beginLogin() }.buttonStyle(GhostButtonStyle()).disabled(!service.canUseDeviceLogin)
                    if !service.canUseDeviceLogin {
                        Button(L10n.t("login.configure")) { isPresented = false; onConfigure() }.buttonStyle(.plain).font(.miore(size: 10)).foregroundColor(MioreTheme.muted)
                    }
                    Button(L10n.t("login.approval")) { service.openApprovalPage() }.buttonStyle(.plain).font(.miore(size: 9)).foregroundColor(MioreTheme.subtle)
                }
            }
            if let error = service.error { Text(error).font(.miore(size: 10)).foregroundColor(MioreTheme.muted).multilineTextAlignment(.center).frame(maxWidth: 360) }
            Button(L10n.t("common.cancel")) { service.cancelLogin(); isPresented = false }.buttonStyle(GhostButtonStyle())
        }
        .padding(30).frame(width: 460, height: 330).background(MioreTheme.background).foregroundColor(MioreTheme.foreground)
    }
}
