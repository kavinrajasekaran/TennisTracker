import SwiftUI
import Firebase

struct DebugView: View {
    @StateObject private var databaseService = DatabaseService()
    @State private var debugMessages: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(debugMessages.indices, id: \.self) { index in
                            Text(debugMessages[index])
                                .font(.caption)
                                .foregroundColor(debugMessages[index].contains("❌") ? .red : 
                                               debugMessages[index].contains("✅") ? .green : .primary)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 300)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Test Authentication") {
                        testAuthentication()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Test Simple Save") {
                        testSimpleSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Clear Log") {
                        debugMessages.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                if isLoading {
                    ProgressView("Testing...")
                        .padding()
                }
            }
            .navigationTitle("Database Debug")
        }
    }
    
    private func addMessage(_ message: String) {
        DispatchQueue.main.async {
            debugMessages.append(message)
            print(message)
        }
    }
    
    private func testAuthentication() {
        isLoading = true
        addMessage("🔄 Starting authentication test...")
        
        Task {
            do {
                let userID = try await databaseService.authenticateUser()
                addMessage("✅ Authentication successful: \(userID)")
            } catch {
                addMessage("❌ Authentication failed: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    private func testSimpleSave() {
        isLoading = true
        addMessage("🔄 Starting simple save test...")
        
        Task {
            do {
                let userID = try await databaseService.authenticateUser()
                addMessage("✅ Authentication successful")
                
                // Create a simple test document
                let testData: [String: Any] = [
                    "timestamp": Date(),
                    "test": true,
                    "message": "Hello from TennisTracker debug"
                ]
                
                let db = Firestore.firestore()
                try await db.collection("debug_test").document("test_doc").setData(testData)
                addMessage("✅ Simple document save successful")
                
                // Try to read it back
                let doc = try await db.collection("debug_test").document("test_doc").getDocument()
                if doc.exists {
                    addMessage("✅ Document read back successfully")
                } else {
                    addMessage("❌ Document not found after save")
                }
                
            } catch {
                addMessage("❌ Simple save failed: \(error.localizedDescription)")
                addMessage("❌ Full error: \(error)")
            }
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
}

#Preview {
    DebugView()
} 