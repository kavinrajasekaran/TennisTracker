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
        print("🏃 Creating/updating player: '\(name)'")
        
        let userID = try await authenticateUser()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Search for existing player by name (case-insensitive)
        let snapshot = try await db.collection("users").document(userID)
            .collection("players")
            .getDocuments()
        
        let existingPlayers = try snapshot.documents.compactMap { doc in
            try doc.data(as: Player.self)
        }
        
        print("🏃 Found \(existingPlayers.count) existing players in database")
        for existingPlayer in existingPlayers {
            print("   - \(existingPlayer.name) (ID: \(existingPlayer.id))")
        }
        
        // Check if player already exists (case-insensitive)
        if let existingPlayer = existingPlayers.first(where: { 
            $0.name.lowercased().trimmingCharacters(in: .whitespaces) == trimmedName.lowercased() 
        }) {
            print("🏃 Found existing player: \(existingPlayer.name) with ID: \(existingPlayer.id)")
            print("🏃 Current stats: \(existingPlayer.stats.matchesWon)/\(existingPlayer.stats.matchesPlayed) matches")
            return existingPlayer
        }
        
        print("🏃 Creating new player: '\(trimmedName)'")
        // Create new player with the properly formatted name
        let newPlayer = Player(name: trimmedName)
        
        do {
            let playerData = try Firestore.Encoder().encode(newPlayer)
            print("🏃 Encoded player data successfully")
            
            try await db.collection("users").document(userID)
                .collection("players").document(newPlayer.id)
                .setData(playerData)
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
        
        print("🎾 Updating stats for \(allPlayers.count) players")
        
        for player in allPlayers {
            print("🎾 Processing stats for player: \(player.name) (ID: \(player.id))")
            
            // Find the current player in the database by name (case-insensitive)
            let currentPlayers = try await fetchPlayers()
            guard let currentPlayer = currentPlayers.first(where: { 
                $0.name.lowercased().trimmingCharacters(in: .whitespaces) == player.name.lowercased().trimmingCharacters(in: .whitespaces)
            }) else {
                print("❌ Could not find player \(player.name) in database")
                continue
            }
            
            print("🎾 Found current player: \(currentPlayer.name) with \(currentPlayer.stats.matchesPlayed) matches played")
            
            var updatedPlayer = currentPlayer
            
            // Update match count
            updatedPlayer.stats.matchesPlayed += 1
            
            // Check if player was on winning team
            let isWinner = match.teams[winnerTeamIndex].players.contains { $0.name.lowercased() == player.name.lowercased() }
            if isWinner {
                updatedPlayer.stats.matchesWon += 1
                print("🎾 Player \(player.name) won this match")
            } else {
                print("🎾 Player \(player.name) lost this match")
            }
            
            // Update set statistics
            let playerTeamIndex = match.teams[0].players.contains { $0.name.lowercased() == player.name.lowercased() } ? 0 : 1
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
            
            print("🎾 Updated stats for \(updatedPlayer.name): \(updatedPlayer.stats.matchesWon)/\(updatedPlayer.stats.matchesPlayed) matches")
            
            try await savePlayer(updatedPlayer)
            print("✅ Saved updated player: \(updatedPlayer.name)")
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
    
    func recalculateAllPlayerStats() async throws {
        print("🔄 Starting player statistics recalculation...")
        let userID = try await authenticateUser()
        
        // Get all players and matches
        let players = try await fetchPlayers()
        let matches = try await fetchMatches()
        
        print("📊 Found \(players.count) players and \(matches.count) matches")
        
        // Reset all player stats
        var updatedPlayers: [Player] = []
        for player in players {
            var resetPlayer = player
            resetPlayer.stats = PlayerStats() // Reset to zero
            updatedPlayers.append(resetPlayer)
        }
        
        // Recalculate stats from all matches
        for match in matches {
            guard let winnerTeamIndex = match.winnerTeamIndex else {
                print("⚠️ Skipping match \(match.id) - no winner specified")
                continue
            }
            
            let allMatchPlayers = Set(match.teams.flatMap { $0.players })
            
            for matchPlayer in allMatchPlayers {
                // Find the corresponding player in our updated list
                guard let playerIndex = updatedPlayers.firstIndex(where: { 
                    $0.name.lowercased().trimmingCharacters(in: .whitespaces) == matchPlayer.name.lowercased().trimmingCharacters(in: .whitespaces)
                }) else {
                    print("⚠️ Could not find player \(matchPlayer.name) in player list")
                    continue
                }
                
                // Update match count
                updatedPlayers[playerIndex].stats.matchesPlayed += 1
                
                // Check if player won
                let isWinner = match.teams[winnerTeamIndex].players.contains { $0.name.lowercased() == matchPlayer.name.lowercased() }
                if isWinner {
                    updatedPlayers[playerIndex].stats.matchesWon += 1
                }
                
                // Update set and game statistics
                let playerTeamIndex = match.teams[0].players.contains { $0.name.lowercased() == matchPlayer.name.lowercased() } ? 0 : 1
                for set in match.sets {
                    if set.winnerTeamIndex == playerTeamIndex {
                        updatedPlayers[playerIndex].stats.setsWon += 1
                        updatedPlayers[playerIndex].stats.gamesWon += (playerTeamIndex == 0) ? set.team1Games : set.team2Games
                        updatedPlayers[playerIndex].stats.gamesLost += (playerTeamIndex == 0) ? set.team2Games : set.team1Games
                    } else {
                        updatedPlayers[playerIndex].stats.setsLost += 1
                        updatedPlayers[playerIndex].stats.gamesWon += (playerTeamIndex == 0) ? set.team1Games : set.team2Games
                        updatedPlayers[playerIndex].stats.gamesLost += (playerTeamIndex == 0) ? set.team2Games : set.team1Games
                    }
                }
            }
        }
        
        // Save all updated players
        for player in updatedPlayers {
            try await savePlayer(player)
            print("✅ Updated \(player.name): \(player.stats.matchesWon)/\(player.stats.matchesPlayed) matches")
        }
        
        print("✅ Player statistics recalculation completed")
    }
    
    func consolidateDuplicatePlayers() async throws {
        print("🔄 Starting player consolidation...")
        let userID = try await authenticateUser()
        let players = try await fetchPlayers()
        
        // Group players by name (case-insensitive)
        let playerGroups = Dictionary(grouping: players) { player in
            player.name.lowercased().trimmingCharacters(in: .whitespaces)
        }
        
        for (normalizedName, duplicatePlayers) in playerGroups {
            guard duplicatePlayers.count > 1 else { continue }
            
            print("🔄 Found \(duplicatePlayers.count) duplicate players for name: \(normalizedName)")
            
            // Keep the first player (or the one with most matches) as the primary
            let primaryPlayer = duplicatePlayers.max { p1, p2 in
                p1.stats.matchesPlayed < p2.stats.matchesPlayed
            } ?? duplicatePlayers[0]
            
            let duplicatePlayerIds = duplicatePlayers.filter { $0.id != primaryPlayer.id }.map { $0.id }
            
            // Merge statistics from all duplicates into the primary player
            var mergedStats = primaryPlayer.stats
            for duplicate in duplicatePlayers where duplicate.id != primaryPlayer.id {
                mergedStats.matchesPlayed += duplicate.stats.matchesPlayed
                mergedStats.matchesWon += duplicate.stats.matchesWon
                mergedStats.setsWon += duplicate.stats.setsWon
                mergedStats.setsLost += duplicate.stats.setsLost
                mergedStats.gamesWon += duplicate.stats.gamesWon
                mergedStats.gamesLost += duplicate.stats.gamesLost
            }
            
            // Update the primary player with merged stats and proper name formatting
            var updatedPrimaryPlayer = primaryPlayer
            updatedPrimaryPlayer.stats = mergedStats
            
            try await savePlayer(updatedPrimaryPlayer)
            
            // Update all matches to use the primary player ID
            try await updateMatchesWithConsolidatedPlayer(
                primaryPlayer: updatedPrimaryPlayer,
                duplicatePlayerIds: duplicatePlayerIds
            )
            
            // Delete duplicate player records
            for duplicateId in duplicatePlayerIds {
                try await db.collection("users").document(userID)
                    .collection("players").document(duplicateId)
                    .delete()
                print("🗑️ Deleted duplicate player: \(duplicateId)")
            }
        }
        
        print("✅ Player consolidation completed")
    }
    
    private func updateMatchesWithConsolidatedPlayer(primaryPlayer: Player, duplicatePlayerIds: [String]) async throws {
        let matches = try await fetchMatches()
        
        for match in matches {
            var needsUpdate = false
            var updatedMatch = match
            
            // Update teams to replace duplicate player references
            for (teamIndex, team) in match.teams.enumerated() {
                var updatedPlayers = team.players
                
                for (playerIndex, player) in team.players.enumerated() {
                    if duplicatePlayerIds.contains(player.id) {
                        updatedPlayers[playerIndex] = primaryPlayer
                        needsUpdate = true
                        print("🔄 Updated match \(match.id) to use consolidated player")
                    }
                }
                
                if needsUpdate {
                    updatedMatch.teams[teamIndex] = Team(players: updatedPlayers)
                }
            }
            
            // Save updated match if changes were made
            if needsUpdate {
                let matchData = try Firestore.Encoder().encode(updatedMatch)
                try await db.collection("matches").document(match.id).setData(matchData)
            }
        }
    }
    
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