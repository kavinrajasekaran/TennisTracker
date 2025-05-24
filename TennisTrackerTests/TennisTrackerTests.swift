//
//  TennisTrackerTests.swift
//  TennisTrackerTests
//
//  Created by Kavin Rajasekaran on 2025-05-01.
//

import Testing
import Foundation
@testable import TennisTracker

// MARK: - Model Tests

struct PlayerTests {
    
    @Test func testPlayerInitialization() {
        let player = Player(name: "John Doe")
        
        #expect(player.name == "John Doe")
        #expect(player.email == nil)
        #expect(player.stats.matchesPlayed == 0)
        #expect(player.stats.matchesWon == 0)
        #expect(player.stats.winPercentage == 0)
    }
    
    @Test func testPlayerStatsCalculation() {
        var stats = PlayerStats()
        stats.matchesPlayed = 10
        stats.matchesWon = 7
        stats.setsWon = 15
        stats.setsLost = 8
        
        #expect(stats.winPercentage == 70.0)
        #expect(abs(stats.setWinPercentage - 65.2173913043478) < 0.001)
    }
    
    @Test func testPlayerEquality() {
        let player1 = Player(id: "123", name: "John")
        let player2 = Player(id: "123", name: "Jane")
        let player3 = Player(id: "456", name: "John")
        
        #expect(player1 == player2) // Same ID
        #expect(player1 != player3) // Different ID
    }
}

// MARK: - Match Validation Tests

struct MatchValidationTests {
    
    @Test func testValidSets() {
        // Standard sets
        #expect(MatchValidation.validateSet(team1Games: 6, team2Games: 0, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        #expect(MatchValidation.validateSet(team1Games: 6, team2Games: 4, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        #expect(MatchValidation.validateSet(team1Games: 7, team2Games: 5, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        
        // Tiebreak sets
        #expect(MatchValidation.validateSet(team1Games: 7, team2Games: 6, team1TiebreakPoints: 7, team2TiebreakPoints: 5))
        #expect(MatchValidation.validateSet(team1Games: 6, team2Games: 7, team1TiebreakPoints: 4, team2TiebreakPoints: 7))
    }
    
    @Test func testInvalidSets() {
        // Invalid scores
        #expect(!MatchValidation.validateSet(team1Games: 6, team2Games: 5, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        #expect(!MatchValidation.validateSet(team1Games: 5, team2Games: 3, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        
        // Missing tiebreak
        #expect(!MatchValidation.validateSet(team1Games: 7, team2Games: 6, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        #expect(!MatchValidation.validateSet(team1Games: 6, team2Games: 7, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
    }
    
    @Test func testValidMatches() {
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        let set2 = GameSet(team1Games: 4, team2Games: 6)
        let set3 = GameSet(team1Games: 6, team2Games: 3)
        
        // Best of 3 match
        #expect(MatchValidation.validateMatch(sets: [set1, set2, set3]))
        
        // Straight sets
        #expect(MatchValidation.validateMatch(sets: [set1, GameSet(team1Games: 6, team2Games: 2)]))
    }
    
    @Test func testInvalidMatches() {
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        let set2 = GameSet(team1Games: 4, team2Games: 6)
        
        // Incomplete match
        #expect(!MatchValidation.validateMatch(sets: [set1, set2]))
        
        // Empty match
        #expect(!MatchValidation.validateMatch(sets: []))
        
        // Too many sets
        let manySets = Array(repeating: set1, count: 6)
        #expect(!MatchValidation.validateMatch(sets: manySets))
    }
}

// MARK: - GameSet Tests

struct GameSetTests {
    
    @Test func testSetWinnerDetermination() {
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        #expect(set1.winnerTeamIndex == 0)
        
        let set2 = GameSet(team1Games: 3, team2Games: 6)
        #expect(set2.winnerTeamIndex == 1)
        
        let tiebreakSet = GameSet(team1Games: 7, team2Games: 6, team1TiebreakPoints: 7, team2TiebreakPoints: 5)
        #expect(tiebreakSet.winnerTeamIndex == 0)
        #expect(tiebreakSet.isTiebreak)
    }
}

// MARK: - Match Tests

struct MatchTests {
    
    @Test func testMatchCreation() {
        let player1 = Player(name: "John")
        let player2 = Player(name: "Jane")
        let team1 = Team(players: [player1])
        let team2 = Team(players: [player2])
        
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        let set2 = GameSet(team1Games: 6, team2Games: 3)
        
        let match = Match(
            userID: "user123",
            matchType: .singles,
            teams: [team1, team2],
            sets: [set1, set2],
            winnerTeamIndex: 0,
            surface: .hard
        )
        
        #expect(match.matchType == .singles)
        #expect(match.teams.count == 2)
        #expect(match.sets.count == 2)
        #expect(match.winnerTeam.players.first?.name == "John")
        #expect(match.loserTeam.players.first?.name == "Jane")
        #expect(match.scoreString == "6-4, 6-3")
    }
    
