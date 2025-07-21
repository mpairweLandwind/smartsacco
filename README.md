# 🏦 SmartSacco - Voice-First SACCO Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.32.6-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-green.svg)](https://firebase.google.com/)
[![MTN API](https://img.shields.io/badge/MTN%20API-Integrated-orange.svg)](https://momodeveloper.mtn.com/)
[![Accessibility](https://img.shields.io/badge/Accessibility-Voice%20First-purple.svg)](https://www.w3.org/WAI/)

A comprehensive SACCO (Savings and Credit Cooperative Organization) management application designed specifically for **blind and visually impaired users** with voice-first navigation, enhanced security, and complete MTN Mobile Money API integration.

## 🎯 Project Overview

SmartSacco is a Flutter-based mobile application that provides a complete SACCO management solution with:

- **🎤 Voice-First Navigation**: Complete voice command system for blind users
- **💳 MTN Mobile Money Integration**: Full payment processing via MTN API
- **🔐 Enhanced Security**: Biometric authentication and secure data handling
- **📊 Comprehensive Analytics**: Real-time tracking and reporting
- **♿ Accessibility Features**: Screen reader support and voice feedback
- **🌐 Multi-Platform**: Android, iOS, Web, and Desktop support

## ✨ Key Features

### 🎤 Voice Navigation System
- **Enhanced Voice Service**: Multi-accent speech recognition with flexible trigger words
- **Voice Commands**: Natural language processing for all app functions
- **Speech Synthesis**: Customizable text-to-speech with multiple voice configurations
- **Error Recovery**: Intelligent retry mechanisms and graceful fallbacks
- **Contextual Help**: Voice-guided assistance throughout the application

### 💰 Financial Management
- **Deposits**: Voice-activated deposits via MTN Mobile Money
- **Withdrawals**: Secure withdrawal processing with voice confirmation
- **Balance Checking**: Real-time account balance with voice feedback
- **Transaction History**: Complete transaction tracking and reporting
- **Loan Management**: Voice-controlled loan applications and repayments

### 🔐 Security & Authentication
- **Firebase Authentication**: Secure user registration and login
- **Role-Based Access**: Admin and member role management
- **PIN Protection**: Voice PIN entry for blind users
- **Session Management**: Secure session handling and timeout
- **Data Encryption**: Encrypted data storage and transmission

### 📱 User Experience
- **Accessibility Modes**: Multiple accessibility levels for different user needs
- **Voice Settings**: Customizable speech rate, pitch, and voice selection
- **Error Handling**: User-friendly error messages with voice feedback
- **Offline Support**: Basic functionality when offline
- **Deep Linking**: Email verification and password reset via deep links

## 🏗️ Architecture

### Core Services
```
lib/
├── services/
│   ├── enhanced_voice_service.dart      # Voice recognition & synthesis
│   ├── momoservices.dart                # MTN Mobile Money API
│   ├── payment_service.dart             # Payment processing
│   ├── auth.dart                        # Authentication service
│   ├── accessibility_service.dart       # Accessibility features
│   ├── analytics_service.dart           # User analytics
│   ├── notification_service.dart        # Push notifications
│   └── user_preferences_service.dart    # User settings
├── pages/
│   ├── splash_page.dart                 # Voice-enabled splash screen
│   ├── voicewelcome.dart                # Voice navigation welcome
│   ├── blinddashboard.dart              # Main voice dashboard
│   ├── voicelogin.dart                  # Voice login system
│   ├── voiceregister.dart               # Voice registration
│   ├── member_dashboard.dart            # Member dashboard
│   └── admin/                           # Admin management pages
├── models/                              # Data models
├── config/                              # Configuration files
└── utils/                               # Utility functions
```

### Technology Stack
- **Frontend**: Flutter 3.32.6
- **Backend**: Firebase (Firestore, Authentication, Storage)
- **Payment**: MTN Mobile Money API
- **Voice**: Flutter TTS + Speech to Text
- **Analytics**: Custom analytics service
- **Notifications**: Firebase Cloud Messaging

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.32.6 or higher
- Dart SDK 3.8.0 or higher
- Android Studio / VS Code
- Firebase project setup
- MTN API credentials

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/smartsacco.git
   cd smartsacco
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories
   - Enable Authentication, Firestore, and Storage

4. **Configure MTN API**
   - Update `lib/config/mtn_api_config.dart` with your MTN API credentials
   - Set up webhook server for payment callbacks
   - Configure sandbox/production environment

5. **Run the application**
   ```bash
   flutter run
   ```

### Environment Configuration

#### Firebase Setup
```dart
// lib/firebase_options.dart
// Configure your Firebase project settings
```

#### MTN API Configuration
```dart
// lib/config/mtn_api_config.dart
class MTNApiConfig {
  static const String collectionSubscriptionKey = 'your_key';
  static const String collectionApiUser = 'your_user';
  static const String collectionApiKey = 'your_api_key';
  static const bool isSandbox = true; // Set to false for production
}
```

## 🎤 Voice Navigation Guide

### Getting Started with Voice
1. **Launch the app** - Voice welcome message plays automatically
2. **Say "one"** - Activates voice navigation mode
3. **Follow voice prompts** - Navigate through all features using voice commands

### Voice Commands

#### Navigation Commands
- `"one"` - Activate voice navigation
- `"go to dashboard"` - Navigate to main dashboard
- `"go to profile"` - Access user profile
- `"go to settings"` - Open settings page
- `"go back"` - Return to previous screen

#### Financial Commands
- `"make deposit"` - Start deposit process
- `"make withdrawal"` - Start withdrawal process
- `"check balance"` - Get current balance
- `"view transactions"` - Show transaction history
- `"apply for loan"` - Start loan application

#### General Commands
- `"help"` - Get contextual help
- `"repeat"` - Repeat last instruction
- `"stop speaking"` - Stop current speech
- `"what can I say"` - List available commands

### Voice Settings
- **Speech Rate**: Adjustable from 0.1 to 1.0
- **Pitch**: Customizable voice pitch
- **Volume**: Adjustable speech volume
- **Voice Selection**: Multiple voice options
- **Accent Support**: Enhanced recognition for different accents

## 💳 Payment Integration

### MTN Mobile Money Features
- **Request to Pay**: Collection API for deposits
- **Transfer**: Disbursement API for withdrawals
- **Balance Checking**: Real-time account balance
- **Transaction Status**: Live transaction monitoring
- **Phone Validation**: Automatic phone number formatting

### Payment Flow
1. **User initiates payment** via voice command
2. **System validates** phone number and amount
3. **MTN API request** sent with proper authentication
4. **Transaction status** monitored in real-time
5. **Confirmation** sent via voice and notification
6. **Database updated** with transaction details

### Supported Operations
- ✅ Deposits (Request to Pay)
- ✅ Withdrawals (Transfer)
- ✅ Balance Inquiries
- ✅ Transaction History
- ✅ Payment Status Tracking
- ✅ Phone Number Validation

## 🔐 Security Features

### Authentication
- **Firebase Authentication**: Email/password and anonymous auth
- **Voice PIN System**: Secure PIN entry for blind users
- **Session Management**: Automatic session timeout
- **Role-Based Access**: Admin and member permissions

### Data Protection
- **Encrypted Storage**: Secure local data storage
- **API Security**: Signed requests to MTN API
- **Input Validation**: Comprehensive data validation
- **Error Handling**: Secure error messages

### Privacy
- **Data Minimization**: Only necessary data collected
- **User Control**: Full control over personal data
- **Transparency**: Clear data usage policies
- **Compliance**: GDPR and local privacy law compliance

## 📊 Analytics & Reporting

### User Analytics
- **Voice Command Tracking**: Monitor voice interaction patterns
- **Feature Usage**: Track most used features
- **Error Monitoring**: Identify and resolve issues
- **Performance Metrics**: App performance monitoring

### Financial Reports
- **Transaction Summaries**: Daily, weekly, monthly reports
- **Payment Success Rates**: Track payment completion rates
- **Revenue Analytics**: Financial performance insights
- **User Activity**: Member engagement metrics

### Admin Dashboard
- **Real-time Monitoring**: Live system status
- **Member Management**: User account administration
- **Loan Applications**: Loan approval workflow
- **System Reports**: Comprehensive system analytics

## ♿ Accessibility Features

### Voice-First Design
- **Complete Voice Navigation**: All features accessible via voice
- **Contextual Help**: Voice guidance throughout the app
- **Error Recovery**: Intelligent retry mechanisms
- **Flexible Commands**: Multiple ways to express the same intent

### Visual Accessibility
- **High Contrast Mode**: Enhanced visibility options
- **Large Text Support**: Adjustable text sizes
- **Screen Reader Integration**: Full screen reader compatibility
- **Haptic Feedback**: Tactile response for actions

### Customization
- **Voice Settings**: Personalized voice preferences
- **Accessibility Modes**: Different levels of assistance
- **Language Support**: Multi-language voice support
- **Speed Control**: Adjustable speech and interaction speed

## 🛠️ Development

### Project Structure
```
smartsacco/
├── lib/
│   ├── config/           # Configuration files
│   ├── models/           # Data models
│   ├── pages/            # UI pages
│   ├── services/         # Business logic services
│   ├── utils/            # Utility functions
│   └── widgets/          # Reusable UI components
├── android/              # Android-specific code
├── ios/                  # iOS-specific code
├── web/                  # Web platform code
├── test/                 # Test files
└── webhook-server/       # Payment callback server
```

### Key Dependencies
```yaml
dependencies:
  flutter: ^3.32.6
  firebase_core: ^3.15.1
  firebase_auth: ^5.6.2
  cloud_firestore: ^5.6.11
  flutter_tts: ^4.2.3
  speech_to_text: ^7.2.0
  http: ^1.4.0
  shared_preferences: ^2.5.3
  permission_handler: ^12.0.1
  logging: ^1.3.0
  uuid: ^4.3.3
  crypto: ^3.0.3
```

### Testing
```bash
# Run unit tests
flutter test

# Run widget tests
flutter test test/widget_test.dart

# Run integration tests
flutter drive --target=test_driver/app.dart
```

## 🚀 Deployment

### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Build iOS app
flutter build ios --release
```

### Web
```bash
# Build web app
flutter build web --release
```

## 📱 Platform Support

- ✅ **Android**: Full support with voice features
- ✅ **iOS**: Full support with voice features
- ✅ **Web**: Basic functionality (voice features limited)
- ✅ **Desktop**: Basic functionality (voice features limited)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter best practices
- Maintain accessibility standards
- Add comprehensive tests
- Update documentation
- Ensure voice navigation works

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Documentation
- [Voice Navigation Guide](VOICE_NAVIGATION_GUIDE.md)
- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

### Contact
- **Email**: support@smartsacco.com
- **Issues**: [GitHub Issues](https://github.com/yourusername/smartsacco/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/smartsacco/discussions)

### Community
- Join our [Discord Server](https://discord.gg/smartsacco)
- Follow us on [Twitter](https://twitter.com/smartsacco)
- Subscribe to our [Newsletter](https://smartsacco.com/newsletter)

## 🙏 Acknowledgments

- **MTN Group** for Mobile Money API
- **Firebase** for backend services
- **Flutter Team** for the amazing framework
- **Accessibility Community** for guidance and feedback
- **Open Source Contributors** for their valuable contributions

---

**Made with ❤️ for the visually impaired community**

*SmartSacco - Empowering financial independence through voice technology*

