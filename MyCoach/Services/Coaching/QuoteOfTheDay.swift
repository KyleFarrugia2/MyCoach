import Foundation

struct Quote: Codable, Equatable, Sendable {
    /// Text and author (short keys keep the bundled JSON small).
    var t: String
    var a: String
}

/// Quote of the Day. The bundled collection (Resources/Data/quotes.json, built by Scripts/build_quotes.py) is
/// shuffled once with a fixed seed, then walked one quote per calendar day — every quote appears once before
/// any repeats, and Android (`web/src/engines/quotes.ts`) shows the same quote on the same day.
enum QuoteOfTheDay {
    static let seed: UInt32 = 20_261_115

    /// mulberry32 — reproduced bit-for-bit from the TypeScript implementation.
    struct Mulberry32 {
        private var a: UInt32

        init(seed: UInt32) {
            a = seed
        }

        mutating func nextUInt32() -> UInt32 {
            a = a &+ 0x6D2B_79F5
            var t = a
            t = (t ^ (t >> 15)) &* (t | 1)
            t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
            return t ^ (t >> 14)
        }

        mutating func next() -> Double {
            Double(nextUInt32()) / 4_294_967_296
        }
    }

    /// Fisher–Yates order of quote indexes for the seed.
    static func shuffledOrder(count: Int, seed: UInt32 = seed) -> [Int] {
        var order = Array(0..<count)
        var rng = Mulberry32(seed: seed)
        var i = count - 1
        while i > 0 {
            let j = Int(rng.next() * Double(i + 1))
            order.swapAt(i, j)
            i -= 1
        }
        return order
    }

    /// Whole days since 2026-01-01 for a calendar date (timezone-independent calendar arithmetic).
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let date = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return utc.dateComponents([.day], from: start, to: date).day ?? 0
    }

    static func index(year: Int, month: Int, day: Int, count: Int, order: [Int]? = nil) -> Int {
        let order = order ?? shuffledOrder(count: count)
        let n = ((dayNumber(year: year, month: month, day: day) % count) + count) % count
        return order[n]
    }

    /// Today's quote from the bundled collection (nil if the resource is missing).
    static func quote(for date: Date, calendar: Calendar = .current) -> Quote? {
        let quotes = bundled
        guard !quotes.isEmpty else { return nil }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return quotes[index(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1, count: quotes.count)]
    }

    /// Loaded once, lazily and thread-safely (static let).
    static let bundled: [Quote] = load(bundle: .main)

    static func load(bundle: Bundle) -> [Quote] {
        guard let url = bundle.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else { return [] }
        return quotes
    }
}