    @Test func testMatchScoreString() {
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        let set2 = GameSet(team1Games: 4, team2Games: 6)
        let set3 = GameSet(team1Games: 7, team2Games: 6, team1TiebreakPoints: 7, team2TiebreakPoints: 3)
        
        let player1 = Player(name: "John")
        let player2 = Player(name: "Jane")
        let team1 = Team(players: [player1])
        let team2 = Team(players: [player2])
        
        let match = Match(
            userID: "user123",
            matchType: .singles,
            teams: [team1, team2],
            sets: [set1, set2, set3],
            winnerTeamIndex: 0
        )
        
        #expect(match.scoreString == "6-4, 4-6, 7-6 (7-3)")
    }
}

// MARK: - Team Tests

struct TeamTests {
    
    @Test func testTeamDisplayName() {
        let player1 = Player(name: "John")
        let player2 = Player(name: "Jane")
        
        // Singles team
        let singlesTeam = Team(players: [player1])
        #expect(singlesTeam.displayName == "John")
        
        // Doubles team
        let doublesTeam = Team(players: [player1, player2])
        #expect(doublesTeam.displayName == "John / Jane")
    }
}

// MARK: - Enum Tests

struct EnumTests {
    
    @Test func testMatchTypeProperties() {
        #expect(MatchType.singles.displayName == "Singles")
        #expect(MatchType.doubles.displayName == "Doubles")
        #expect(MatchType.singles.maxPlayersPerTeam == 1)
        #expect(MatchType.doubles.maxPlayersPerTeam == 2)
    }
    
    @Test func testCourtSurfaceProperties() {
        #expect(CourtSurface.hard.displayName == "Hard Court")
        #expect(CourtSurface.clay.displayName == "Clay Court")
        #expect(CourtSurface.grass.displayName == "Grass Court")
        #expect(CourtSurface.indoor.displayName == "Indoor Court")
        #expect(CourtSurface.carpet.displayName == "Carpet Court")
        
        #expect(!CourtSurface.hard.icon.isEmpty)
        #expect(!CourtSurface.clay.icon.isEmpty)
    }
}

// MARK: - Head-to-Head Tests

struct HeadToHeadTests {
    
    @Test func testHeadToHeadCalculation() {
        let player1 = Player(name: "John")
        let player2 = Player(name: "Jane")
        
        let record = HeadToHeadRecord(
            opponent: player2,
            wins: 7,
            losses: 3,
            totalMatches: 10
        )
        
        #expect(record.wins == 7)
        #expect(record.losses == 3)
        #expect(record.totalMatches == 10)
        #expect(record.winPercentage == 70.0)
    }
}

// MARK: - ViewModel Tests (if we can test synchronous parts)

struct MatchViewModelTests {
    
    @Test func testMatchValidation() async {
        let viewModel = await MatchViewModel()
        
        // Test empty validation
        let initialErrors = await viewModel.validateMatch()
        #expect(!initialErrors.isEmpty)
        
        // Test with some data
        await MainActor.run {
            viewModel.team1Players[0] = "John"
            viewModel.team2Players[0] = "Jane"
            viewModel.sets[0].team1Games = "6"
            viewModel.sets[0].team2Games = "4"
        }
        
        let errorsWithData = await viewModel.validateMatch()
        #expect(errorsWithData.count < initialErrors.count)
    }
    
    @Test func testMatchTypeChange() async {
        let viewModel = await MatchViewModel()
        
        await MainActor.run {
            viewModel.matchType = .doubles
            viewModel.team1Players = ["John", "Jane"]
            viewModel.team2Players = ["Bob", "Alice"]
            
            viewModel.matchType = .singles
            viewModel.onMatchTypeChanged()
            
            #expect(viewModel.team1Players[1].isEmpty)
            #expect(viewModel.team2Players[1].isEmpty)
        }
    }
}

// MARK: - Integration Tests

struct IntegrationTests {
    
    @Test func testCompleteMatchFlow() {
        // Create players
        let john = Player(name: "John Doe")
        let jane = Player(name: "Jane Smith")
        
        // Create teams
        let team1 = Team(players: [john])
        let team2 = Team(players: [jane])
        
        // Create sets
        let set1 = GameSet(team1Games: 6, team2Games: 4)
        let set2 = GameSet(team1Games: 6, team2Games: 3)
        
        // Validate sets
        #expect(MatchValidation.validateSet(team1Games: 6, team2Games: 4, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        #expect(MatchValidation.validateSet(team1Games: 6, team2Games: 3, team1TiebreakPoints: nil, team2TiebreakPoints: nil))
        
        // Create match
        let match = Match(
            userID: "user123",
            matchType: .singles,
            teams: [team1, team2],
            sets: [set1, set2],
            winnerTeamIndex: 0,
            surface: .hard
        )
        
        // Validate match
        #expect(MatchValidation.validateMatch(sets: match.sets))
        #expect(match.winnerTeam.players.first?.name == "John Doe")
        #expect(match.scoreString == "6-4, 6-3")
    }
}
