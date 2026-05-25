import Foundation

enum OnboardingStore {
    static let completedKey = "jpad.onboardingCompleted"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}
