import Foundation

final class SettingsStore: ObservableObject {
    private enum Key {
        static let gameDirectory = "gameDirectory"
        static let javaPath = "javaPath"
        static let username = "username"
        static let memoryMB = "memoryMB"
        static let provider = "provider"
        static let endpoint = "endpoint"
        static let model = "model"
        static let aiGreeting = "aiGreeting"
        static let closeAfterLaunch = "closeAfterLaunch"
        static let microsoftClientID = "microsoftClientID"
        static let homeBackgroundHex = "homeBackgroundHex"
        static let homeAccentHex = "homeAccentHex"
        static let homeProfileX = "homeProfileX"
        static let homeProfileY = "homeProfileY"
        static let showHomeProfile = "showHomeProfile"
        static let homeGreetingX = "homeGreetingX"
        static let homeGreetingY = "homeGreetingY"
        static let homeLogoX = "homeLogoX"
        static let homeLogoY = "homeLogoY"
        static let homeBrandX = "homeBrandX"
        static let homeBrandY = "homeBrandY"
        static let homeVersionX = "homeVersionX"
        static let homeVersionY = "homeVersionY"
        static let homeLaunchX = "homeLaunchX"
        static let homeLaunchY = "homeLaunchY"
        static let autoSelectJava = "autoSelectJava"
        static let appLanguage = "appLanguage"
        static let homeClockX = "homeClockX"
        static let homeClockY = "homeClockY"
        static let showHomeClock = "showHomeClock"
        static let homeInstanceWidgetX = "homeInstanceWidgetX"
        static let homeInstanceWidgetY = "homeInstanceWidgetY"
        static let showHomeInstanceWidget = "showHomeInstanceWidget"
        static let homeRuntimeWidgetX = "homeRuntimeWidgetX"
        static let homeRuntimeWidgetY = "homeRuntimeWidgetY"
        static let showHomeRuntimeWidget = "showHomeRuntimeWidget"
        static let homeProfileWidth = "homeProfileWidth"
        static let homeProfileHeight = "homeProfileHeight"
        static let homeClockWidth = "homeClockWidth"
        static let homeClockHeight = "homeClockHeight"
        static let homeInstanceWidgetWidth = "homeInstanceWidgetWidth"
        static let homeInstanceWidgetHeight = "homeInstanceWidgetHeight"
        static let homeRuntimeWidgetWidth = "homeRuntimeWidgetWidth"
        static let homeRuntimeWidgetHeight = "homeRuntimeWidgetHeight"
        static let homeIdentityLayoutVersion = "homeIdentityLayoutVersion"
    }

    @Published var gameDirectory: String { didSet { save(Key.gameDirectory, gameDirectory) } }
    @Published var javaPath: String { didSet { save(Key.javaPath, javaPath) } }
    @Published var username: String { didSet { save(Key.username, username) } }
    @Published var memoryMB: Double { didSet { save(Key.memoryMB, memoryMB) } }
    private var previousProvider: AIProvider = .openAI

