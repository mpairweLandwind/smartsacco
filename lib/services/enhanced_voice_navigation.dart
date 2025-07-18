import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:logging/logging.dart';
import 'smartsacco_audio_manager.dart';

class EnhancedVoiceNavigation {
  static final EnhancedVoiceNavigation _instance =
      EnhancedVoiceNavigation._internal();
  factory EnhancedVoiceNavigation() => _instance;
  EnhancedVoiceNavigation._internal();

  final Logger _logger = Logger('EnhancedVoiceNavigation');
  final SmartSaccoAudioManager _audioManager = SmartSaccoAudioManager();

  // Navigation state
  String _currentScreen = '';
  String _previousScreen = '';
  bool _isNavigating = false;
  bool _isListening = false;

  // Voice feedback settings
  bool _voiceFeedbackEnabled = true;
  bool _hapticFeedbackEnabled = true;
  double _speechRate = 0.5;
  double _volume = 1.0;

  // Stream controllers for navigation events
  final StreamController<String> _navigationEventController =
      StreamController<String>.broadcast();
  final StreamController<String> _voiceCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _screenTransitionController =
      StreamController<String>.broadcast();

  // Streams for UI to listen to
  Stream<String> get navigationEventStream => _navigationEventController.stream;
  Stream<String> get voiceCommandStream => _voiceCommandController.stream;
  Stream<String> get screenTransitionStream =>
      _screenTransitionController.stream;

