import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:logging/logging.dart';

class SmartSaccoAudioManager {
  static final SmartSaccoAudioManager _instance =
      SmartSaccoAudioManager._internal();
  factory SmartSaccoAudioManager() => _instance;
  SmartSaccoAudioManager._internal();

  final Logger _logger = Logger('SmartSaccoAudioManager');

  String? _activeScreenId;
  final Map<String, FlutterTts> _screenTtsInstances = {};
  final Map<String, stt.SpeechToText> _screenSpeechInstances = {};

  // Stream controllers for audio events
  final StreamController<String> _audioControlController =
      StreamController<String>.broadcast();
  final StreamController<String> _screenActivationController =
      StreamController<String>.broadcast();
  final StreamController<String> _audioStatusController =
      StreamController<String>.broadcast();
  final StreamController<String> _voiceCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _navigationController =
      StreamController<String>.broadcast();

  // Audio transition management
  Timer? _transitionTimer;
  bool _isTransitioning = false;
  final List<String> _pendingAudioQueue = [];

  // Enhanced voice command patterns for seamless SmartSacco navigation
  static const Map<String, List<String>> _voiceCommandPatterns = {
    // App Start & Welcome
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

    // Authentication Flow
    'register': [
      'register',
      'sign up',
      'create account',
      'new account',
      'join',
      'voice register',
      'new user',
      'create profile',
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
      'say that again',
    ],

    // Seamless Navigation
    'go_home': [
      'go home',
      'home screen',
      'main menu',
      'dashboard',
      'main screen',
      'home',
      'main dashboard',
      'member dashboard',
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
      'my activity',
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
      'current balance',
    ],
    'make_deposit': [
      'make deposit',
      'deposit money',
      'save money',
      'add money',
      'deposit',
      'add to account',
      'put money in',
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
      'confirm amount',
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
      'what loans do i have',
    ],
    'apply_loan': [
      'apply loan',
      'new loan',
      'borrow money',
      'loan application',
      'apply',
      'request loan',
      'get loan',
    ],
    'pay_loan': [
      'pay loan',
      'loan payment',
      'repay',
      'make payment',
      'pay',
      'repay loan',
      'loan repayment',
    ],

    // Voice Control & Help
    'help': [
      'help',
      'what can i say',
      'commands',
      'voice commands',
      'available commands',
      'what commands',
      'show commands',
      'list commands',
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
      'turn on voice',
    ],
    'repeat': [
      'repeat',
      'say again',
      'what did you say',
      'repeat that',
      'say that again',
      'repeat last',
    ],

    // Settings & Preferences
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
      'speech volume',
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
      'support team',
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

  // Streams for UI to listen to
  Stream<String> get audioControlStream => _audioControlController.stream;
  Stream<String> get screenActivationStream =>
      _screenActivationController.stream;
  Stream<String> get audioStatusStream => _audioStatusController.stream;
  Stream<String> get voiceCommandStream => _voiceCommandController.stream;
  Stream<String> get navigationStream => _navigationController.stream;

  // Initialize the service
  Future<void> initialize() async {
    _logger.info('SmartSaccoAudioManager initialized');
    _audioStatusController.add('initialized');
  }

  // Register a screen for audio management
  void registerScreen(
    String screenId,
    FlutterTts tts,
    stt.SpeechToText speech,
  ) {
    _screenTtsInstances[screenId] = tts;
    _screenSpeechInstances[screenId] = speech;
    _logger.info('Screen registered: $screenId');
    _audioStatusController.add('registered:$screenId');
  }

  // Unregister a screen
  void unregisterScreen(String screenId) {
    _screenTtsInstances.remove(screenId);
    _screenSpeechInstances.remove(screenId);
    if (_activeScreenId == screenId) {
      _activeScreenId = null;
    }
    _logger.info('Screen unregistered: $screenId');
    _audioStatusController.add('unregistered:$screenId');
  }

  // Activate audio for a specific screen with smooth transition
  Future<void> activateScreenAudio(String screenId) async {
    _logger.info('Attempting to activate audio for screen: $screenId');

    if (_isTransitioning) {
      _logger.info(
        'Audio transition in progress, queuing activation for: $screenId',
      );
      _pendingAudioQueue.add('activate:$screenId');
      return;
    }

    _isTransitioning = true;
    _audioStatusController.add('transitioning:$screenId');

    try {
      // Deactivate audio for previously active screen
      if (_activeScreenId != null && _activeScreenId != screenId) {
        await _deactivateScreenAudio(_activeScreenId!);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Activate audio for new screen
      _activeScreenId = screenId;
      _audioControlController.add('activated:$screenId');
      _screenActivationController.add(screenId);
      _audioStatusController.add('activated:$screenId');

      // Provide context-aware voice guidance
      await _speakContextualHelp(screenId);

      _logger.info('Audio activated for screen: $screenId');
    } catch (e) {
      _logger.warning('Error activating audio for screen $screenId: $e');
      _audioStatusController.add('error:activation:$screenId');
    } finally {
      _isTransitioning = false;
      _processPendingAudioQueue();
    }
  }

  // Enhanced context-aware voice guidance for seamless navigation
  Future<void> _speakContextualHelp(String screenId) async {
    final tts = _screenTtsInstances[screenId];
    if (tts == null) return;

    String message;
    switch (screenId) {
      case 'splash':
        message =
            "Welcome to SmartSacco! Say 'register' to create a new account, 'login' to sign in with your PIN, or 'help' for available commands. You can also tap the screen to continue normally.";
        break;
      case 'voice_welcome':
        message =
            "Voice-first SmartSacco experience. Say 'register' to create account, 'login' to sign in, or 'help' for commands. I'll guide you through everything.";
        break;
      case 'voice_register':
        message =
            "Voice registration. I'll guide you through creating your account step by step. Tell me your full name, email, phone number, and a 4-digit PIN. Say 'help' anytime for assistance.";
        break;
      case 'voice_login':
        message =
            "Voice login. Please say your 4-digit PIN one digit at a time. For example, say 'one two three four' for PIN 1234. Say 'help' for assistance.";
        break;
      case 'member_dashboard':
        message =
            "Member dashboard. Say 'check balance' to hear your savings, 'my loans' for loan status, 'make deposit' to save money, 'transactions' for history, or 'settings' for options. Say 'help' for all commands.";
        break;
      case 'blind_dashboard':
        message =
            "Voice dashboard. Say 'check balance' for savings, 'my loans' for loans, 'make deposit' to save, 'transactions' for history, or 'settings' for options. Say 'help' for commands.";
        break;
      case 'savings':
        message =
            "Savings screen. Say 'check balance' to hear your current balance, 'make deposit' to add money, 'view history' for transactions, or 'go back' to return. Say 'help' for available commands.";
        break;
      case 'loans':
        message =
            "Loans screen. Say 'check loans' for your loan status, 'apply loan' for new loan, 'pay loan' for payments, or 'go back' to return. Say 'help' for available commands.";
        break;
      case 'deposits':
        message =
            "Deposits screen. Say the amount you want to deposit like 'hundred', 'thousand', or 'five hundred', then say 'confirm' to proceed. Say 'go back' to return. Say 'help' for available commands.";
        break;
      case 'transactions':
        message =
            "Transactions screen. View your recent activity and transaction history. Say 'filter' to search transactions, 'export' to download, or 'go back' to return. Say 'help' for available commands.";
        break;
      case 'settings':
        message =
            "Settings screen. Say 'voice settings' to adjust speech, 'change language' for language options, 'security' for account security, or 'go back' to return. Say 'help' for available commands.";
        break;
      case 'loan_application':
        message =
            "Loan application. I'll guide you through applying for a loan. Tell me the amount you need, purpose, and repayment period. Say 'help' for assistance.";
        break;
      case 'payment':
        message =
            "Payment screen. Say the amount you want to pay, choose payment method, then say 'confirm' to proceed. Say 'go back' to return. Say 'help' for available commands.";
        break;
      default:
        message =
            "Screen activated. Say 'help' for available commands or 'go back' to return.";
    }

    await tts.speak(message);
  }

  // Process pending audio operations
  void _processPendingAudioQueue() {
    if (_pendingAudioQueue.isNotEmpty) {
      final nextOperation = _pendingAudioQueue.removeAt(0);
      _processPendingAudioOperation(nextOperation);
    }
  }

  // Process pending audio operation
  void _processPendingAudioOperation(String operation) {
    if (operation.startsWith('activate:')) {
      final screenId = operation.split(':')[1];
      activateScreenAudio(screenId);
    } else if (operation.startsWith('speak:')) {
      final parts = operation.split(':');
      if (parts.length >= 3) {
        final screenId = parts[1];
        final text = parts.sublist(2).join(':');
        speakIfActive(screenId, text);
      }
    }
  }

  // Deactivate audio for a specific screen
  Future<void> deactivateScreenAudio(String screenId) async {
    if (_activeScreenId == screenId) {
      await _deactivateScreenAudio(screenId);
      _activeScreenId = null;
      _audioControlController.add('deactivated:$screenId');
      _audioStatusController.add('deactivated:$screenId');
      _logger.info('Audio deactivated for screen: $screenId');
    }
  }

  // Internal method to deactivate screen audio
  Future<void> _deactivateScreenAudio(String screenId) async {
    final tts = _screenTtsInstances[screenId];
    final speech = _screenSpeechInstances[screenId];

    if (tts != null) {
      try {
        await tts.stop();
        _logger.info('TTS stopped for screen: $screenId');
      } catch (e) {
        _logger.warning('Error stopping TTS for screen $screenId: $e');
      }
    }

    if (speech != null) {
      try {
        await speech.stop();
        _logger.info('Speech recognition stopped for screen: $screenId');
      } catch (e) {
        _logger.warning(
          'Error stopping speech recognition for screen $screenId: $e',
        );
      }
    }
  }

  // Check if a screen has active audio
  bool isScreenAudioActive(String screenId) {
    return _activeScreenId == screenId;
  }

  // Get the currently active screen
  String? get activeScreenId => _activeScreenId;

  // Speak text only if the screen is active
  Future<void> speakIfActive(String screenId, String text) async {
    if (_isTransitioning) {
      _logger.info(
        'Audio transition in progress, queuing speech for: $screenId',
      );
      _pendingAudioQueue.add('speak:$screenId:$text');
      return;
    }

    if (isScreenAudioActive(screenId)) {
      final tts = _screenTtsInstances[screenId];
      if (tts != null) {
        try {
          await tts.speak(text);
          _logger.info('Spoke text for screen $screenId: $text');
        } catch (e) {
          _logger.warning('Error speaking text for screen $screenId: $e');
        }
      }
    }
  }

  // Enhanced voice command processing with seamless navigation
  Future<void> processVoiceCommand(String command) async {
    final lowerCommand = command.toLowerCase().trim();
    _logger.info('Processing voice command: $lowerCommand');

    // Provide haptic feedback for command recognition
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    // Check for exact matches in command patterns
    for (final entry in _voiceCommandPatterns.entries) {
      for (final pattern in entry.value) {
        if (lowerCommand.contains(pattern.toLowerCase())) {
          _voiceCommandController.add('${entry.key}:$command');
          _navigationController.add(entry.key);

          // Provide voice confirmation for important commands
          await _provideCommandConfirmation(entry.key, command);

          _logger.info('Voice command matched: ${entry.key}');
          return;
        }
      }
    }

    // Handle unknown commands with helpful feedback
    await _handleUnknownCommand(lowerCommand);
    _voiceCommandController.add('unknown:$command');
  }

  // Provide voice confirmation for important commands
  Future<void> _provideCommandConfirmation(
    String commandType,
    String fullCommand,
  ) async {
    if (!isScreenAudioActive(_activeScreenId ?? '')) return;

    String confirmation;
    switch (commandType) {
      case 'register':
        confirmation =
            "Taking you to voice registration. I'll guide you through creating your account.";
        break;
      case 'login':
        confirmation =
            "Taking you to voice login. Please prepare to speak your PIN.";
        break;
      case 'make_deposit':
        confirmation =
            "Opening deposit screen. Say the amount you want to deposit.";
        break;
      case 'check_balance':
        confirmation = "Checking your balance. Please wait a moment.";
        break;
      case 'apply_loan':
        confirmation =
            "Opening loan application. I'll guide you through the process.";
        break;
      case 'go_back':
        confirmation = "Going back to previous screen.";
        break;
      case 'logout':
        confirmation = "Logging you out. Thank you for using SmartSacco.";
        break;
      default:
        confirmation = "Processing your request.";
    }

    await speakIfActive(_activeScreenId ?? '', confirmation);
  }

  // Handle unknown commands with helpful feedback
  Future<void> _handleUnknownCommand(String command) async {
    if (!isScreenAudioActive(_activeScreenId ?? '')) return;

    final availableCommands = getAvailableCommands(_activeScreenId ?? '');
    final message =
        "I didn't understand '$command'. Available commands: ${availableCommands.take(3).join(', ')}. Say 'help' for all commands.";

    await speakIfActive(_activeScreenId ?? '', message);
    _logger.info('Unknown command: $command');
  }

  // Enhanced continuous listening with seamless error handling
  Future<void> startContinuousListening(String screenId) async {
    final speech = _screenSpeechInstances[screenId];
    if (speech == null || !isScreenAudioActive(screenId)) return;

    try {
      // Stop any existing listening session to prevent conflicts
      await speech.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      // Initialize speech recognition with proper error handling
      bool available = await speech.initialize(
        onStatus: (status) {
          _logger.info('Speech status for $screenId: $status');
          if (status == 'done' || status == 'notListening') {
            // Auto-restart listening after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (isScreenAudioActive(screenId)) {
                startContinuousListening(screenId);
              }
            });
          }
        },
        onError: (error) {
          _logger.warning('Speech error for $screenId: ${error.errorMsg}');
          // Handle specific error types
          if (error.errorMsg.contains('error_busy')) {
            // Wait longer before retrying for busy errors
            Future.delayed(const Duration(seconds: 3), () {
              if (isScreenAudioActive(screenId)) {
                startContinuousListening(screenId);
              }
            });
          } else {
            // Retry for other errors
            Future.delayed(const Duration(seconds: 1), () {
              if (isScreenAudioActive(screenId)) {
                startContinuousListening(screenId);
              }
            });
          }
        },
      );

      if (available) {
        await speech.listen(
          onResult: (result) {
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              processVoiceCommand(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 5),
          listenOptions: stt.SpeechListenOptions(
            cancelOnError: false,
            listenMode: stt.ListenMode.confirmation,
            partialResults: false,
          ),
        );
      } else {
        _logger.warning(
          'Speech recognition not available for screen: $screenId',
        );
      }

      _logger.info('Continuous listening started for screen: $screenId');
    } catch (e) {
      _logger.warning(
        'Error starting continuous listening for screen $screenId: $e',
      );
      // Retry after error
      Future.delayed(const Duration(seconds: 2), () {
        if (isScreenAudioActive(screenId)) {
          startContinuousListening(screenId);
        }
      });
    }
  }

