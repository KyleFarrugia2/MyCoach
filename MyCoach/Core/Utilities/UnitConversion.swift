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
    /// Sleep duration typed as "7.5", "7,5", "7:30", "7h30" or "7h" → hours (0…24). Mirrors `parseHours` in
    /// web/src/engines/units.ts.
    static func parseHours(_ text: String) -> Double? {
        let t = text.lowercased().filter { !$0.isWhitespace }
        guard !t.isEmpty else { return nil }
        if let sep = t.firstIndex(where: { $0 == ":" || $0 == "h" }) {
            let hPart = String(t[..<sep])
            var mPart = String(t[t.index(after: sep)...])
            if mPart.hasSuffix("m") { mPart.removeLast() }
            guard (1...2).contains(hPart.count), hPart.allSatisfy(\.isNumber), let h = Int(hPart) else { return nil }
            if mPart.isEmpty { return h <= 24 ? Double(h) : nil }
            guard mPart.count <= 2, mPart.allSatisfy(\.isNumber), let m = Int(mPart), m < 60, h <= 24 else { return nil }
            return Double(h) + Double(m) / 60
        }
        guard let n = Double(t.replacingOccurrences(of: ",", with: ".")), n >= 0, n <= 24 else { return nil }
        return n
    }

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
