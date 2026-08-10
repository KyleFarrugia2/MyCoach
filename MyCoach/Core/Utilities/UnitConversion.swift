import Foundation

enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case kilogram
    case pound

    var shortLabel: String {
        switch self {
        case .kilogram: "kg"
        case .pound: "lb"
        }
    }
}

enum FoodMassUnit: String, Codable, CaseIterable, Sendable {
    case gram
    case ounce

    var shortLabel: String {
        switch self {
        case .gram: "g"
        case .ounce: "oz"
        }
    }
}

enum UnitConversion {
    static let poundsPerKilogram = 2.2046226218
    static let ouncesPerGram = 0.03527396195
    static let cmPerInch = 2.54
    static let inchesPerFoot = 12.0

    static func kilograms(from value: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilogram: value
        case .pound: value / poundsPerKilogram
        }
    }

    static func displayWeight(kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilogram: kg
        case .pound: kg * poundsPerKilogram
        }
    }

    static func grams(from value: Double, unit: FoodMassUnit) -> Double {
        switch unit {
        case .gram: value
        case .ounce: value / ouncesPerGram
        }
    }

    static func displayFoodMass(grams: Double, unit: FoodMassUnit) -> Double {
        switch unit {
        case .gram: grams
        case .ounce: grams * ouncesPerGram
        }
    }

    static func centimeters(feet: Double, inches: Double) -> Double {
        ((feet * inchesPerFoot) + inches) * cmPerInch
    }

    static func feetAndInches(fromCentimeters cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / cmPerInch
        let feet = Int(totalInches / inchesPerFoot)
        let inches = totalInches.truncatingRemainder(dividingBy: inchesPerFoot)
        return (feet, inches)
    }
}
