import Foundation
import SwiftUI

@MainActor
class MatchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var matchType: MatchType = .singles
    @Published var courtSurface: CourtSurface = .hard
    @Published var location: String = ""
    @Published var notes: String = ""
    
    // Teams and Players
    @Published var team1Players: [String] = ["", ""]
    @Published var team2Players: [String] = ["", ""]
    @Published var availablePlayers: [Player] = []
    @Published var showingPlayerSuggestions = false
    @Published var currentPlayerField: PlayerField?
    
    // Sets and Scoring
    @Published var sets: [SetInput] = [SetInput()]
    
    // UI State
    @Published var isLoading = false
    @Published var statusMessage: String = ""
    @Published var showingSuccess = false
    
    private let databaseService = DatabaseService.shared
    
    init() {
        loadAvailablePlayers()
    }
    
    // MARK: - Player Field Tracking
    enum PlayerField: Hashable {
        case team1Player1, team1Player2, team2Player1, team2Player2
    }
    
    // MARK: - Set Input Structure
    struct SetInput: Identifiable {
        let id = UUID()
        var team1Games: String = ""
        var team2Games: String = ""
        var team1TiebreakPoints: String = ""
        var team2TiebreakPoints: String = ""
        
        var requiresTiebreak: Bool {
            guard let t1 = Int(team1Games), let t2 = Int(team2Games) else { return false }
            return (t1 == 7 && t2 == 6) || (t1 == 6 && t2 == 7)
        }
        
        var isValid: Bool {
            guard let t1 = Int(team1Games), let t2 = Int(team2Games) else { return false }
            guard t1 != t2 && t1 >= 0 && t2 >= 0 && t1 <= 20 && t2 <= 20 else { return false }
            
            if requiresTiebreak {
                guard let tb1 = Int(team1TiebreakPoints), let tb2 = Int(team2TiebreakPoints) else { return false }
                guard tb1 >= 0 && tb2 >= 0 && tb1 <= 50 && tb2 <= 50 else { return false }
            }
            
            return true
        }
        
        func toGameSet() -> GameSet? {
            guard let t1 = Int(team1Games), let t2 = Int(team2Games) else { return nil }
            guard t1 != t2 && t1 >= 0 && t2 >= 0 && t1 <= 20 && t2 <= 20 else { return nil }
            
            if requiresTiebreak {
                guard let tb1 = Int(team1TiebreakPoints), let tb2 = Int(team2TiebreakPoints) else { return nil }
                return GameSet(team1Games: t1, team2Games: t2, team1TiebreakPoints: tb1, team2TiebreakPoints: tb2)
            } else {
                return GameSet(team1Games: t1, team2Games: t2)
            }
        }
    }
    
    // MARK: - Computed Properties
    var maxPlayersPerTeam: Int {
        matchType.maxPlayersPerTeam
    }
    
    var team1PlayersFiltered: [String] {
        Array(team1Players.prefix(maxPlayersPerTeam))
    }
    
    var team2PlayersFiltered: [String] {
        Array(team2Players.prefix(maxPlayersPerTeam))
    }
    
    var canAddSet: Bool {
        sets.count < 5 && !sets.isEmpty && sets.last?.isValid == true
    }
    
    // Automatically determine winner based on sets
    var calculatedWinnerTeamIndex: Int? {
        let validSets = sets.compactMap { $0.toGameSet() }
        guard !validSets.isEmpty else { return nil }
        
        let team1SetsWon = validSets.filter { $0.winnerTeamIndex == 0 }.count
        let team2SetsWon = validSets.filter { $0.winnerTeamIndex == 1 }.count
        
        // For single set matches, return the winner of that set
        if validSets.count == 1 {
            return validSets[0].winnerTeamIndex
        }
        
        // For multiple sets, check if someone has won the majority
        let requiredSetsToWin = validSets.count <= 3 ? 2 : 3
        
        if team1SetsWon >= requiredSetsToWin {
            return 0
        } else if team2SetsWon >= requiredSetsToWin {
            return 1
        }
        
        // If no clear winner yet, return nil
        return nil
    }
    
    var isMatchValid: Bool {
        let errors = validateMatch()
        return errors.isEmpty
    }
    
    // MARK: - Actions
    
    func onMatchTypeChanged() {
        // Clear extra players when switching from doubles to singles
        if matchType == .singles {
            team1Players[1] = ""
            team2Players[1] = ""
        }
    }
    
    func addSet() {
        guard canAddSet else { return }
        sets.append(SetInput())
    }
    
    func removeSet(at index: Int) {
        guard sets.count > 1 && index < sets.count else { return }
        sets.remove(at: index)
    }
    
    func getPlayerSuggestions(for query: String) -> [Player] {
        guard !query.isEmpty else { return availablePlayers }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        
        return availablePlayers.filter { player in
            player.name.lowercased().contains(trimmedQuery)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    func selectPlayer(_ player: Player, for field: PlayerField) {
        switch field {
        case .team1Player1:
            team1Players[0] = player.name
        case .team1Player2:
            team1Players[1] = player.name
        case .team2Player1:
            team2Players[0] = player.name
        case .team2Player2:
            team2Players[1] = player.name
        }
        
        currentPlayerField = nil
        showingPlayerSuggestions = false
    }
    
    // MARK: - Validation
    
    func validateMatch() -> [String] {
        var errors: [String] = []
        
        // Get actual player names, trimming whitespace
        let team1Names = team1PlayersFiltered.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        let team2Names = team2PlayersFiltered.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        // Check player count based on match type
        let requiredPlayers = matchType.maxPlayersPerTeam
        
        if team1Names.count < requiredPlayers {
            errors.append("Team 1 needs \(requiredPlayers) player(s)")
        }
        
        if team2Names.count < requiredPlayers {
            errors.append("Team 2 needs \(requiredPlayers) player(s)")
        }
        
        // Check for duplicate players
        let allPlayers = team1Names + team2Names
        let uniquePlayers = Set(allPlayers.map { $0.lowercased() })
        if allPlayers.count != uniquePlayers.count {
            errors.append("Players cannot appear on both teams")
        }
        
        // Check sets - ensure we have at least one valid set
        let validSets = sets.compactMap { $0.toGameSet() }
        
        if validSets.isEmpty {
            errors.append("At least one valid set is required")
        }
        
        // For multiple sets, ensure the match is complete (someone has won)
        if validSets.count > 1 && calculatedWinnerTeamIndex == nil {
            errors.append("Match is incomplete - no clear winner")
        }
        
        return errors
    }
    
    // MARK: - Save Match
    
    func saveMatch() async {
        print("🎾 MatchViewModel: Starting save match process...")
        isLoading = true
        
        let errors = validateMatch()
        if !errors.isEmpty {
            print("❌ MatchViewModel: Validation errors found: \(errors)")
            statusMessage = "Please check your match details: \(errors.first ?? "Invalid data")"
            isLoading = false
            return
        }
        
        do {
            print("🎾 MatchViewModel: Authenticating user...")
            let userID = try await databaseService.authenticateUser()
            
            print("🎾 MatchViewModel: Creating players...")
            // Create or find players
            let team1PlayerObjects = try await createPlayers(from: team1PlayersFiltered)
            let team2PlayerObjects = try await createPlayers(from: team2PlayersFiltered)
            
            print("🎾 MatchViewModel: Creating teams...")
            // Create teams
            let team1 = Team(players: team1PlayerObjects)
            let team2 = Team(players: team2PlayerObjects)
            
            print("🎾 MatchViewModel: Creating game sets...")
            // Create game sets
            let gameSets = sets.compactMap { $0.toGameSet() }
            
            guard !gameSets.isEmpty else {
                throw DatabaseError.invalidMatchData("No valid sets found")
            }
            
            print("🎾 MatchViewModel: Creating match object...")
            // Create match with calculated winner
            let match = Match(
                userID: userID,
                matchType: matchType,
                teams: [team1, team2],
                sets: gameSets,
                winnerTeamIndex: calculatedWinnerTeamIndex,
                location: location.isEmpty ? nil : location,
                surface: courtSurface,
                notes: notes.isEmpty ? nil : notes
            )
            
            print("🎾 MatchViewModel: Saving match to database...")
            // Save match
            try await databaseService.saveMatch(match)
            
            print("✅ MatchViewModel: Match saved successfully!")
            statusMessage = "Match saved successfully!"
            showingSuccess = true
            
            // Reset form
            await resetForm()
            
            // Reload available players
            loadAvailablePlayers()
            
        } catch {
            let errorMsg = "Failed to save match: \(error.localizedDescription)"
            print("❌ MatchViewModel: \(errorMsg)")
            print("❌ MatchViewModel: Full error: \(error)")
            statusMessage = errorMsg
        }
        
        isLoading = false
    }
    
    private func createPlayers(from playerNames: [String]) async throws -> [Player] {
        var players: [Player] = []
        
        for name in playerNames {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty {
                let player = try await databaseService.createOrUpdatePlayer(name: trimmedName)
                players.append(player)
            }
        }
        
        return players
    }
    
    // MARK: - Form Management
    
    func resetForm() async {
        team1Players = ["", ""]
        team2Players = ["", ""]
        sets = [SetInput()]
        location = ""
        notes = ""
        courtSurface = .hard
        matchType = .singles
        statusMessage = ""
        showingSuccess = false
    }
    
    func loadAvailablePlayers() {
        Task {
            do {
                let players = try await databaseService.fetchPlayers()
                await MainActor.run {
                    self.availablePlayers = players.sorted { $0.name < $1.name }
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Failed to load players: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Quick Match Templates
    
    func applyQuickTemplate(team1: [String], team2: [String], matchType: MatchType) {
        self.matchType = matchType
        self.team1Players = team1 + Array(repeating: "", count: max(0, 2 - team1.count))
        self.team2Players = team2 + Array(repeating: "", count: max(0, 2 - team2.count))
        onMatchTypeChanged()
    }
    
    // MARK: - Score Input Helpers
    
    func getScoreInputBinding(setIndex: Int, team: Int, isGames: Bool) -> Binding<String> {
        Binding(
            get: {
                guard setIndex < self.sets.count else { return "" }
                let set = self.sets[setIndex]
                
                if isGames {
                    return team == 1 ? set.team1Games : set.team2Games
                } else {
                    return team == 1 ? set.team1TiebreakPoints : set.team2TiebreakPoints
                }
            },
            set: { newValue in
                guard setIndex < self.sets.count else { return }
                
                if isGames {
                    if team == 1 {
                        self.sets[setIndex].team1Games = newValue
                    } else {
                        self.sets[setIndex].team2Games = newValue
                    }
                } else {
                    if team == 1 {
                        self.sets[setIndex].team1TiebreakPoints = newValue
                    } else {
                        self.sets[setIndex].team2TiebreakPoints = newValue
                    }
                }
            }
        )
    }
} 