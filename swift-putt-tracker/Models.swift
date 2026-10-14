import Foundation
import SwiftData
import SwiftUI

@Model
final class Round {
    var date: Date
    var golfClubName: String       // required
    var courseName: String         // required
    var teeColour: String          // TeeColour.rawValue
    var weather: String?
    var wind: String?
    var numberOfHoles: Int

    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    var holes: [HoleScore] = []

    init(
        date: Date = .now,
        golfClubName: String,
        courseName: String,
        teeColour: TeeColour = .green,
        weather: String? = nil,
        wind: String? = nil,
        numberOfHoles: Int = 9
    ) {
        self.date = date
        self.golfClubName = golfClubName
        self.courseName = courseName
        self.teeColour = teeColour.rawValue
        self.weather = weather
        self.wind = wind
        self.numberOfHoles = numberOfHoles
    }

    var totalPutts: Int {
        holes.map(\.totalPutts).reduce(0, +)
    }

    var averagePuttsPerHole: Double {
        guard !holes.isEmpty else { return 0 }
        return Double(totalPutts) / Double(holes.count)
    }
}

/// Tee box played from.
enum TeeColour: String, CaseIterable, Identifiable {
    case green = "Green"
    case white = "White"
    case yellow = "Yellow"
    case red = "Red"

    var id: String { rawValue }

    /// Swatch color shown next to the tee name in pickers.
    var color: Color {
        switch self {
        case .green: return .green
        case .white: return .white
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

/// Common weather conditions, offered as quick-pick options.
enum WeatherCondition: String, CaseIterable, Identifiable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case rainy = "Rainy"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        }
    }
}

/// Common wind conditions, offered as quick-pick options.
enum WindCondition: String, CaseIterable, Identifiable {
    case calm = "Calm"
    case light = "Light"
    case moderate = "Moderate"
    case strong = "Strong"

    var id: String { rawValue }
}

/// A putt distance bin. Every putt taken on a hole is logged into one of these.
enum PuttBin: String, CaseIterable, Identifiable {
    case short = "0–4 ft"
    case mid = "4–10 ft"
    case long = "10+ ft"

    var id: String { rawValue }
}

@Model
final class HoleScore {
    var holeNumber: Int
    var puttsShort: Int   // 0–4 ft
    var puttsMid: Int     // 4–10 ft
    var puttsLong: Int    // 10+ ft
    var usedPutterOffGreen: Bool   // took the putter to play a shot off the green, this hole
    var round: Round?

    init(holeNumber: Int, puttsShort: Int = 0, puttsMid: Int = 0, puttsLong: Int = 0, usedPutterOffGreen: Bool = false) {
        self.holeNumber = holeNumber
        self.puttsShort = puttsShort
        self.puttsMid = puttsMid
        self.puttsLong = puttsLong
        self.usedPutterOffGreen = usedPutterOffGreen
    }

    var totalPutts: Int {
        puttsShort + puttsMid + puttsLong
    }

    func count(for bin: PuttBin) -> Int {
        switch bin {
        case .short: return puttsShort
        case .mid: return puttsMid
        case .long: return puttsLong
        }
    }

    func increment(_ bin: PuttBin) {
        switch bin {
        case .short: puttsShort += 1
        case .mid: puttsMid += 1
        case .long: puttsLong += 1
        }
    }

    func decrement(_ bin: PuttBin) {
        switch bin {
        case .short: puttsShort = max(0, puttsShort - 1)
        case .mid: puttsMid = max(0, puttsMid - 1)
        case .long: puttsLong = max(0, puttsLong - 1)
        }
    }
}

// MARK: - v2 Phase 1: Golf Round Plan

/// Pre-round planning info captured before a round is played (v2 Phase 1).
/// Intentionally separate from `Round` so this stays isolated from the v1 schema;
/// a later phase can link a plan to the `Round` it becomes.
@Model
final class RoundPlan {
    var golfClubName: String
    var numberOfHoles: Int   // 9, 13, or 18
    var plannedTeeTime: Date
    var teeTimeBooked: Bool
    var players: [String]
    var partnersInformed: Bool
    var calendarUpdated: Bool

    init(
        golfClubName: String,
        numberOfHoles: Int = 9,
        plannedTeeTime: Date = .now,
        teeTimeBooked: Bool = false,
        players: [String] = [],
        partnersInformed: Bool = false,
        calendarUpdated: Bool = false
    ) {
        self.golfClubName = golfClubName
        self.numberOfHoles = numberOfHoles
        self.plannedTeeTime = plannedTeeTime
        self.teeTimeBooked = teeTimeBooked
        self.players = players
        self.partnersInformed = partnersInformed
        self.calendarUpdated = calendarUpdated
    }

    /// Phase 1's "done when": players, club and tee time are recorded, and
    /// booking, partner notification and calendar are all marked yes.
    var isReadyToPlay: Bool {
        !golfClubName.isEmpty && !players.isEmpty && teeTimeBooked && partnersInformed && calendarUpdated
    }
}
