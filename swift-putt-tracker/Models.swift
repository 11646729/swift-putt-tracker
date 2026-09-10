import Foundation
import SwiftData

@Model
final class Round {
    var date: Date
    var courseName: String?
    var numberOfHoles: Int

    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    var holes: [HoleScore] = []

    init(date: Date = .now, courseName: String? = nil, numberOfHoles: Int = 18) {
        self.date = date
        self.courseName = courseName
        self.numberOfHoles = numberOfHoles
    }

    var totalPutts: Int {
        holes.reduce(0) { $0 + $1.putts }
    }

    var averagePuttsPerHole: Double {
        guard !holes.isEmpty else { return 0 }
        return Double(totalPutts) / Double(holes.count)
    }
}

@Model
final class HoleScore {
    var holeNumber: Int
    var putts: Int
    var round: Round?

    init(holeNumber: Int, putts: Int = 0) {
        self.holeNumber = holeNumber
        self.putts = putts
    }
}
