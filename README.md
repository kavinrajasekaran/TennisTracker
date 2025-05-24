# TennisTracker 🎾

A comprehensive iOS app for tracking tennis matches with detailed statistics, player management, and analytics.

## Features

### 🏆 Match Logging
- **Singles & Doubles Support**: Track both singles and doubles matches
- **Professional Scoring**: Set-by-set scoring with tiebreak support
- **Court Surface Tracking**: Hard, clay, grass, indoor, and carpet courts
- **Player Autocomplete**: Smart suggestions based on existing players
- **Real-time Validation**: Tennis rules validation for accurate scoring

### 📊 Advanced Analytics
- **Win Percentage**: Overall and recent form tracking
- **Head-to-Head Records**: Player vs player statistics
- **Set & Game Statistics**: Detailed performance metrics
- **Surface Performance**: Track performance across different court types
- **Recent Form**: Last 5 matches performance indicator

### 👥 Player Management
- **Smart Player Creation**: Automatic player detection and creation
- **Statistics Tracking**: Comprehensive stats for each player
- **Search & Filter**: Find players and matches quickly
- **Leaderboard**: Multiple sorting criteria (win %, total wins, recent form)

### 🎨 Modern UI/UX
- **Dark Mode Support**: Full dark mode compatibility
- **Responsive Design**: Optimized for all iPhone sizes
- **Intuitive Interface**: Clean, modern SwiftUI design
- **Real-time Updates**: Live validation and feedback

## Technical Stack

- **Framework**: SwiftUI (iOS 17+)
- **Backend**: Firebase Firestore
- **Authentication**: Firebase Anonymous Auth
- **Architecture**: MVVM (Model-View-ViewModel)
- **Language**: Swift 5.9+

## Installation

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Firebase account

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/kavinrajasekaran/TennisTracker.git
   cd TennisTracker
   ```

2. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Firestore Database
   - Enable Anonymous Authentication
   - Download `GoogleService-Info.plist` from your Firebase project
   
   **⚠️ IMPORTANT: Security Setup**
   - Copy `GoogleService-Info-template.plist` to `GoogleService-Info.plist`
   - Replace all placeholder values with your actual Firebase configuration
   - **NEVER commit the real `GoogleService-Info.plist` to git** (it's already in .gitignore)
   
   ```bash
   # Copy the template and edit with your Firebase config
   cp GoogleService-Info-template.plist GoogleService-Info.plist
   # Edit GoogleService-Info.plist with your actual Firebase values
   ```

3. **Firestore Rules**
   Configure your Firestore rules to allow anonymous access:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

4. **Build and Run**
   - Open `TennisTracker.xcodeproj` in Xcode
   - Ensure `GoogleService-Info.plist` is added to your Xcode project
   - Select your target device/simulator
   - Build and run (⌘+R)

## Usage

### Logging a Match
1. Navigate to the "Log Match" tab
2. Select match type (Singles/Doubles)
3. Enter player names (autocomplete suggestions will appear)
4. Input set scores (6-4, 7-6, etc.)
5. Add tiebreak scores if needed (automatically detected for 7-6 sets)
6. Select court surface and add optional location/notes
7. Choose the winner and save

### Quick Testing
- In debug mode, use the "🐛 Quick Test Setup" button for instant valid match setup
- Check the "Validation Status" section to see real-time validation feedback

### Viewing Statistics
1. Go to the "Leaderboard" tab
2. Browse player rankings and statistics
3. Use search and filters to find specific data
4. Tap on any player to view detailed stats and recent matches
5. View head-to-head records between players

### Debug Features
- Use the "Debug" tab to test Firebase connectivity
- Check authentication status
- Test database operations

## Security & Deployment

### For Contributors
- **Never commit `GoogleService-Info.plist`** - use the template instead
- The real config file is automatically ignored by git
- Each developer needs their own Firebase project for development

### For Public Repositories
- Firebase configuration is kept private via .gitignore
- Template file shows required structure without exposing keys
- Production deployments use separate Firebase projects

## Data Models

### Player
- Unique ID, name, and comprehensive statistics
- Win/loss records, set statistics, game counts
- Calculated win percentages and recent form

### Match
- Teams, sets, winner, timestamp, location, surface, notes
- Complete match history with detailed scoring

### Set Scoring
- Individual set scores with tiebreak support
- Automatic winner determination
- Tennis rules validation

## Architecture

The app follows MVVM architecture with:

- **Models**: Core data structures (Player, Match, Team, GameSet)
- **ViewModels**: Business logic and state management
- **Views**: SwiftUI interface components
- **Services**: Firebase integration and data persistence

## Testing

The app includes comprehensive unit tests covering:
- Model validation and tennis scoring rules
- Match creation and statistics calculation
- Database operations and error handling

Run tests with: `⌘+U` in Xcode

## Contributing

1. Fork the repository
2. Set up your own Firebase project (don't use production config)
3. Create a feature branch (`git checkout -b feature/amazing-feature`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

**Security Guidelines:**
- Never commit real Firebase configurations
- Use the template file for setup instructions
- Each contributor should use their own Firebase project

## Future Enhancements

- [ ] Match video/photo attachments
- [ ] Tournament bracket management
- [ ] Social features and match sharing
- [ ] Apple Watch companion app
- [ ] Offline mode with sync
- [ ] Professional tournament data integration
- [ ] Advanced analytics and insights
- [ ] Export functionality (PDF reports)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:
- Create an issue on GitHub
- Check the Debug tab in the app for connectivity issues
- Ensure Firebase is properly configured with your own project

## Security Notice

This project uses Firebase for backend services. The `GoogleService-Info.plist` file contains sensitive configuration data and is excluded from version control. Use the provided template to set up your own Firebase configuration.

## Acknowledgments

- Tennis scoring rules and validation logic
- Firebase for backend services
- SwiftUI for modern iOS development
- The tennis community for inspiration

---

**Built with ❤️ for tennis enthusiasts** 