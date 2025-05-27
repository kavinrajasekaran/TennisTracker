import Foundation
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var players: [Player] = []
    @Published var matches: [Match] = []
    @Published var recentMatches: [Match] = []
    @Published var headToHeadRecords: [HeadToHeadRecord] = []
    
    // Filtering and Search
    @Published var searchText: String = ""
    @Published var selectedMatchType: MatchType?
    @Published var selectedSurface: CourtSurface?
    @Published var selectedDateRange: DateRangeFilter = .all
    @Published var sortCriteria: SortCriteria = .winPercentage
    
    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPlayer: Player?
    @Published var showingPlayerDetail = false
    
    private let databaseService = DatabaseService.shared
    
    // MARK: - Enums
    
    enum SortCriteria: String, CaseIterable {
        case winPercentage = "Win %"
        case totalWins = "Total Wins"
        case matchesPlayed = "Matches Played"
        case setWinPercentage = "Set Win %"
        case recentForm = "Recent Form"
        
        var icon: String {
            switch self {
            case .winPercentage: return "percent"
            case .totalWins: return "trophy.fill"
            case .matchesPlayed: return "number"
            case .setWinPercentage: return "chart.bar.fill"
            case .recentForm: return "clock.fill"
            }
        }
    }
    
    enum DateRangeFilter: String, CaseIterable {
        case all = "All Time"
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastThreeMonths = "Last 3 Months"
        case lastYear = "Last Year"
        
        var dateInterval: DateInterval? {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return nil
            case .lastWeek:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                return DateInterval(start: weekAgo, end: now)
            case .lastMonth:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
                return DateInterval(start: monthAgo, end: now)
            case .lastThreeMonths:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
                return DateInterval(start: threeMonthsAgo, end: now)
            case .lastYear:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
                return DateInterval(start: yearAgo, end: now)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredPlayers: [Player] {
        var filtered = players
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { player in
                player.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Filter by match criteria (this requires recalculating stats)
        if selectedMatchType != nil || selectedSurface != nil || selectedDateRange != .all {
            filtered = filtered.compactMap { player in
                let playerStats = calculateFilteredStats(for: player)
                guard playerStats.matchesPlayed > 0 else { return nil }
                
                var updatedPlayer = player
                updatedPlayer.stats = playerStats
                return updatedPlayer
            }
        }
        
        // Sort players
        return sortPlayers(filtered)
    }
    
    var topPerformers: [Player] {
        players.filter { $0.stats.matchesPlayed >= 3 }
            .sorted { $0.stats.winPercentage > $1.stats.winPercentage }
            .prefix(5)
            .map { $0 }
    }
    
    var totalMatches: Int {
        matches.count
    }
    
    var totalPlayers: Int {
        players.count
    }
    
    // MARK: - Initialization
    
    init() {
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        Task {
            isLoading = true
            
            do {
                async let playersTask = databaseService.fetchPlayers()
                async let matchesTask = databaseService.fetchMatches()
                async let recentMatchesTask = databaseService.fetchRecentMatches()
                
                players = try await playersTask
                matches = try await matchesTask
                recentMatches = try await recentMatchesTask
                
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func refreshData() {
        loadData()
    }
    
    func consolidateDuplicatePlayers() {
        Task {
            isLoading = true
            
            do {
                try await databaseService.consolidateDuplicatePlayers()
                // Reload data after consolidation
                loadData()
                errorMessage = nil
            } catch {
                errorMessage = "Failed to consolidate players: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Player Statistics
    
    private func calculateFilteredStats(for player: Player) -> PlayerStats {
        var stats = PlayerStats()
        
        let playerMatches = matches.filter { match in
            // Check if player participated in this match
            guard match.teams.contains(where: { $0.players.contains(player) }) else {
                return false
            }
            
            // Apply filters
            if let matchType = selectedMatchType, match.matchType != matchType {
                return false
            }
            
            if let surface = selectedSurface, match.surface != surface {
                return false
            }
            
            if let dateRange = selectedDateRange.dateInterval,
               !dateRange.contains(match.timestamp) {
                return false
            }
            
            return true
        }
        
        for match in playerMatches {
            stats.matchesPlayed += 1
            
            // Find player's team
            guard let playerTeamIndex = match.teams.firstIndex(where: { $0.players.contains(player) }) else {
                continue
            }
            
            // Check if player won (skip if no winner specified)
            if let winnerTeamIndex = match.winnerTeamIndex, winnerTeamIndex == playerTeamIndex {
                stats.matchesWon += 1
            }
            
            // Calculate set and game statistics
            for set in match.sets {
                if set.winnerTeamIndex == playerTeamIndex {
                    stats.setsWon += 1
                } else {
                    stats.setsLost += 1
                }
                
                stats.gamesWon += (playerTeamIndex == 0) ? set.team1Games : set.team2Games
                stats.gamesLost += (playerTeamIndex == 0) ? set.team2Games : set.team1Games
            }
        }
        
        return stats
    }
    
    private func sortPlayers(_ players: [Player]) -> [Player] {
        switch sortCriteria {
        case .winPercentage:
            return players.sorted { player1, player2 in
                if player1.stats.matchesPlayed == 0 && player2.stats.matchesPlayed == 0 {
                    return player1.name < player2.name
                }
                if player1.stats.matchesPlayed == 0 { return false }
                if player2.stats.matchesPlayed == 0 { return true }
                return player1.stats.winPercentage > player2.stats.winPercentage
            }
        case .totalWins:
            return players.sorted { $0.stats.matchesWon > $1.stats.matchesWon }
        case .matchesPlayed:
            return players.sorted { $0.stats.matchesPlayed > $1.stats.matchesPlayed }
        case .setWinPercentage:
            return players.sorted { player1, player2 in
                let total1 = player1.stats.setsWon + player1.stats.setsLost
                let total2 = player2.stats.setsWon + player2.stats.setsLost
                if total1 == 0 && total2 == 0 { return player1.name < player2.name }
                if total1 == 0 { return false }
                if total2 == 0 { return true }
                return player1.stats.setWinPercentage > player2.stats.setWinPercentage
            }
        case .recentForm:
            return players.sorted { player1, player2 in
                let form1 = calculateRecentForm(for: player1)
                let form2 = calculateRecentForm(for: player2)
                return form1 > form2
            }
        }
    }
    
    func calculateRecentForm(for player: Player, lastNMatches: Int = 5) -> Double {
        let playerMatches = matches
            .filter { match in
                match.teams.contains(where: { $0.players.contains(player) })
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(lastNMatches)
        
        guard !playerMatches.isEmpty else { return 0.0 }
        
        let wins = playerMatches.filter { match in
            guard let playerTeamIndex = match.teams.firstIndex(where: { $0.players.contains(player) }) else {
                return false
            }
            guard let winnerTeamIndex = match.winnerTeamIndex else {
                return false
            }
            return winnerTeamIndex == playerTeamIndex
        }.count
        
        let totalMatches = playerMatches.count
        guard totalMatches > 0 else { return 0.0 }
        
        let percentage = Double(wins) / Double(totalMatches) * 100.0
        return percentage.isFinite ? percentage : 0.0
    }
    
    // MARK: - Player Detail
    
    func showPlayerDetail(_ player: Player) {
        selectedPlayer = player
        loadHeadToHeadRecords(for: player)
        showingPlayerDetail = true
    }
    
    private func loadHeadToHeadRecords(for player: Player) {
        Task {
            do {
                headToHeadRecords = try await databaseService.calculateHeadToHeadRecords(for: player)
            } catch {
                errorMessage = "Failed to load head-to-head records: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Search and Filter Actions
    
    func clearFilters() {
        searchText = ""
        selectedMatchType = nil
        selectedSurface = nil
        selectedDateRange = .all
        sortCriteria = .winPercentage
    }
    
    func getMatches(for player: Player) -> [Match] {
        return matches.filter { match in
            match.teams.contains(where: { $0.players.contains(player) })
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Statistics Helpers
    
    func getWinStreak(for player: Player) -> Int {
        let playerMatches = matches
            .filter { match in
                match.teams.contains(where: { $0.players.contains(player) })
            }
            .sorted { $0.timestamp > $1.timestamp }
        
        var streak = 0
        for match in playerMatches {
            guard let playerTeamIndex = match.teams.firstIndex(where: { $0.players.contains(player) }) else {
                break
            }
            
            guard let winnerTeamIndex = match.winnerTeamIndex else {
                break
            }
            
            if winnerTeamIndex == playerTeamIndex {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    func getPlayerRank(for player: Player) -> Int? {
        guard let index = filteredPlayers.firstIndex(where: { $0.id == player.id }) else {
            return nil
        }
        return index + 1
    }
    
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
    
    func formatRecord(wins: Int, losses: Int) -> String {
        return "\(wins)-\(losses)"
    }
    
    // MARK: - Analytics
    
    var surfaceStatistics: [(surface: CourtSurface, matches: Int)] {
        let surfaceCounts = Dictionary(grouping: matches) { $0.surface }
            .mapValues { $0.count }
        
        return CourtSurface.allCases.compactMap { surface in
            guard let count = surfaceCounts[surface], count > 0 else { return nil }
            return (surface: surface, matches: count)
        }.sorted { $0.matches > $1.matches }
    }
    
    var matchTypeStatistics: [(type: MatchType, matches: Int)] {
        let typeCounts = Dictionary(grouping: matches) { $0.matchType }
            .mapValues { $0.count }
        
        return MatchType.allCases.compactMap { type in
            guard let count = typeCounts[type], count > 0 else { return nil }
            return (type: type, matches: count)
        }.sorted { $0.matches > $1.matches }
    }
} 