import Foundation

/// Service for loading golf club reference data from JSON files.
struct GolfClubLoader {
    
    enum LoadError: Error, LocalizedError {
        case fileNotFound(String)
        case decodingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "Golf club JSON file '\(filename)' not found in bundle"
            case .decodingFailed(let message):
                return "Failed to decode golf club data: \(message)"
            }
        }
    }
    
    /// Load a golf club document from a JSON file in the app bundle.
    /// - Parameter filename: Name of the JSON file without extension (e.g., "clandeboyeGolfClub")
    /// - Returns: Decoded golf club document
    /// - Throws: LoadError if file not found or decoding fails
    static func load(from filename: String) throws -> GolfClubDocument {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw LoadError.fileNotFound(filename)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(GolfClubDocument.self, from: data)
        } catch {
            throw LoadError.decodingFailed(error.localizedDescription)
        }
    }
    
    /// Load a golf club document from a URL.
    /// - Parameter url: URL to the JSON file
    /// - Returns: Decoded golf club document
    /// - Throws: LoadError if decoding fails
    static func load(from url: URL) throws -> GolfClubDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(GolfClubDocument.self, from: data)
        } catch {
            throw LoadError.decodingFailed(error.localizedDescription)
        }
    }
    
    /// Load multiple golf club documents from the app bundle.
    /// - Parameter filenames: Array of JSON filenames without extensions
    /// - Returns: Array of successfully loaded golf club documents
    static func loadAll(from filenames: [String]) -> [GolfClubDocument] {
        filenames.compactMap { filename in
            try? load(from: filename)
        }
    }
}

// MARK: - Convenience Extensions

extension GolfClubDocument {
    /// All courses across the golf club.
    var allCourses: [Course] {
        golfClub.courses
    }
    
    /// Find a course by name.
    func course(named name: String) -> Course? {
        golfClub.courses.first { $0.name == name }
    }
}

extension Course {
    /// Get course details for a specific tee type.
    func details(for teeType: String) -> CourseDetail? {
        courseDetails.first { $0.teeType.lowercased() == teeType.lowercased() }
    }
    
    /// Get hole details for a specific hole number.
    func hole(number: Int) -> HoleDetail? {
        holeDetails.first { $0.number == number }
    }
    
    /// All hole numbers in order.
    var holeNumbers: [Int] {
        holeDetails.map(\.number).sorted()
    }
}

extension HoleDetail {
    /// Get distance information for a specific tee type.
    func distance(for teeType: String) -> HoleDistance? {
        distances.first { $0.teeType.lowercased() == teeType.lowercased() }
    }
}
