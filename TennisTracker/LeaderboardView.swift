//
//  LeaderboardView.swift
//  TennisTracker
//
//  Created by Kavin Rajasekaran on 2025-05-01.
//


import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistics Header
                statisticsHeader
                
                // Search and Filter Bar
                searchAndFilterBar
                
                // Leaderboard Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredPlayers.isEmpty {
                    emptyStateView
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data") {
                            viewModel.refreshData()
                        }
                        
                        Button("Consolidate Duplicate Players") {
                            viewModel.consolidateDuplicatePlayers()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                viewModel.refreshData()
            }
            .sheet(isPresented: $viewModel.showingPlayerDetail) {
                if let player = viewModel.selectedPlayer {
                    PlayerDetailView(player: player, viewModel: viewModel)
                }
            }
            .onAppear {
                if viewModel.players.isEmpty {
                    viewModel.loadData()
                }
            }
        }
    }
    
    // MARK: - Statistics Header
    
    private var statisticsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticCard(
                    title: "Total Players",
                    value: "\(viewModel.totalPlayers)",
                    icon: "person.3.fill"
                )
                
                StatisticCard(
                    title: "Total Matches",
                    value: "\(viewModel.totalMatches)",
                    icon: "sportscourt.fill"
                )
                
                if !viewModel.topPerformers.isEmpty {
                    StatisticCard(
                        title: "Top Performer",
                        value: viewModel.topPerformers.first!.name,
                        icon: "trophy.fill"
                    )
                }
            }
            
            if !viewModel.recentMatches.isEmpty {
                RecentMatchesCarousel(matches: Array(viewModel.recentMatches.prefix(3)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.7))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search players...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Sort: \(viewModel.sortCriteria.rawValue)",
                        icon: viewModel.sortCriteria.icon,
                        isSelected: false
                    ) {
                        // Show sort picker
                    }
                    
                    ForEach(MatchType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            icon: "figure.tennis",
                            isSelected: viewModel.selectedMatchType == type
                        ) {
                            viewModel.selectedMatchType = viewModel.selectedMatchType == type ? nil : type
                        }
                    }
                    
                    ForEach(LeaderboardViewModel.DateRangeFilter.allCases, id: \.self) { range in
                        if range != .all {
                            FilterChip(
                                title: range.rawValue,
                                icon: "calendar",
                                isSelected: viewModel.selectedDateRange == range
                            ) {
                                viewModel.selectedDateRange = viewModel.selectedDateRange == range ? .all : range
                            }
                        }
                    }
                    
                    if viewModel.selectedMatchType != nil || viewModel.selectedSurface != nil || viewModel.selectedDateRange != .all {
                        Button("Clear Filters") {
                            viewModel.clearFilters()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(16)
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading leaderboard...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Players Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start by logging your first match to see players on the leaderboard.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if viewModel.errorMessage != nil {
                Text(viewModel.errorMessage!)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Leaderboard List
    
    private var leaderboardList: some View {
        List {
            ForEach(Array(viewModel.filteredPlayers.enumerated()), id: \.element.id) { index, player in
                PlayerRowView(
                    player: player,
                    rank: index + 1,
                    sortCriteria: viewModel.sortCriteria,
                    onTap: {
                        viewModel.showPlayerDetail(player)
                    },
                    viewModel: viewModel
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct RecentMatchesCarousel: View {
    let matches: [Match]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Matches")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(matches) { match in
                        RecentMatchCard(match: match)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentMatchCard: View {
    let match: Match
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.teams[0].displayName)
                    .font(.caption)
                    .fontWeight(match.winnerTeamIndex == 0 ? .bold : .regular)
                    .foregroundColor(match.winnerTeamIndex == 0 ? .primary : .secondary)
                
                Spacer()
                
                Text("vs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(match.teams[1].displayName)
                    .font(.caption)
                    .fontWeight(match.winnerTeamIndex == 1 ? .bold : .regular)
                    .foregroundColor(match.winnerTeamIndex == 1 ? .primary : .secondary)
            }
            
            Text(match.scoreString)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(match.timestamp.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
        )
        .frame(width: 140)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct PlayerRowView: View {
    let player: Player
    let rank: Int
    let sortCriteria: LeaderboardViewModel.SortCriteria
    let onTap: () -> Void
    let viewModel: LeaderboardViewModel
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Rank
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                    
                    Text("\(rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Player Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatRecord)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Primary Statistic
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryStatValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(sortCriteria.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var formatRecord: String {
        return "\(player.stats.matchesWon)-\(player.stats.matchesPlayed - player.stats.matchesWon)"
    }
    
    private var primaryStatValue: String {
        switch sortCriteria {
        case .winPercentage:
            return String(format: "%.1f%%", player.stats.winPercentage)
        case .totalWins:
            return "\(player.stats.matchesWon)"
        case .matchesPlayed:
            return "\(player.stats.matchesPlayed)"
        case .setWinPercentage:
            return String(format: "%.1f%%", player.stats.setWinPercentage)
        case .recentForm:
            let recentForm = viewModel.calculateRecentForm(for: player)
            return String(format: "%.1f%%", recentForm)
        }
    }
}

// MARK: - Player Detail View

struct PlayerDetailView: View {
    let player: Player
    let viewModel: LeaderboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Player Header
                    VStack(spacing: 8) {
                        Text(player.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let rank = viewModel.getPlayerRank(for: player) {
                            Text("Rank #\(rank)")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    
                    // Statistics Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        StatDetailCard(title: "Win Rate", value: "\(String(format: "%.1f", player.stats.winPercentage))%", icon: "percent")
                        StatDetailCard(title: "Matches", value: "\(player.stats.matchesPlayed)", icon: "number")
                        StatDetailCard(title: "Wins", value: "\(player.stats.matchesWon)", icon: "trophy.fill")
                        StatDetailCard(title: "Set Win Rate", value: "\(String(format: "%.1f", player.stats.setWinPercentage))%", icon: "chart.bar.fill")
                    }
                    .padding(.horizontal)
                    
                    // Head-to-Head Records
                    if !viewModel.headToHeadRecords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Head-to-Head Records")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.headToHeadRecords.prefix(5)) { record in
                                HStack {
                                    Text(record.opponent.name)
                                    Spacer()
                                    Text("\(record.wins)-\(record.losses)")
                                        .foregroundColor(.secondary)
                                    Text("(\(String(format: "%.1f", record.winPercentage))%)")
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Recent Matches
                    let recentMatches = viewModel.getMatches(for: player).prefix(5)
                    if !recentMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Matches")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(recentMatches)) { match in
                                RecentMatchDetailCard(match: match, player: player)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Player Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatDetailCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct RecentMatchDetailCard: View {
    let match: Match
    let player: Player
    
    var body: some View {
        let playerTeamIndex = match.teams.firstIndex { $0.players.contains(player) }
        let isWinner = match.winnerTeamIndex == playerTeamIndex
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isWinner ? "WIN" : "LOSS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isWinner ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill((isWinner ? Color.green : Color.red).opacity(0.1))
                    )
                
                Spacer()
                
                Text(match.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("vs \(match.teams[(playerTeamIndex ?? 0) == 0 ? 1 : 0].displayName)")
                .font(.subheadline)
            
            Text(match.scoreString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    LeaderboardView()
}
