//
//  MainTabView.swift
//  TennisTracker
//
//  Created by Kavin Rajasekaran on 2025-05-01.
//


import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Log Match", systemImage: "square.and.pencil")
                }

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "list.number")
                }
            
            DebugView()
                .tabItem {
                    Label("Debug", systemImage: "wrench.and.screwdriver")
                }
        }
    }
}
