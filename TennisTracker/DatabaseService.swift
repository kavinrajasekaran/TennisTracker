import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

// MARK: - Database Service

@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    
    private let db = Firestore.firestore()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Authentication
    
    func authenticateUser() async throws -> String {
        print("🔐 Attempting to authenticate user...")
        
        if let currentUser = Auth.auth().currentUser {
            print("🔐 Found existing user: \(currentUser.uid)")
            return currentUser.uid
        } else {
            print("🔐 No existing user, signing in anonymously...")
            do {
                let result = try await Auth.auth().signInAnonymously()
                print("🔐 Anonymous sign-in successful: \(result.user.uid)")
                return result.user.uid
            } catch {
                print("❌ Anonymous sign-in failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - Player Management
    
    func savePlayer(_ player: Player) async throws {
        let userID = try await authenticateUser()
        try await db.collection("users").document(userID)
            .collection("players").document(player.id)
            .setData(try Firestore.Encoder().encode(player))
    }
    
    func fetchPlayers() async throws -> [Player] {
        let userID = try await authenticateUser()
        let snapshot = try await db.collection("users").document(userID)
            .collection("players").getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Player.self)
        }
    }
    
    func findOrCreatePlayer(name: String) async throws -> Player {
        let players = try await fetchPlayers()
        
        // Check if player already exists (case-insensitive)
        if let existingPlayer = players.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existingPlayer
        }
        
        // Create new player
        let newPlayer = Player(name: name)
        try await savePlayer(newPlayer)
        return newPlayer
    }
    
    func createOrUpdatePlayer(name: String) async throws -> Player {
        print("🏃 Creating/updating player: \(name)")
        
        // First check if player already exists
        if let existingPlayer = try await findPlayer(by: name) {
            print("🏃 Found existing player: \(existingPlayer.name)")
            return existingPlayer
        }
        
        print("🏃 Creating new player: \(name)")
        // Create new player
        let newPlayer = Player(name: name)
        
        do {
            let playerData = try Firestore.Encoder().encode(newPlayer)
            print("🏃 Encoded player data successfully")
            
            try await db.collection("players").document(newPlayer.id).setData(playerData)
            print("🏃 Player saved to Firestore: \(newPlayer.id)")
            
            return newPlayer
        } catch {
            print("❌ Failed to save player: \(error)")
            throw error
        }
    }
    
    // MARK: - Match Management
    
    func saveMatch(_ match: Match) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("🎾 Attempting to save match: \(match.id)")
            print("🎾 Teams: \(match.teams.map { $0.displayName })")
            print("🎾 Score: \(match.scoreString)")
            print("🎾 Sets count: \(match.sets.count)")
            
            // Basic validation - just ensure we have data
            guard !match.teams.isEmpty && !match.sets.isEmpty else {
                throw DatabaseError.invalidMatchData("Match must have teams and sets")
            }
            
            // For any number of sets, just ensure someone won each set
            for set in match.sets {
                guard set.team1Games != set.team2Games else {
                    throw DatabaseError.invalidMatchData("Sets cannot be tied")
                }
            }
            
            print("🎾 Basic validation passed")
            
            // Save match to Firestore
            let matchData = try Firestore.Encoder().encode(match)
            print("🎾 Encoded match data successfully")
            
            try await db.collection("matches").document(match.id).setData(matchData)
            print("🎾 Match saved to Firestore successfully")
            
            // Update player statistics
            try await updatePlayerStats(for: match)
            print("🎾 Player stats updated successfully")
            
            errorMessage = nil
        } catch {
            let errorMsg = "Failed to save match: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            print("❌ Full error: \(error)")
            errorMessage = errorMsg
            throw error
        }
    }
    
    func fetchMatches() async throws -> [Match] {
        let userID = try await authenticateUser()
        let snapshot = try await db.collection("matches")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Match.self)
        }
    }
    
    func fetchRecentMatches(limit: Int = 10) async throws -> [Match] {
        let userID = try await authenticateUser()
        let snapshot = try await db.collection("matches")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: Match.self)
        }
    }
    
    // MARK: - Statistics
    
    private func updatePlayerStats(for match: Match) async throws {
        let allPlayers = Set(match.teams.flatMap { $0.players })
        
        guard let winnerTeamIndex = match.winnerTeamIndex else {
            print("⚠️ No winner specified for match, skipping stats update")
            return
        }
        
        for player in allPlayers {
            var updatedPlayer = player
            
            // Update match count
            updatedPlayer.stats.matchesPlayed += 1
            
            // Check if player was on winning team
            let isWinner = match.teams[winnerTeamIndex].players.contains(player)
            if isWinner {
                updatedPlayer.stats.matchesWon += 1
            }
            
            // Update set statistics
            let playerTeamIndex = match.teams[0].players.contains(player) ? 0 : 1
            for set in match.sets {
                if set.winnerTeamIndex == playerTeamIndex {
                    updatedPlayer.stats.setsWon += 1
                    updatedPlayer.stats.gamesWon += (playerTeamIndex == 0) ? set.team1Games : set.team2Games
                    updatedPlayer.stats.gamesLost += (playerTeamIndex == 0) ? set.team2Games : set.team1Games
                } else {
                    updatedPlayer.stats.setsLost += 1
                    updatedPlayer.stats.gamesWon += (playerTeamIndex == 0) ? set.team1Games : set.team2Games
                    updatedPlayer.stats.gamesLost += (playerTeamIndex == 0) ? set.team2Games : set.team1Games
                }
            }
            
            try await savePlayer(updatedPlayer)
        }
    }
    
    func calculateHeadToHeadRecords(for player: Player) async throws -> [HeadToHeadRecord] {
        let matches = try await fetchMatches()
        var opponentRecords: [String: (wins: Int, losses: Int, opponent: Player)] = [:]
        
        for match in matches {
            // Skip matches without a winner
            guard let winnerTeamIndex = match.winnerTeamIndex else {
                continue
            }
            
            // Find which team the player is on
            guard let playerTeamIndex = match.teams.firstIndex(where: { $0.players.contains(player) }) else {
                continue
            }
            
            let opponentTeamIndex = playerTeamIndex == 0 ? 1 : 0
            let opponents = match.teams[opponentTeamIndex].players
            
            for opponent in opponents {
                let isWin = winnerTeamIndex == playerTeamIndex
                
                if var record = opponentRecords[opponent.id] {
                    if isWin {
                        record.wins += 1
                    } else {
                        record.losses += 1
                    }
                    opponentRecords[opponent.id] = record
                } else {
                    opponentRecords[opponent.id] = (
                        wins: isWin ? 1 : 0,
                        losses: isWin ? 0 : 1,
                        opponent: opponent
                    )
                }
            }
        }
        
        return opponentRecords.values.map { record in
            HeadToHeadRecord(
                opponent: record.opponent,
                wins: record.wins,
                losses: record.losses
            )
        }.sorted { $0.winPercentage > $1.winPercentage }
    }
    
    // MARK: - Search and Filtering
    
    func searchMatches(query: String) async throws -> [Match] {
        let matches = try await fetchMatches()
        
        guard !query.isEmpty else { return matches }
        
        return matches.filter { match in
            // Search in player names
            let playerNames = match.teams.flatMap { $0.players.map { $0.name.lowercased() } }
            let hasPlayerName = playerNames.contains { $0.contains(query.lowercased()) }
            
            // Search in location
            let hasLocation = match.location?.lowercased().contains(query.lowercased()) ?? false
            
            // Search in notes
            let hasNotes = match.notes?.lowercased().contains(query.lowercased()) ?? false
            
            return hasPlayerName || hasLocation || hasNotes
        }
    }
    
    func filterMatches(
        by matchType: MatchType? = nil,
        surface: CourtSurface? = nil,
        dateRange: DateInterval? = nil
    ) async throws -> [Match] {
        let matches = try await fetchMatches()
        
        return matches.filter { match in
            var includeMatch = true
            
            if let matchType = matchType {
                includeMatch = includeMatch && match.matchType == matchType
            }
            
            if let surface = surface {
                includeMatch = includeMatch && match.surface == surface
            }
            
            if let dateRange = dateRange {
                includeMatch = includeMatch && dateRange.contains(match.timestamp)
            }
            
            return includeMatch
        }
    }
    
    // MARK: - Data Validation and Cleanup
    
    func detectDuplicateMatches() async throws -> [(Match, Match)] {
        let matches = try await fetchMatches()
        var duplicates: [(Match, Match)] = []
        
        for i in 0..<matches.count {
            for j in (i+1)..<matches.count {
                let match1 = matches[i]
                let match2 = matches[j]
                
                // Check if matches are within 1 hour of each other and have same players
                let timeDifference = abs(match1.timestamp.timeIntervalSince(match2.timestamp))
                if timeDifference < 3600 { // 1 hour
                    let players1 = Set(match1.teams.flatMap { $0.players.map { $0.name } })
                    let players2 = Set(match2.teams.flatMap { $0.players.map { $0.name } })
                    
                    if players1 == players2 {
                        duplicates.append((match1, match2))
                    }
                }
            }
        }
        
        return duplicates
    }
    
    func findPlayer(by name: String) async throws -> Player? {
        print("🔍 Searching for player: \(name)")
        
        do {
            let querySnapshot = try await db.collection("players")
                .whereField("name", isEqualTo: name)
                .limit(to: 1)
                .getDocuments()
            
            if let document = querySnapshot.documents.first {
                print("🔍 Found player document: \(document.documentID)")
                let player = try document.data(as: Player.self)
                print("🔍 Decoded player: \(player.name)")
                return player
            } else {
                print("🔍 No player found with name: \(name)")
                return nil
            }
        } catch {
            print("❌ Error searching for player: \(error)")
            throw error
        }
    }
}

// MARK: - Error Types

enum DatabaseError: LocalizedError {
    case invalidMatchData(String)
    case playerNotFound(String)
    case authenticationFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMatchData(let message):
            return "Invalid match data: \(message)"
        case .playerNotFound(let name):
            return "Player not found: \(name)"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
} 