  // Stop listening
  Future<void> stopListening(String screenId) async {
    final speech = _screenSpeechInstances[screenId];
    if (speech != null) {
      try {
        await speech.stop();
        _transitionTimer?.cancel();
        _logger.info('Listening stopped for screen: $screenId');
      } catch (e) {
        _logger.warning('Error stopping listening for screen $screenId: $e');
      }
    }
  }

  // Enhanced available commands for seamless navigation
  List<String> getAvailableCommands(String screenId) {
    List<String> commands = [];

    switch (screenId) {
      case 'splash':
        commands = [
          'register',
          'login',
          'voice mode',
          'touch mode',
          'help',
          'start app',
        ];
        break;
      case 'voice_welcome':
        commands = [
          'register',
          'login',
          'help',
          'voice commands',
          'start voice navigation',
        ];
        break;
      case 'voice_register':
        commands = ['register', 'help', 'repeat', 'voice commands', 'go back'];
        break;
      case 'voice_login':
        commands = [
          'login',
          'pin entry',
          'help',
          'repeat',
          'voice commands',
          'go back',
        ];
        break;
      case 'member_dashboard':
      case 'blind_dashboard':
        commands = [
          'check balance',
          'my loans',
          'make deposit',
          'transactions',
          'settings',
          'apply loan',
          'help',
          'logout',
        ];
        break;
      case 'savings':
        commands = [
          'check balance',
          'make deposit',
          'view history',
          'go back',
          'help',
        ];
        break;
      case 'loans':
        commands = [
          'check loans',
          'apply loan',
          'pay loan',
          'loan status',
          'go back',
          'help',
        ];
        break;
      case 'deposits':
        commands = [
          'make deposit',
          'hundred',
          'thousand',
          'five hundred',
          'confirm',
          'cancel',
          'go back',
          'help',
        ];
        break;
      case 'transactions':
        commands = ['view transactions', 'filter', 'export', 'go back', 'help'];
        break;
      case 'settings':
        commands = [
          'voice settings',
          'change language',
          'security',
          'logout',
          'go back',
          'help',
        ];
        break;
      case 'loan_application':
        commands = [
          'apply loan',
          'amount',
          'purpose',
          'confirm',
          'cancel',
          'help',
          'go back',
        ];
        break;
      case 'payment':
        commands = [
          'pay loan',
          'amount',
          'confirm',
          'cancel',
          'go back',
          'help',
        ];
        break;
      default:
        commands = ['help', 'go back', 'voice commands'];
    }

    return commands;
  }

