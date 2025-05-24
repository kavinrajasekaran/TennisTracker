#!/bin/bash

echo "🔥 TennisTracker Firebase Setup"
echo "==============================="
echo ""

# Check if GoogleService-Info.plist exists
if [ -f "GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist already exists"
    echo ""
    echo "⚠️  SECURITY REMINDER:"
    echo "   - This file contains sensitive API keys"
    echo "   - It's automatically ignored by git"
    echo "   - Never commit this file to version control"
    echo ""
else
    echo "📝 Setting up Firebase configuration..."
    echo ""
    
    if [ -f "GoogleService-Info-template.plist" ]; then
        echo "1. Copying template file..."
        cp GoogleService-Info-template.plist GoogleService-Info.plist
        echo "   ✅ GoogleService-Info.plist created from template"
        echo ""
        
        echo "2. Next steps:"
        echo "   📋 Go to Firebase Console: https://console.firebase.google.com"
        echo "   🔧 Create a new project or use existing one"
        echo "   📱 Add an iOS app to your project"
        echo "   📥 Download the GoogleService-Info.plist file"
        echo "   📝 Replace the template values with your actual config"
        echo ""
        
        echo "3. Required Firebase settings:"
        echo "   🔒 Enable Anonymous Authentication"
        echo "   💾 Enable Firestore Database"
        echo "   🛡️  Set Firestore rules to allow authenticated users"
        echo ""
        
        echo "4. Firestore Security Rules:"
        echo "   rules_version = '2';"
        echo "   service cloud.firestore {"
        echo "     match /databases/{database}/documents {"
        echo "       match /{document=**} {"
        echo "         allow read, write: if request.auth != null;"
        echo "       }"
        echo "     }"
        echo "   }"
        echo ""
        
        echo "⚠️  REMEMBER: Your GoogleService-Info.plist is gitignored for security!"
        echo ""
        
    else
        echo "❌ Template file not found!"
        echo "   Please ensure GoogleService-Info-template.plist exists"
    fi
fi

echo "🚀 Once configured, you can:"
echo "   - Open TennisTracker.xcodeproj in Xcode"
echo "   - Build and run the app"
echo "   - Use the Debug tab to test Firebase connectivity"
echo "   - Try the Quick Test Setup button for easy testing"
echo ""

echo "📚 For detailed instructions, see README.md" 