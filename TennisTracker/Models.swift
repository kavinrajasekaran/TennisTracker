import Foundation
import FirebaseFirestore

// MARK: - Core Data Models

struct Player: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    var stats: PlayerStats
    
    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.stats = PlayerStats()
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PlayerStats: Codable {
    var matchesPlayed: Int = 0
    var matchesWon: Int = 0
    var setsWon: Int = 0
    var setsLost: Int = 0
    var gamesWon: Int = 0
    var gamesLost: Int = 0
    
    var winPercentage: Double {
        guard matchesPlayed > 0 else { return 0.0 }
        let percentage = Double(matchesWon) / Double(matchesPlayed) * 100.0
        return percentage.isFinite ? percentage : 0.0
    }
    
    var setWinPercentage: Double {
        let totalSets = setsWon + setsLost
        guard totalSets > 0 else { return 0.0 }
        let percentage = Double(setsWon) / Double(totalSets) * 100.0
        return percentage.isFinite ? percentage : 0.0
    }
}

struct Match: Identifiable, Codable {
    let id: String
    let userID: String
    let matchType: MatchType
    let teams: [Team]
    let sets: [GameSet]
    let winnerTeamIndex: Int?
    let timestamp: Date
    let location: String?
    let surface: CourtSurface?
    let notes: String?
    
    init(userID: String, matchType: MatchType, teams: [Team], sets: [GameSet], 
         winnerTeamIndex: Int?, location: String? = nil, surface: CourtSurface? = nil, notes: String? = nil) {
        self.id = UUID().uuidString
        self.userID = userID
        self.matchType = matchType
        self.teams = teams
        self.sets = sets
        self.winnerTeamIndex = winnerTeamIndex
        self.timestamp = Date()
        self.location = location
        self.surface = surface
        self.notes = notes
    }
    
    var scoreString: String {
        return sets.map { "\($0.team1Games)-\($0.team2Games)" }.joined(separator: ", ")
    }
}

struct Team: Codable, Identifiable {
    let id: String
    let players: [Player]
    
    init(players: [Player]) {
        self.id = UUID().uuidString
        self.players = players
    }
    
    var displayName: String {
        return players.map { $0.name }.joined(separator: " / ")
    }
}

struct GameSet: Codable, Identifiable {
    let id: String
    let team1Games: Int
    let team2Games: Int
    let team1TiebreakPoints: Int?
    let team2TiebreakPoints: Int?
    
    init(team1Games: Int, team2Games: Int, team1TiebreakPoints: Int? = nil, team2TiebreakPoints: Int? = nil) {
        self.id = UUID().uuidString
        self.team1Games = team1Games
        self.team2Games = team2Games
        self.team1TiebreakPoints = team1TiebreakPoints
        self.team2TiebreakPoints = team2TiebreakPoints
    }
    
    var winnerTeamIndex: Int {
        if team1Games > team2Games { return 0 }
        else if team2Games > team1Games { return 1 }
        else {
            // Tiebreak scenario
            if let tb1 = team1TiebreakPoints, let tb2 = team2TiebreakPoints {
                return tb1 > tb2 ? 0 : 1
            }
            return 0 // Default fallback
        }
    }
    
    var isTiebreak: Bool {
        return team1TiebreakPoints != nil || team2TiebreakPoints != nil
    }
}

// MARK: - Enums

enum MatchType: String, CaseIterable, Codable {
    case singles = "singles"
    case doubles = "doubles"
    
    var displayName: String {
        switch self {
        case .singles: return "Singles"
        case .doubles: return "Doubles"
        }
    }
    
    var maxPlayersPerTeam: Int {
        switch self {
        case .singles: return 1
        case .doubles: return 2
        }
    }
}

enum CourtSurface: String, CaseIterable, Codable {
    case hard = "hard"
    case clay = "clay"
    case grass = "grass"
    case indoor = "indoor"
    case carpet = "carpet"
    
    var displayName: String {
        switch self {
        case .hard: return "Hard Court"
        case .clay: return "Clay Court"
        case .grass: return "Grass Court"
        case .indoor: return "Indoor Court"
        case .carpet: return "Carpet Court"
        }
    }
    
    var icon: String {
        switch self {
        case .hard: return "square.fill"
        case .clay: return "circle.fill"
        case .grass: return "leaf.fill"
        case .indoor: return "house.fill"
        case .carpet: return "rectangle.fill"
        }
    }
}

// MARK: - Head-to-Head Record

struct HeadToHeadRecord: Identifiable {
    let id: String
    let opponent: Player
    let wins: Int
    let losses: Int
    let totalMatches: Int
    
    init(opponent: Player, wins: Int, losses: Int) {
        self.id = UUID().uuidString
        self.opponent = opponent
        self.wins = wins
        self.losses = losses
        self.totalMatches = wins + losses
    }
    
    var winPercentage: Double {
        guard totalMatches > 0 else { return 0.0 }
        let percentage = Double(wins) / Double(totalMatches) * 100.0
        return percentage.isFinite ? percentage : 0.0
    }
}

// MARK: - Match Validation

struct MatchValidation {
    static func validateSet(team1Games: Int, team2Games: Int, team1TiebreakPoints: Int?, team2TiebreakPoints: Int?) -> Bool {
        // Basic tennis set validation
        let maxGames = max(team1Games, team2Games)
        let minGames = min(team1Games, team2Games)
        
        // Standard set wins: 6-0, 6-1, 6-2, 6-3, 6-4
        if maxGames == 6 && minGames <= 4 {
            return true
        }
        
        // 7-5 set
        if maxGames == 7 && minGames == 5 {
            return true
        }
        
        // 7-6 with tiebreak
        if maxGames == 7 && minGames == 6 {
            return team1TiebreakPoints != nil && team2TiebreakPoints != nil
        }
        
        // Extended sets (rare but possible)
        if maxGames > 7 && (maxGames - minGames) == 2 {
            return true
        }
        
        return false
    }
    
    static func validateMatch(sets: [GameSet]) -> Bool {
        guard !sets.isEmpty && sets.count <= 5 else { return false }
        
        // Validate each set
        for set in sets {
            if !validateSet(team1Games: set.team1Games, team2Games: set.team2Games, 
                          team1TiebreakPoints: set.team1TiebreakPoints, team2TiebreakPoints: set.team2TiebreakPoints) {
                return false
            }
        }
        
        // Check match format (best of 3 or best of 5)
        let team1SetsWon = sets.filter { $0.winnerTeamIndex == 0 }.count
        let team2SetsWon = sets.filter { $0.winnerTeamIndex == 1 }.count
        
        if sets.count <= 3 {
            // Best of 3: winner needs 2 sets
            return max(team1SetsWon, team2SetsWon) >= 2
        } else {
            // Best of 5: winner needs 3 sets
            return max(team1SetsWon, team2SetsWon) >= 3
        }
    }
} 