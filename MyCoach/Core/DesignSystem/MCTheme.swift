import SwiftUI

/// Central design tokens for My Coach — white / blue / navy / grey with semantic macro colours.
enum MCTheme {
    // MARK: - Brand colours

    enum ColorToken {
        static let brandBlue = Color("MCBrandBlue", bundle: .main)
        static let brandNavy = Color("MCBrandNavy", bundle: .main)
        static let brandBlueFallback = Color(red: 0.12, green: 0.45, blue: 0.95)
        static let brandNavyFallback = Color(red: 0.06, green: 0.12, blue: 0.28)

        static var primary: Color { brandBlueFallback }
        static var navy: Color { brandNavyFallback }

        static let protein = Color(red: 0.92, green: 0.72, blue: 0.12)
        static let carbohydrates = Color(red: 0.22, green: 0.72, blue: 0.42)
        static let fat = Color(red: 0.58, green: 0.38, blue: 0.85)
        static let calories = primary

        static let success = Color(red: 0.20, green: 0.70, blue: 0.45)
        static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)
        static let danger = Color(red: 0.88, green: 0.28, blue: 0.28)

        static let grey50 = Color(red: 0.97, green: 0.98, blue: 0.99)
        static let grey100 = Color(red: 0.94, green: 0.95, blue: 0.97)
        static let grey200 = Color(red: 0.88, green: 0.90, blue: 0.93)
        static let grey400 = Color(red: 0.60, green: 0.64, blue: 0.70)
        static let grey600 = Color(red: 0.40, green: 0.44, blue: 0.50)
        static let grey800 = Color(red: 0.18, green: 0.20, blue: 0.26)

        static let darkBackground = Color(red: 0.05, green: 0.07, blue: 0.12)
        static let darkElevated = Color(red: 0.10, green: 0.13, blue: 0.20)
        static let darkBorder = Color(red: 0.18, green: 0.22, blue: 0.32)
    }

    // MARK: - Semantic surfaces

    enum Surface {
        static func background(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.darkBackground : Color.white
        }

        static func elevated(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.darkElevated : Color.white
        }

        static func grouped(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.darkBackground : ColorToken.grey50
        }

        static func secondaryFill(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.darkBorder.opacity(0.55) : ColorToken.grey100
        }

        static func border(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.darkBorder : ColorToken.grey200
        }

        static func primaryText(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white : ColorToken.navy
        }

        static func secondaryText(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? ColorToken.grey400 : ColorToken.grey600
        }
    }

    // MARK: - Typography

    enum Typography {
        static let hero = Font.system(size: 34, weight: .bold, design: .rounded)
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let callout = Font.system(size: 15, weight: .medium, design: .default)
        static let subheadline = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .medium, design: .default)
        static let numericLarge = Font.system(size: 40, weight: .bold, design: .rounded).monospacedDigit()
        static let numeric = Font.system(size: 28, weight: .bold, design: .rounded).monospacedDigit()
        static let numericMedium = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
        static let numericSmall = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let screenHorizontal: CGFloat = 20
    }

    // MARK: - Radii

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadow {
        static func card(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            if scheme == .dark {
                return (Color.black.opacity(0.35), 12, 4)
            }
            return (ColorToken.navy.opacity(0.08), 16, 6)
        }
    }

    // MARK: - Animation

    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.28)
        static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
        static let ring = Animation.easeOut(duration: 0.7)
    }

    // MARK: - Macro helpers

    enum MacroKind: String, CaseIterable, Identifiable {
        case calories
        case protein
        case carbohydrates
        case fat

        var id: String { rawValue }

        var label: String {
            switch self {
            case .calories: "Calories"
            case .protein: "Protein"
            case .carbohydrates: "Carbs"
            case .fat: "Fat"
            }
        }

        var shortLabel: String {
            switch self {
            case .calories: "kcal"
            case .protein: "P"
            case .carbohydrates: "C"
            case .fat: "F"
            }
        }

        var unit: String {
            switch self {
            case .calories: "kcal"
            case .protein, .carbohydrates, .fat: "g"
            }
        }

        var color: Color {
            switch self {
            case .calories: ColorToken.calories
            case .protein: ColorToken.protein
            case .carbohydrates: ColorToken.carbohydrates
            case .fat: ColorToken.fat
            }
        }

        var accessibilityLabel: String { label }
    }
}

// MARK: - View modifiers

struct MCCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = MCTheme.Shadow.card(colorScheme)
        content
            .background(MCTheme.Surface.elevated(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: MCTheme.Radius.lg, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

struct MCScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(MCTheme.Surface.grouped(colorScheme).ignoresSafeArea())
    }
}

extension View {
    func mcCardStyle() -> some View {
        modifier(MCCardStyle())
    }

    func mcScreenBackground() -> some View {
        modifier(MCScreenBackground())
    }
}