  // Enhanced speak available commands with better formatting
  Future<void> speakAvailableCommands(String screenId) async {
    final commands = getAvailableCommands(screenId);
    final message =
        "Available commands: ${commands.join(', ')}. Say any command to proceed.";
    await speakIfActive(screenId, message);
  }

  // Seamless navigation helper method
  Future<void> navigateToScreen(String fromScreenId, String toScreenId) async {
    _logger.info('Navigating from $fromScreenId to $toScreenId');

    // Deactivate current screen audio
    if (fromScreenId.isNotEmpty) {
      await deactivateScreenAudio(fromScreenId);
    }

    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    // Activate new screen audio
    await activateScreenAudio(toScreenId);

    _logger.info('Navigation completed: $fromScreenId -> $toScreenId');
  }

  // Enhanced voice command processing with navigation
  Future<void> processNavigationCommand(String command) async {
    final lowerCommand = command.toLowerCase().trim();

    // Map voice commands to screen navigation
    Map<String, String> navigationMap = {
      'register': 'voice_register',
      'login': 'voice_login',
      'home': 'member_dashboard',
      'dashboard': 'member_dashboard',
      'savings': 'savings',
      'loans': 'loans',
      'deposits': 'deposits',
      'transactions': 'transactions',
      'settings': 'settings',
      'back': 'previous',
    };

    for (final entry in navigationMap.entries) {
      if (lowerCommand.contains(entry.key)) {
        _navigationController.add('navigate:${entry.value}');
        return;
      }
    }
  }

