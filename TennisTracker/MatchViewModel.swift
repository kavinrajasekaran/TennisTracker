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
    @Published var winnerTeamIndex: Int = 0
    
    // UI State
    @Published var isLoading = false
    @Published var statusMessage: String = ""
    @Published var showingSuccess = false
    @Published var validationErrors: [String] = []
    
    private let databaseService = DatabaseService.shared
    
    init() {
        loadAvailablePlayers()
        // Set up a simple test match for easier debugging
        setupQuickTestMatch()
    }
    
    // Helper method to set up a quick test match
    private func setupQuickTestMatch() {
        #if DEBUG
        // Delay to ensure the view is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.team1Players[0] = "Player 1"
            self.team2Players[0] = "Player 2"
            self.sets[0].team1Games = "6"
            self.sets[0].team2Games = "4"
            self.winnerTeamIndex = 0
            
            // Force update tiebreak requirement
            self.updateSetTiebreakRequirement(for: 0)
            
            print("🐛 Debug setup complete: t1='\(self.sets[0].team1Games)', t2='\(self.sets[0].team2Games)', tiebreak=\(self.sets[0].requiresTiebreak)")
            print("🐛 Debug setup isValid: \(self.sets[0].isValid)")
        }
        #endif
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
        var requiresTiebreak: Bool = false
        
        var isValid: Bool {
            guard let t1Games = Int(team1Games), let t2Games = Int(team2Games) else {
                print("🐛 SetInput.isValid: Failed to parse games - t1: '\(team1Games)', t2: '\(team2Games)'")
                return false
            }
            
            // Basic validation - just check that games are reasonable numbers
            guard t1Games >= 0 && t2Games >= 0 && t1Games <= 20 && t2Games <= 20 else {
                print("🐛 SetInput.isValid: Games out of range - t1: \(t1Games), t2: \(t2Games)")
                return false
            }
            
            // Must have a winner (someone has more games)
            guard t1Games != t2Games else {
                print("🐛 SetInput.isValid: Tied games - t1: \(t1Games), t2: \(t2Games)")
                return false
            }
            
            // If tiebreak is required, validate tiebreak points
            if requiresTiebreak {
                guard let t1TB = Int(team1TiebreakPoints), let t2TB = Int(team2TiebreakPoints) else {
                    print("🐛 SetInput.isValid: Tiebreak required but invalid points - t1TB: '\(team1TiebreakPoints)', t2TB: '\(team2TiebreakPoints)'")
                    return false
                }
                guard t1TB >= 0 && t2TB >= 0 && t1TB <= 50 && t2TB <= 50 else {
                    print("🐛 SetInput.isValid: Tiebreak points out of range - t1TB: \(t1TB), t2TB: \(t2TB)")
                    return false
                }
            }
            
            print("🐛 SetInput.isValid: Valid set - t1: \(t1Games), t2: \(t2Games), tiebreak: \(requiresTiebreak)")
            return true
        }
        
        func toGameSet() -> GameSet? {
            guard let t1Games = Int(team1Games), let t2Games = Int(team2Games) else {
                print("🐛 SetInput.toGameSet: Failed to parse games - t1: '\(team1Games)', t2: '\(team2Games)'")
                return nil
            }
            
            print("🐛 SetInput.toGameSet: t1Games=\(t1Games), t2Games=\(t2Games), requiresTiebreak=\(requiresTiebreak)")
            
            let t1TB = requiresTiebreak ? Int(team1TiebreakPoints) : nil
            let t2TB = requiresTiebreak ? Int(team2TiebreakPoints) : nil
            
            if requiresTiebreak {
                print("🐛 SetInput.toGameSet: Tiebreak required - t1TB: '\(team1TiebreakPoints)', t2TB: '\(team2TiebreakPoints)'")
                guard t1TB != nil && t2TB != nil else {
                    print("🐛 SetInput.toGameSet: Failed to parse tiebreak points")
                    return nil
                }
            }
            
            let gameSet = GameSet(team1Games: t1Games, team2Games: t2Games, 
                          team1TiebreakPoints: t1TB, team2TiebreakPoints: t2TB)
            
            print("🐛 SetInput.toGameSet: Created GameSet - winner: \(gameSet.winnerTeamIndex)")
            return gameSet
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
    
    var isMatchValid: Bool {
        let errors = validateMatch()
        // Debug: print validation errors
        if !errors.isEmpty {
            print("🐛 Match validation errors: \(errors)")
        }
        return errors.isEmpty
    }
    
    // Debug helper to show current validation status
    var validationDebugInfo: String {
        let errors = validateMatch()
        if errors.isEmpty {
            return "✅ Match is valid"
        } else {
            return "❌ Validation errors:\n" + errors.joined(separator: "\n")
        }
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
    
    func updateSetTiebreakRequirement(for setIndex: Int) {
        guard setIndex < sets.count else { return }
        
        let set = sets[setIndex]
        if let t1Games = Int(set.team1Games), let t2Games = Int(set.team2Games) {
            sets[setIndex].requiresTiebreak = (t1Games == 7 && t2Games == 6) || (t1Games == 6 && t2Games == 7)
        }
    }
    
    func getPlayerSuggestions(for query: String) -> [Player] {
        guard !query.isEmpty else { return availablePlayers }
        
        return availablePlayers.filter { player in
            player.name.lowercased().contains(query.lowercased())
        }.sorted { $0.name < $1.name }
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
        
        print("🐛 validateMatch: Starting validation...")
        
        // Validate players
        let team1Names = team1PlayersFiltered.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let team2Names = team2PlayersFiltered.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        print("🐛 validateMatch: team1Names=\(team1Names), team2Names=\(team2Names)")
        print("🐛 validateMatch: maxPlayersPerTeam=\(maxPlayersPerTeam)")
        
        if team1Names.count != maxPlayersPerTeam {
            errors.append("Team 1 needs \(maxPlayersPerTeam) player(s)")
        }
        
        if team2Names.count != maxPlayersPerTeam {
            errors.append("Team 2 needs \(maxPlayersPerTeam) player(s)")
        }
        
        // Check for duplicate players
        let allPlayers = team1Names + team2Names
        let uniquePlayers = Set(allPlayers.map { $0.lowercased() })
        if allPlayers.count != uniquePlayers.count {
            errors.append("Players cannot appear on both teams")
        }
        
        // Validate sets - be more lenient
        print("🐛 validateMatch: Checking sets... count=\(sets.count)")
        for (index, set) in sets.enumerated() {
            print("🐛 validateMatch: Set \(index): t1='\(set.team1Games)', t2='\(set.team2Games)', isValid=\(set.isValid)")
        }
        
        let validSets = sets.compactMap { $0.toGameSet() }
        print("🐛 validateMatch: validSets.count=\(validSets.count)")
        
        if validSets.isEmpty {
            errors.append("At least one valid set is required")
        }
        
        // Only validate match format if we have multiple sets
        if validSets.count > 1 && !MatchValidation.validateMatch(sets: validSets) {
            errors.append("Invalid match format or scores")
        }
        
        // Validate winner - only if we have sets and they're not tied
        if !validSets.isEmpty {
            let team1SetsWon = validSets.filter { $0.winnerTeamIndex == 0 }.count
            let team2SetsWon = validSets.filter { $0.winnerTeamIndex == 1 }.count
            
            print("🐛 validateMatch: team1SetsWon=\(team1SetsWon), team2SetsWon=\(team2SetsWon), winnerTeamIndex=\(winnerTeamIndex)")
            
            // Only validate winner if there's a clear winner
            if team1SetsWon != team2SetsWon {
                let actualWinnerIndex = team1SetsWon > team2SetsWon ? 0 : 1
                if winnerTeamIndex != actualWinnerIndex {
                    errors.append("Winner selection doesn't match the scores")
                }
            }
        }
        
        print("🐛 validateMatch: Final errors=\(errors)")
        return errors
    }
    
    // MARK: - Save Match
    
    func saveMatch() async {
        print("🎾 MatchViewModel: Starting save match process...")
        isLoading = true
        validationErrors = validateMatch()
        
        if !validationErrors.isEmpty {
            print("❌ MatchViewModel: Validation errors found: \(validationErrors)")
            statusMessage = "Please fix the errors above"
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
            // Create match
            let match = Match(
                userID: userID,
                matchType: matchType,
                teams: [team1, team2],
                sets: gameSets,
                winnerTeamIndex: winnerTeamIndex,
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
        winnerTeamIndex = 0
        location = ""
        notes = ""
        courtSurface = .hard
        matchType = .singles
        statusMessage = ""
        validationErrors = []
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
                
                // Update tiebreak requirement
                self.updateSetTiebreakRequirement(for: setIndex)
            }
        )
    }
} 