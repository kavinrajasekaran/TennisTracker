import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct ContentView: View {
    @StateObject private var viewModel = MatchViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                matchTypeSection
                teamsSection
                setsSection
                additionalInfoSection
                validationSection
                actionSection
            }
            .navigationTitle("Log Match")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadAvailablePlayers()
            }
            .alert("Match Saved", isPresented: $viewModel.showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your match has been saved successfully!")
            }
        }
    }
    
    // MARK: - Match Type Section
    
    private var matchTypeSection: some View {
        Section {
            Picker("Match Type", selection: $viewModel.matchType) {
                ForEach(MatchType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.matchType) { oldValue, newValue in
                viewModel.onMatchTypeChanged()
            }
            
            Picker("Court Surface", selection: $viewModel.courtSurface) {
                ForEach(CourtSurface.allCases, id: \.self) { surface in
                    Label(surface.displayName, systemImage: surface.icon)
                        .tag(surface)
                }
            }
        } header: {
            Text("Match Details")
        }
    }
    
    // MARK: - Teams Section
    
    private var teamsSection: some View {
        Group {
            Section {
                ForEach(0..<viewModel.maxPlayersPerTeam, id: \.self) { index in
                    playerField(
                        title: "Player \(index + 1)",
                        text: $viewModel.team1Players[index],
                        field: index == 0 ? .team1Player1 : .team1Player2
                    )
                }
            } header: {
                HStack {
                    Text("Team 1")
                    Spacer()
                    if !viewModel.team1PlayersFiltered.allSatisfy({ $0.isEmpty }) {
                        Text(viewModel.team1PlayersFiltered.filter { !$0.isEmpty }.joined(separator: " / "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                ForEach(0..<viewModel.maxPlayersPerTeam, id: \.self) { index in
                    playerField(
                        title: "Player \(index + 1)",
                        text: $viewModel.team2Players[index],
                        field: index == 0 ? .team2Player1 : .team2Player2
                    )
                }
            } header: {
                HStack {
                    Text("Team 2")
                    Spacer()
                    if !viewModel.team2PlayersFiltered.allSatisfy({ $0.isEmpty }) {
                        Text(viewModel.team2PlayersFiltered.filter { !$0.isEmpty }.joined(separator: " / "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func playerField(title: String, text: Binding<String>, field: MatchViewModel.PlayerField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onTapGesture {
                    viewModel.currentPlayerField = field
                    viewModel.showingPlayerSuggestions = true
                }
            
            if viewModel.currentPlayerField == field && viewModel.showingPlayerSuggestions {
                playerSuggestions(for: field, query: text.wrappedValue)
            }
        }
    }
    
    private func playerSuggestions(for field: MatchViewModel.PlayerField, query: String) -> some View {
        let suggestions = viewModel.getPlayerSuggestions(for: query)
        
        return LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions.prefix(5), id: \.id) { player in
                Button(action: {
                    viewModel.selectPlayer(player, for: field)
                }) {
                    HStack {
                        Text(player.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(player.stats.matchesWon)-\(player.stats.matchesPlayed - player.stats.matchesWon)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Sets Section
    
    private var setsSection: some View {
        Section {
            ForEach(Array(viewModel.sets.enumerated()), id: \.offset) { index, set in
                setInput(for: index)
            }
            
            if viewModel.canAddSet {
                Button("Add Set", action: viewModel.addSet)
                    .foregroundColor(.blue)
            }
            
            winnerSelection
            
        } header: {
            HStack {
                Text("Match Score")
                Spacer()
                if viewModel.sets.count > 1 {
                    Text("Best of \(viewModel.sets.count <= 3 ? "3" : "5")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func setInput(for index: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Set \(index + 1)")
                    .font(.headline)
                Spacer()
                
                if viewModel.sets.count > 1 {
                    Button("Remove") {
                        viewModel.removeSet(at: index)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                VStack {
                    Text("Team 1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Games", text: viewModel.getScoreInputBinding(setIndex: index, team: 1, isGames: true))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                }
                
                Text("-")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("Team 2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Games", text: viewModel.getScoreInputBinding(setIndex: index, team: 2, isGames: true))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                }
            }
            
            if viewModel.sets[index].requiresTiebreak {
                HStack(spacing: 12) {
                    VStack {
                        Text("TB")
                            .font(.caption)
                            .foregroundColor(.orange)
                        TextField("TB", text: viewModel.getScoreInputBinding(setIndex: index, team: 1, isGames: false))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("-")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        Text("TB")
                            .font(.caption)
                            .foregroundColor(.orange)
                        TextField("TB", text: viewModel.getScoreInputBinding(setIndex: index, team: 2, isGames: false))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Set validation indicator
            HStack {
                Image(systemName: viewModel.sets[index].isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(viewModel.sets[index].isValid ? .green : .red)
                Text(viewModel.sets[index].isValid ? "Valid set" : "Invalid score")
                    .font(.caption)
                    .foregroundColor(viewModel.sets[index].isValid ? .green : .red)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    private var winnerSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Winner")
                .font(.headline)
            
            Picker("Winner", selection: $viewModel.winnerTeamIndex) {
                Text("Team 1").tag(0)
                Text("Team 2").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Additional Info Section
    
    private var additionalInfoSection: some View {
        Section("Additional Information") {
            TextField("Location (optional)", text: $viewModel.location)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Validation Section
    
    private var validationSection: some View {
        Group {
            // Debug validation info
            Section("Validation Status") {
                Text(viewModel.validationDebugInfo)
                    .font(.caption)
                    .foregroundColor(viewModel.isMatchValid ? .green : .red)
            }
            
            if !viewModel.validationErrors.isEmpty {
                Section("Validation Errors") {
                    ForEach(viewModel.validationErrors, id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            
            if !viewModel.statusMessage.isEmpty {
                Section {
                    Label(viewModel.statusMessage, systemImage: viewModel.showingSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(viewModel.showingSuccess ? .green : .blue)
                }
            }
        }
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        Section {
            #if DEBUG
            Button("🐛 Quick Test Setup") {
                viewModel.validationErrors = []
                viewModel.statusMessage = ""
                viewModel.matchType = .singles
                viewModel.team1Players = ["Test Player 1", ""]
                viewModel.team2Players = ["Test Player 2", ""]
                viewModel.sets = [MatchViewModel.SetInput()]
                viewModel.sets[0].team1Games = "6"
                viewModel.sets[0].team2Games = "4"
                viewModel.winnerTeamIndex = 0
            }
            .foregroundColor(.orange)
            #endif
            
            Button(action: {
                Task {
                    await viewModel.saveMatch()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isLoading ? "Saving..." : "Save Match")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
            }
            .disabled(viewModel.isLoading || !viewModel.isMatchValid)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Reset Form") {
                Task {
                    await viewModel.resetForm()
                }
            }
            .foregroundColor(.red)
            .disabled(viewModel.isLoading)
        }
    }
}

#Preview {
    ContentView()
}
