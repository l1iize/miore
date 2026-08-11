import AppKit
import CoreText
import SwiftUI

enum MioreFont {
    static let familyName = "Google Sans Flex"

    @discardableResult
    static func registerBundledFont() -> Bool {
        let bundle = Bundle.module
        let url = bundle.url(forResource: "GoogleSansFlex-Regular", withExtension: "ttf", subdirectory: "Fonts")
            ?? bundle.url(forResource: "GoogleSansFlex-Regular", withExtension: "ttf")
        guard let url else { return false }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if registered { return true }
        return NSFont(name: familyName, size: 12) != nil
    }

    static func font(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        guard design == .default else {
            return .system(size: size, weight: weight, design: design)
        }
        return .custom(familyName, size: size).weight(weight)
    }
}

extension Font {
    static func miore(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        MioreFont.font(size: size, weight: weight, design: design)
    }
}