  // Enhanced voice command patterns for seamless navigation
  static const Map<String, List<String>> _seamlessCommands = {
    // App Navigation
    'start_app': [
      'start app',
      'open app',
      'launch app',
      'begin',
      'start',
      'continue',
    ],
    'voice_mode': [
      'voice mode',
      'voice first',
      'blind mode',
      'accessibility mode',
      'voice navigation',
    ],
    'touch_mode': [
      'touch mode',
      'normal mode',
      'visual mode',
      'manual mode',
      'touch navigation',
    ],

    // Authentication
    'register': [
      'register',
      'sign up',
      'create account',
      'new account',
      'join',
      'voice register',
      'new user',
    ],
    'login': [
      'login',
      'sign in',
      'log in',
      'enter',
      'access account',
      'voice login',
      'existing user',
      'my account',
    ],
    'pin_entry': [
      'say pin',
      'enter pin',
      'speak pin',
      'voice pin',
      'my pin',
      'pin number',
      'security code',
    ],
    'confirm_pin': [
      'confirm',
      'yes',
      'correct',
      'that\'s right',
      'confirm pin',
      'proceed',
      'continue',
    ],
    'repeat_pin': [
      'repeat',
      'say again',
      'not clear',
      'didn\'t catch',
      'repeat pin',
      'repeat that',
    ],

    // Dashboard Navigation
    'go_home': [
      'go home',
      'home screen',
      'main menu',
      'dashboard',
      'main screen',
      'home',
      'main dashboard',
    ],
    'go_savings': [
      'savings',
      'check balance',
      'my money',
      'account balance',
      'balance',
      'savings balance',
      'my savings',
    ],
    'go_loans': [
      'loans',
      'my loans',
      'loan status',
      'borrowings',
      'loan',
      'loan balance',
      'my borrowings',
    ],
    'go_deposits': [
      'deposits',
      'make deposit',
      'save money',
      'add money',
      'deposit',
      'add to savings',
      'put money',
    ],
    'go_transactions': [
      'transactions',
      'history',
      'my history',
      'recent activity',
      'activity',
      'transaction history',
    ],
    'go_settings': [
      'settings',
      'preferences',
      'options',
      'configure',
      'settings',
      'voice settings',
      'app settings',
    ],
    'go_back': [
      'go back',
      'back',
      'previous screen',
      'return',
      'back to previous',
      'return to previous',
      'previous',
    ],

    // Financial Operations
    'check_balance': [
      'check balance',
      'my balance',
      'how much',
      'account balance',
      'balance',
      'what\'s my balance',
    ],
    'make_deposit': [
      'make deposit',
      'deposit money',
      'save money',
      'add money',
      'deposit',
      'add to account',
    ],
    'deposit_amount': [
      'deposit',
      'save',
      'add',
      'amount',
      'hundred',
      'thousand',
      'five hundred',
      'one thousand',
    ],
    'confirm_deposit': [
      'confirm',
      'yes',
      'proceed',
      'go ahead',
      'confirm deposit',
      'that\'s correct',
    ],
    'cancel_deposit': [
      'cancel',
      'no',
      'cancel deposit',
      'stop',
      'abort',
      'don\'t proceed',
    ],
    'check_loans': [
      'my loans',
      'loan status',
      'borrowings',
      'active loans',
      'loans',
      'loan balance',
    ],
    'apply_loan': [
      'apply loan',
      'new loan',
      'borrow money',
      'loan application',
      'apply',
      'request loan',
    ],
    'pay_loan': [
      'pay loan',
      'loan payment',
      'repay',
      'make payment',
      'pay',
      'repay loan',
    ],

    // Voice Control
    'help': [
      'help',
      'what can i say',
      'commands',
      'voice commands',
      'available commands',
      'what commands',
    ],
    'stop_listening': [
      'stop listening',
      'quiet',
      'mute',
      'pause',
      'stop voice',
      'silence',
      'stop microphone',
    ],
    'start_listening': [
      'start listening',
      'listen',
      'activate voice',
      'resume listening',
      'begin listening',
    ],
    'repeat': [
      'repeat',
      'say again',
      'what did you say',
      'repeat that',
      'say that again',
      'repeat last',
    ],

    // Settings
    'voice_settings': [
      'voice settings',
      'speech settings',
      'voice options',
      'speech options',
      'voice preferences',
    ],
    'change_language': [
      'change language',
      'language',
      'different language',
      'switch language',
      'set language',
    ],
    'adjust_speed': [
      'adjust speed',
      'speech speed',
      'talk faster',
      'talk slower',
      'speed',
      'speech rate',
    ],
    'adjust_volume': [
      'adjust volume',
      'volume',
      'louder',
      'quieter',
      'volume up',
      'volume down',
    ],

    // Emergency & Support
    'emergency': [
      'emergency',
      'help me',
      'sos',
      'call for help',
      'urgent',
      'emergency help',
    ],
    'contact_support': [
      'contact support',
      'support',
      'help desk',
      'customer service',
      'get help',
    ],
    'logout': [
      'logout',
      'sign out',
      'log out',
      'exit',
      'quit',
      'close app',
      'end session',
    ],
  };

  // Initialize the enhanced voice navigation
  Future<void> initialize() async {
    _logger.info('EnhancedVoiceNavigation initialized');
    _navigationEventController.add('initialized');
  }

  // Process voice commands with enhanced feedback
  Future<void> processVoiceCommand(String command) async {
    final lowerCommand = command.toLowerCase().trim();
    _logger.info('Processing enhanced voice command: $lowerCommand');

    // Provide haptic feedback for command recognition
    if (_hapticFeedbackEnabled) {
      await _provideHapticFeedback();
    }

    // Check for command matches
    for (final entry in _seamlessCommands.entries) {
      for (final pattern in entry.value) {
        if (lowerCommand.contains(pattern.toLowerCase())) {
          await _executeSeamlessCommand(entry.key, lowerCommand);
          return;
        }
      }
    }

    // Handle unknown commands with helpful feedback
    await _handleUnknownCommand(lowerCommand);
  }

