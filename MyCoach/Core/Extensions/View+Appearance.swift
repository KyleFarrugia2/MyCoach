import SwiftUI

extension View {
    /// Applies the user's AppearancePreference as a preferred color scheme.
    @ViewBuilder
    func applyingAppearance(_ preference: AppearancePreference) -> some View {
        switch preference {
        case .system:
            self
        case .light:
            preferredColorScheme(.light)
        case .dark:
            preferredColorScheme(.dark)
        }
    }
}

extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
