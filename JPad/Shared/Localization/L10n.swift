import Foundation

enum L10n {
    private static let fallbackBundle: Bundle = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }()

    static func string(_ key: String) -> String {
        let localized = NSLocalizedString(key, bundle: .main, comment: "")
        if localized != key {
            return localized
        }
        return NSLocalizedString(key, bundle: fallbackBundle, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