  // Execute seamless commands with enhanced feedback
  Future<void> _executeSeamlessCommand(
    String commandType,
    String fullCommand,
  ) async {
    _logger.info('Executing seamless command: $commandType');

    // Provide voice confirmation
    if (_voiceFeedbackEnabled) {
      await _provideCommandConfirmation(commandType, fullCommand);
    }

    // Emit navigation event
    _voiceCommandController.add('$commandType:$fullCommand');
    _navigationEventController.add('command_executed:$commandType');

    // Handle specific command types
    switch (commandType) {
      case 'register':
        await _navigateToScreen('voice_register', 'Voice registration');
        break;
      case 'login':
        await _navigateToScreen('voice_login', 'Voice login');
        break;
      case 'go_home':
        await _navigateToScreen('member_dashboard', 'Member dashboard');
        break;
      case 'go_savings':
        await _navigateToScreen('savings', 'Savings screen');
        break;
      case 'go_loans':
        await _navigateToScreen('loans', 'Loans screen');
        break;
      case 'go_deposits':
        await _navigateToScreen('deposits', 'Deposits screen');
        break;
      case 'go_transactions':
        await _navigateToScreen('transactions', 'Transactions screen');
        break;
      case 'go_settings':
        await _navigateToScreen('settings', 'Settings screen');
        break;
      case 'go_back':
        await _navigateBack();
        break;
      case 'help':
        await _provideContextualHelp();
        break;
      case 'logout':
        await _handleLogout();
        break;
      default:
        _logger.info('Command type not handled: $commandType');
    }
  }

  // Provide enhanced command confirmation
  Future<void> _provideCommandConfirmation(
    String commandType,
    String fullCommand,
  ) async {
    String confirmation;
    switch (commandType) {
      case 'register':
        confirmation =
            "Taking you to voice registration. I'll guide you through creating your account step by step.";
        break;
      case 'login':
        confirmation =
            "Taking you to voice login. Please prepare to speak your PIN when prompted.";
        break;
      case 'go_home':
        confirmation = "Navigating to your member dashboard.";
        break;
      case 'go_savings':
        confirmation =
            "Opening your savings screen. You can check balance and make deposits.";
        break;
      case 'go_loans':
        confirmation =
            "Opening loans screen. You can view loan status and apply for new loans.";
        break;
      case 'go_deposits':
        confirmation =
            "Opening deposits screen. Say the amount you want to deposit.";
        break;
      case 'go_transactions':
        confirmation =
            "Opening transactions screen. View your recent activity.";
        break;
      case 'go_settings':
        confirmation =
            "Opening settings screen. Adjust voice preferences and app settings.";
        break;
      case 'go_back':
        confirmation = "Going back to previous screen.";
        break;
      case 'help':
        confirmation = "Providing help and available commands.";
        break;
      case 'logout':
        confirmation = "Logging you out. Thank you for using SmartSacco.";
        break;
      default:
        confirmation = "Processing your request.";
    }

    await _speakWithFeedback(confirmation);
  }