  // Get current screen context for better voice guidance
  String getCurrentScreenContext() {
    return _activeScreenId ?? 'unknown';
  }

  // Enhanced error recovery for voice recognition
  Future<void> recoverFromVoiceError(String screenId, String errorType) async {
    _logger.warning(
      'Recovering from voice error: $errorType on screen: $screenId',
    );

    String recoveryMessage;
    switch (errorType) {
      case 'error_busy':
        recoveryMessage =
            "Voice recognition is busy. Please wait a moment and try again.";
        break;
      case 'error_speech_timeout':
        recoveryMessage =
            "I didn't hear anything. Please speak clearly and try again.";
        break;
      case 'error_network':
        recoveryMessage =
            "Network connection issue. Please check your internet and try again.";
        break;
      default:
        recoveryMessage =
            "There was an issue with voice recognition. Please try again.";
    }

    await speakIfActive(screenId, recoveryMessage);

    // Restart listening after recovery message
    Future.delayed(const Duration(seconds: 3), () {
      if (isScreenAudioActive(screenId)) {
        startContinuousListening(screenId);
      }
    });
  }

  // Dispose resources
  void dispose() {
    _transitionTimer?.cancel();
    _audioControlController.close();
    _screenActivationController.close();
    _audioStatusController.close();
    _voiceCommandController.close();
    _navigationController.close();
  }
}