    @Published var provider: AIProvider {
        didSet {
            save(Key.provider, provider.rawValue)
            if endpoint.isEmpty || endpoint == previousProvider.defaultEndpoint {
                endpoint = provider.defaultEndpoint
            }
            if model.isEmpty || model == previousProvider.defaultModel {
                model = provider.defaultModel
            }
            previousProvider = provider
        }
    }
    @Published var endpoint: String { didSet { save(Key.endpoint, endpoint) } }
    @Published var model: String { didSet { save(Key.model, model) } }
    @Published var aiGreeting: Bool { didSet { save(Key.aiGreeting, aiGreeting) } }
    @Published var closeAfterLaunch: Bool { didSet { save(Key.closeAfterLaunch, closeAfterLaunch) } }
    @Published var microsoftClientID: String { didSet { save(Key.microsoftClientID, microsoftClientID) } }
    @Published var homeBackgroundHex: String { didSet { save(Key.homeBackgroundHex, homeBackgroundHex) } }
    @Published var homeAccentHex: String { didSet { save(Key.homeAccentHex, homeAccentHex) } }
    @Published var homeProfileX: Double { didSet { save(Key.homeProfileX, homeProfileX) } }
    @Published var homeProfileY: Double { didSet { save(Key.homeProfileY, homeProfileY) } }
    @Published var showHomeProfile: Bool { didSet { save(Key.showHomeProfile, showHomeProfile) } }
    @Published var homeGreetingX: Double { didSet { save(Key.homeGreetingX, homeGreetingX) } }
    @Published var homeGreetingY: Double { didSet { save(Key.homeGreetingY, homeGreetingY) } }
    @Published var homeLogoX: Double { didSet { save(Key.homeLogoX, homeLogoX) } }
    @Published var homeLogoY: Double { didSet { save(Key.homeLogoY, homeLogoY) } }
    @Published var homeBrandX: Double { didSet { save(Key.homeBrandX, homeBrandX) } }
    @Published var homeBrandY: Double { didSet { save(Key.homeBrandY, homeBrandY) } }
    @Published var homeVersionX: Double { didSet { save(Key.homeVersionX, homeVersionX) } }
    @Published var homeVersionY: Double { didSet { save(Key.homeVersionY, homeVersionY) } }
    @Published var homeLaunchX: Double { didSet { save(Key.homeLaunchX, homeLaunchX) } }
    @Published var homeLaunchY: Double { didSet { save(Key.homeLaunchY, homeLaunchY) } }
    @Published var autoSelectJava: Bool { didSet { save(Key.autoSelectJava, autoSelectJava) } }
    @Published var appLanguage: AppLanguage { didSet { save(Key.appLanguage, appLanguage.rawValue) } }
    @Published var homeClockX: Double { didSet { save(Key.homeClockX, homeClockX) } }
    @Published var homeClockY: Double { didSet { save(Key.homeClockY, homeClockY) } }
    @Published var showHomeClock: Bool { didSet { save(Key.showHomeClock, showHomeClock) } }
    @Published var homeInstanceWidgetX: Double { didSet { save(Key.homeInstanceWidgetX, homeInstanceWidgetX) } }
    @Published var homeInstanceWidgetY: Double { didSet { save(Key.homeInstanceWidgetY, homeInstanceWidgetY) } }
    @Published var showHomeInstanceWidget: Bool { didSet { save(Key.showHomeInstanceWidget, showHomeInstanceWidget) } }
    @Published var homeRuntimeWidgetX: Double { didSet { save(Key.homeRuntimeWidgetX, homeRuntimeWidgetX) } }
    @Published var homeRuntimeWidgetY: Double { didSet { save(Key.homeRuntimeWidgetY, homeRuntimeWidgetY) } }
    @Published var showHomeRuntimeWidget: Bool { didSet { save(Key.showHomeRuntimeWidget, showHomeRuntimeWidget) } }
    @Published var homeProfileWidth: Double { didSet { save(Key.homeProfileWidth, homeProfileWidth) } }
    @Published var homeProfileHeight: Double { didSet { save(Key.homeProfileHeight, homeProfileHeight) } }
    @Published var homeClockWidth: Double { didSet { save(Key.homeClockWidth, homeClockWidth) } }
    @Published var homeClockHeight: Double { didSet { save(Key.homeClockHeight, homeClockHeight) } }
    @Published var homeInstanceWidgetWidth: Double { didSet { save(Key.homeInstanceWidgetWidth, homeInstanceWidgetWidth) } }
    @Published var homeInstanceWidgetHeight: Double { didSet { save(Key.homeInstanceWidgetHeight, homeInstanceWidgetHeight) } }
    @Published var homeRuntimeWidgetWidth: Double { didSet { save(Key.homeRuntimeWidgetWidth, homeRuntimeWidgetWidth) } }
    @Published var homeRuntimeWidgetHeight: Double { didSet { save(Key.homeRuntimeWidgetHeight, homeRuntimeWidgetHeight) } }

    private let config = LocalConfigStore.shared
    private let secrets = SecureStore.shared