  // Navigate to screen with smooth transition
  Future<void> _navigateToScreen(String screenId, String screenName) async {
    if (_isNavigating) {
      await _speakWithFeedback("Navigation in progress. Please wait.");
      return;
    }

    _isNavigating = true;
    _previousScreen = _currentScreen;
    _currentScreen = screenId;

    _logger.info('Navigating from $_previousScreen to $_currentScreen');

    // Emit transition event
    _screenTransitionController.add('navigate:$screenId');

    // Provide transition feedback
    await _speakWithFeedback(
      "Navigating to $screenName. Please wait a moment.",
    );

    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 500));

    _isNavigating = false;
    _navigationEventController.add('navigation_completed:$screenId');
  }

  // Navigate back with context awareness
  Future<void> _navigateBack() async {
    if (_previousScreen.isEmpty) {
      await _speakWithFeedback("No previous screen to go back to.");
      return;
    }

    await _navigateToScreen(_previousScreen, "previous screen");
  }

  // Provide contextual help based on current screen
  Future<void> _provideContextualHelp() async {
    String helpMessage;
    switch (_currentScreen) {
      case 'splash':
        helpMessage =
            "Available commands: Say 'register' to create account, 'login' to sign in, 'voice mode' for voice-first experience, or tap screen to continue normally.";
        break;
      case 'member_dashboard':
        helpMessage =
            "Available commands: check balance, make deposit, my loans, transactions, settings, apply loan, help, logout.";
        break;
      case 'savings':
        helpMessage =
            "Available commands: check balance, make deposit, view history, go back, help.";
        break;
      case 'loans':
        helpMessage =
            "Available commands: check loans, apply loan, pay loan, loan status, go back, help.";
        break;
      case 'deposits':
        helpMessage =
            "Available commands: make deposit, hundred, thousand, five hundred, confirm, cancel, go back, help.";
        break;
      case 'transactions':
        helpMessage =
            "Available commands: view transactions, filter, export, go back, help.";
        break;
      case 'settings':
        helpMessage =
            "Available commands: voice settings, change language, security, logout, go back, help.";
        break;
      default:
        helpMessage = "Available commands: help, go back, voice commands.";
    }

    await _speakWithFeedback(helpMessage);
  }

  // Handle logout with confirmation
  Future<void> _handleLogout() async {
    await _speakWithFeedback(
      "Logging you out. Thank you for using SmartSacco. Have a great day!",
    );

    // Emit logout event
    _navigationEventController.add('logout');

    // Reset navigation state
    _currentScreen = '';
    _previousScreen = '';
  }

  // Handle unknown commands with helpful feedback
  Future<void> _handleUnknownCommand(String command) async {
    final availableCommands = _getAvailableCommandsForCurrentScreen();
    final message =
        "I didn't understand '$command'. Available commands: ${availableCommands.take(3).join(', ')}. Say 'help' for all commands.";

    await _speakWithFeedback(message);
    _voiceCommandController.add('unknown:$command');
  }

  // Get available commands for current screen
  List<String> _getAvailableCommandsForCurrentScreen() {
    switch (_currentScreen) {
      case 'splash':
        return ['register', 'login', 'voice mode', 'help'];
      case 'member_dashboard':
        return [
          'check balance',
          'make deposit',
          'my loans',
          'transactions',
          'settings',
          'help',
        ];
      case 'savings':
        return ['check balance', 'make deposit', 'go back', 'help'];
      case 'loans':
        return ['check loans', 'apply loan', 'pay loan', 'go back', 'help'];
      case 'deposits':
        return ['make deposit', 'confirm', 'cancel', 'go back', 'help'];
      case 'transactions':
        return ['view transactions', 'go back', 'help'];
      case 'settings':
        return ['voice settings', 'logout', 'go back', 'help'];
      default:
        return ['help', 'go back'];
    }
  }

  // Speak with enhanced feedback
  Future<void> _speakWithFeedback(String message) async {
    _logger.info('Speaking: $message');

    // Use SmartSaccoAudioManager if available, otherwise use direct TTS
    if (_currentScreen.isNotEmpty) {
      await _audioManager.speakIfActive(_currentScreen, message);
    }
  }

  // Provide haptic feedback
  Future<void> _provideHapticFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  // Set current screen
  void setCurrentScreen(String screenId) {
    _previousScreen = _currentScreen;
    _currentScreen = screenId;
    _logger.info('Current screen set to: $screenId');
  }

  // Get current screen
  String get currentScreen => _currentScreen;

  // Enable/disable voice feedback
  void setVoiceFeedback(bool enabled) {
    _voiceFeedbackEnabled = enabled;
  }

  // Enable/disable haptic feedback
  void setHapticFeedback(bool enabled) {
    _hapticFeedbackEnabled = enabled;
  }

  // Set speech rate
  void setSpeechRate(double rate) {
    _speechRate = rate.clamp(0.1, 1.0);
  }

  // Set volume
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  // Dispose resources
  void dispose() {
    _navigationEventController.close();
    _voiceCommandController.close();
    _screenTransitionController.close();
  }
}
