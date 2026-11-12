import Foundation

// MARK: - Golf Club JSON Decoding (Static Reference Data)

/// Root document structure for golf club JSON files.
struct GolfClubDocument: Codable {
    let fileHeader: FileHeader
    let golfClub: GolfClub
}

/// File metadata header.
struct FileHeader: Codable {
    let filename: String
    let id: Int
    let version: Int
    let creationDate: String
}

/// A golf club with one or more courses.
struct GolfClub: Codable {
    let name: String
    let phoneNumber: String
    let logoImage: String
    let numberOfGolfCourses: Int
    let type: String
    let crs: CRS
    let features: [GeoFeature]
    let courses: [Course]
}

/// Coordinate Reference System for GeoJSON data.
struct CRS: Codable {
    let type: String
    let properties: CRSProperties
}

struct CRSProperties: Codable {
    let name: String
}

/// A GeoJSON feature (e.g., clubhouse location, green boundaries).
struct GeoFeature: Codable {
    let type: String
    let geometry: Geometry
    let properties: FeatureProperties
}

/// GeoJSON geometry with support for Point and Polygon types.
struct Geometry: Codable {
    let type: String
    let coordinates: CoordinateValue
    
    enum CoordinateValue: Codable {
        case point([Double])
        case polygon([[[Double]]])
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let point = try? container.decode([Double].self) {
                self = .point(point)
            } else if let polygon = try? container.decode([[[Double]]].self) {
                self = .polygon(polygon)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid coordinate format"
                )
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .point(let coords):
                try container.encode(coords)
            case .polygon(let coords):
                try container.encode(coords)
            }
        }
    }
}

struct FeatureProperties: Codable {
    let name: String
}

/// A golf course within a club.
struct Course: Codable {
    let name: String
    let courseDescription: String
    let units: String
    let whsParameters: WHSParameters?
    let type: String?
    let crs: CRS?
    let features: [GeoFeature]?
    let courseDetails: [CourseDetail]
    let holeDetails: [HoleDetail]
}

/// World Handicap System parameters for different tee/gender combinations.
struct WHSParameters: Codable {
    let mensWhite18: RatingParameters?
    let mensGreen18: RatingParameters?
    let mensRed18: RatingParameters?
    let womensGreen18: RatingParameters?
    let womensRed18: RatingParameters?
    let mensWhiteFront9: RatingParameters?
    let mensGreenFront9: RatingParameters?
    let mensRedFront9: RatingParameters?
    let mensWhiteBack9: RatingParameters?
    let mensGreenBack9: RatingParameters?
    let mensRedBack9: RatingParameters?
    let womensGreenFront9: RatingParameters?
    let womensRedFront9: RatingParameters?
    let womensGreenBack9: RatingParameters?
    let womensRedBack9: RatingParameters?
}

/// Course and slope rating for handicap calculations.
struct RatingParameters: Codable {
    let courseRating: Double
    let slopeRating: Int
}

/// Summary details for a tee color.
struct CourseDetail: Codable {
    let teeType: String
    let teeColour: String
    let outPar: Int
    let inPar: Int
    let totalPar: Int
    let standardScratchScore: Int
    let outDistance: Int
    let inDistance: Int
    let totalDistance: Int
}

/// Details for a single hole.
struct HoleDetail: Codable {
    let number: Int
    let name: String
    let description: String
    let image: String
    let distances: [HoleDistance]
}

/// Distance, par and stroke index for a hole from a specific tee.
struct HoleDistance: Codable {
    let teeType: String
    let distance: Int
    let par: Int
    let strokeIndex: Int
}