    init() {
        secrets.migrate(key: "aiAPIKey", from: config)
        gameDirectory = config.string(forKey: Key.gameDirectory) ?? Self.officialGameDirectory
        javaPath = config.string(forKey: Key.javaPath) ?? "/usr/bin/java"
        username = config.string(forKey: Key.username) ?? NSUserName()
        let memoryUpperBound = Double(max(2048, min(32768, Int(ProcessInfo.processInfo.physicalMemory / 1_048_576))))
        memoryMB = min(max(config.double(forKey: Key.memoryMB) ?? 4096, 1024), memoryUpperBound)
        let storedProvider = AIProvider(rawValue: config.string(forKey: Key.provider) ?? "") ?? .openAI
        provider = storedProvider
        previousProvider = storedProvider
        endpoint = config.string(forKey: Key.endpoint) ?? AIProvider.openAI.defaultEndpoint
        model = config.string(forKey: Key.model) ?? AIProvider.openAI.defaultModel
        aiGreeting = config.bool(forKey: Key.aiGreeting) ?? true
        closeAfterLaunch = config.bool(forKey: Key.closeAfterLaunch) ?? false
        microsoftClientID = config.string(forKey: Key.microsoftClientID)
            ?? (Bundle.main.object(forInfoDictionaryKey: "MioreMicrosoftClientID") as? String)
            ?? ""
        homeBackgroundHex = config.string(forKey: Key.homeBackgroundHex) ?? "#070708"
        homeAccentHex = config.string(forKey: Key.homeAccentHex) ?? "#FFFFFF"
        homeProfileX = config.double(forKey: Key.homeProfileX) ?? -0.68
        homeProfileY = config.double(forKey: Key.homeProfileY) ?? -0.66
        showHomeProfile = config.bool(forKey: Key.showHomeProfile) ?? true
        homeGreetingX = config.double(forKey: Key.homeGreetingX) ?? 0
        homeGreetingY = config.double(forKey: Key.homeGreetingY) ?? -0.70
        homeLogoX = config.double(forKey: Key.homeLogoX) ?? 0
        homeLogoY = config.double(forKey: Key.homeLogoY) ?? -0.02
        homeBrandX = config.double(forKey: Key.homeBrandX) ?? 0
        homeBrandY = config.double(forKey: Key.homeBrandY) ?? -0.42
        homeVersionX = config.double(forKey: Key.homeVersionX) ?? 0
        homeVersionY = config.double(forKey: Key.homeVersionY) ?? 0.35
        homeLaunchX = config.double(forKey: Key.homeLaunchX) ?? 0
        homeLaunchY = config.double(forKey: Key.homeLaunchY) ?? 0.66
        autoSelectJava = config.bool(forKey: Key.autoSelectJava) ?? true
        appLanguage = AppLanguage(rawValue: config.string(forKey: Key.appLanguage) ?? "en") ?? .system
        homeClockX = config.double(forKey: Key.homeClockX) ?? 0.72
        homeClockY = config.double(forKey: Key.homeClockY) ?? -0.66
        showHomeClock = config.bool(forKey: Key.showHomeClock) ?? true
        homeInstanceWidgetX = config.double(forKey: Key.homeInstanceWidgetX) ?? -0.72
        homeInstanceWidgetY = config.double(forKey: Key.homeInstanceWidgetY) ?? 0.46
        showHomeInstanceWidget = config.bool(forKey: Key.showHomeInstanceWidget) ?? true
        homeRuntimeWidgetX = config.double(forKey: Key.homeRuntimeWidgetX) ?? 0.72
        homeRuntimeWidgetY = config.double(forKey: Key.homeRuntimeWidgetY) ?? 0.46
        showHomeRuntimeWidget = config.bool(forKey: Key.showHomeRuntimeWidget) ?? true
        homeProfileWidth = config.double(forKey: Key.homeProfileWidth) ?? 190
        homeProfileHeight = config.double(forKey: Key.homeProfileHeight) ?? 88
        homeClockWidth = config.double(forKey: Key.homeClockWidth) ?? 142
        homeClockHeight = config.double(forKey: Key.homeClockHeight) ?? 92
        homeInstanceWidgetWidth = config.double(forKey: Key.homeInstanceWidgetWidth) ?? 152
        homeInstanceWidgetHeight = config.double(forKey: Key.homeInstanceWidgetHeight) ?? 104
        homeRuntimeWidgetWidth = config.double(forKey: Key.homeRuntimeWidgetWidth) ?? 152
        homeRuntimeWidgetHeight = config.double(forKey: Key.homeRuntimeWidgetHeight) ?? 104

        if Int(config.double(forKey: Key.homeIdentityLayoutVersion) ?? 0) < 4 {
            homeLogoX = 0
            homeLogoY = -0.18
            homeBrandX = 0
            homeBrandY = 0.21
            homeVersionX = 0
            homeVersionY = 0.31
            config.set(homeLogoX, forKey: Key.homeLogoX)
            config.set(homeLogoY, forKey: Key.homeLogoY)
            config.set(homeBrandX, forKey: Key.homeBrandX)
            config.set(homeBrandY, forKey: Key.homeBrandY)
            config.set(homeVersionX, forKey: Key.homeVersionX)
            config.set(homeVersionY, forKey: Key.homeVersionY)
            config.set(4, forKey: Key.homeIdentityLayoutVersion)
        }

        if endpoint.isEmpty {
            endpoint = provider.defaultEndpoint
        }
        if model.isEmpty {
            model = provider.defaultModel
        }
    }

    var apiKey: String {
        get { secrets.string(forKey: "aiAPIKey") ?? "" }
        set {
            if newValue.isEmpty { secrets.remove("aiAPIKey") }
            else { _ = secrets.set(newValue, forKey: "aiAPIKey") }
        }
    }

    private func save(_ key: String, _ value: Any) { config.set(value, forKey: key) }

    func persistAIEndpoint(_ value: String? = nil) {
        let completed = provider.completedEndpoint(value ?? endpoint)
        endpoint = completed
        config.set(completed, forKey: Key.endpoint)
    }

    static var officialGameDirectory: String {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/minecraft").path
    }

    func resetHomeLayout() {
        showHomeProfile = true
        showHomeClock = true
        showHomeInstanceWidget = true
        showHomeRuntimeWidget = true
        homeProfileX = -0.68; homeProfileY = -0.66
        homeGreetingX = 0; homeGreetingY = -0.70
        homeLogoX = 0; homeLogoY = -0.18
        homeBrandX = 0; homeBrandY = 0.21
        homeVersionX = 0; homeVersionY = 0.31
        homeLaunchX = 0; homeLaunchY = 0.66
        homeClockX = 0.72; homeClockY = -0.66
        homeInstanceWidgetX = -0.72; homeInstanceWidgetY = 0.46
        homeRuntimeWidgetX = 0.72; homeRuntimeWidgetY = 0.46
        homeProfileWidth = 190; homeProfileHeight = 88
        homeClockWidth = 142; homeClockHeight = 92
        homeInstanceWidgetWidth = 152; homeInstanceWidgetHeight = 104
        homeRuntimeWidgetWidth = 152; homeRuntimeWidgetHeight = 104
    }
}
