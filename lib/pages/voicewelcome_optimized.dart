// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:smartsacco/services/enhanced_voice_service.dart';
import 'package:smartsacco/services/voice_navigation_service.dart';
import 'package:smartsacco/services/voice_input_matching_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';

class VoiceWelcomeScreen extends StatefulWidget {
  const VoiceWelcomeScreen({super.key});

  @override
  _VoiceWelcomeScreenState createState() => _VoiceWelcomeScreenState();
}

class _VoiceWelcomeScreenState extends State<VoiceWelcomeScreen>
    with TickerProviderStateMixin {
  final Logger _logger = Logger('VoiceWelcomeScreen');
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();
  final VoiceNavigationService _navigationService = VoiceNavigationService();
  final VoiceInputMatchingService _matchingService =
      VoiceInputMatchingService();

  bool isListening = false;
  bool isSpeaking = false;
  String spokenText = "";
  int retryCount = 0;
  final int maxRetries = 3;

  // Confirmation state
  bool awaitingConfirmation = false;
  String pendingAction = "";

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeServices();
    _startWelcomeSequence();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    try {
      await _voiceService.initialize();
      await _navigationService.initialize();
      await _requestPermissions();

      // Set up voice service callbacks
    } catch (e) {
      _logger.warning('Error initializing services: $e');
    }
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showError("Microphone permission is required for voice commands");
    }
  }

  Future<void> _startWelcomeSequence() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _scaleController.forward();

    await Future.delayed(const Duration(seconds: 1));
    await _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    const String welcomeMessage =
        "Welcome Back again. To register say one and to login say three";

    setState(() {
      isSpeaking = true;
    });

    await _voiceService.speak(welcomeMessage, context: 'welcome');
  }

  void _handleListeningComplete() {
    _pulseController.stop();

    if (!awaitingConfirmation) {
      // If we're not awaiting confirmation and haven't heard a valid command
      final validCommands = ['one', '1', 'three', '3', 'yes', 'no'];
      final hasValidCommand = validCommands.any(
        (cmd) => spokenText.contains(cmd),
      );

      if (!hasValidCommand && retryCount < maxRetries) {
        retryCount++;
        String retryMessage = retryCount == 1
            ? "I didn't catch that. Please say 'one' to register or 'three' to login."
            : retryCount == 3
            ? "Let's try again. Say 'one' for register or 'three' for login."
            : "One more time. Say 'one' to register or 'three' to login.";

        _speakAndRetry(retryMessage);
      } else if (retryCount >= maxRetries) {
        _speakAndRetry(
          "Having trouble with voice recognition. You can tap the screen to continue.",
        );
      }
    } else {
      // If we're awaiting confirmation but didn't hear yes/no
      final confirmationCommands = ['yes', 'no'];
      final hasConfirmation = confirmationCommands.any(
        (cmd) => spokenText.contains(cmd),
      );

      if (!hasConfirmation && retryCount < maxRetries) {
        retryCount++;
        _speakAndRetry("Please say 'yes' to confirm or 'no' to cancel.");
      } else if (retryCount >= maxRetries) {
        _resetConfirmationState();
        _speakAndRetry(
          "Let's start over. Say 'one' to register or 'three' to login.",
        );
      }
    }
  }

  void _handleSpeechError(String errorMsg) {
    _pulseController.stop();

    _logger.warning('Speech error details: $errorMsg');

    if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      _speakAndRetry(
        "Network issue detected. Please check your connection and try again.",
      );
    } else if (errorMsg.contains('no-speech') ||
        errorMsg.contains('speech-timeout')) {
      if (awaitingConfirmation) {
        _speakAndRetry(
          "I didn't hear anything. Please say 'yes' to confirm or 'no' to cancel.",
        );
      } else {
        _speakAndRetry(
          "I didn't hear anything. Please say 'one' to register or 'three' to login.",
        );
      }
    } else if (retryCount < maxRetries) {
      retryCount++;
      if (awaitingConfirmation) {
        _speakAndRetry(
          "Let's try again. Please say 'yes' to confirm or 'no' to cancel.",
        );
      } else {
        _speakAndRetry(
          "Let's try again. Say 'one' to register or 'three' to login.",
        );
      }
    } else {
      if (awaitingConfirmation) {
        _resetConfirmationState();
      }
      _speakAndRetry(
        "Voice recognition is having trouble. Please tap the screen to continue.",
      );
    }
  }

  Future<void> _speakAndRetry(String message) async {
    setState(() {
      isSpeaking = true;
    });

    await _voiceService.speak(message, context: 'retry');
  }

  void _handleVoiceNavigation() {
    _logger.info("Handling voice navigation with text: $spokenText");

    if (awaitingConfirmation) {
      _handleConfirmation();
    } else {
      _handleInitialCommand();
    }
  }

  void _handleInitialCommand() {
    // Use enhanced matching service
    final commands = ['one', 'three'];
    final matchedCommand = _matchingService.matchVoiceInput(
      spokenText,
      commands,
    );

    if (matchedCommand == 'one') {
      _logger.info("Detected 'one' - requesting confirmation for register");
      _requestConfirmation("register", "one");
    } else if (matchedCommand == 'three') {
      _logger.info("Detected 'three' - requesting confirmation for login");
      _requestConfirmation("login", "three");
    } else {
      _logger.info("Unrecognized command: $spokenText");
      _speakAndRetry(
        "I didn't catch that. Please say 'one' to register or 'three' to login.",
      );
    }
  }

  void _requestConfirmation(String action, String number) async {
    _logger.info("Action: $action, Number: $number");

    setState(() {
      awaitingConfirmation = true;
      pendingAction = action;
      isListening = false;
      retryCount = 0;
      spokenText = "";
    });

    _pulseController.stop();
    await _voiceService.stopListening();

    String confirmationMessage =
        "Did you say $number to $action? Say yes to confirm or no to cancel.";

    setState(() {
      isSpeaking = true;
    });

    await _voiceService.speak(confirmationMessage, context: 'confirmation');
  }

  void _handleConfirmation() {
    final matchedCommand = _matchingService.matchConfirmation(spokenText);

    if (matchedCommand == 'yes') {
      _executeAction(pendingAction);
    } else if (matchedCommand == 'no') {
      _resetConfirmationState();
      _speakAndRetry(
        "Okay, let's start over. Say 'one' to register or 'three' to login.",
      );
    } else {
      _speakAndRetry("Please say 'yes' to confirm or 'no' to cancel.");
    }
  }

  void _executeAction(String action) {
    _resetConfirmationState();

    if (action == "register") {
      Navigator.pushNamed(context, '/voiceRegister');
    } else if (action == "login") {
      Navigator.pushNamed(context, '/voiceLogin');
    }
  }

  void _resetConfirmationState() {
    setState(() {
      awaitingConfirmation = false;
      pendingAction = "";
      retryCount = 0;
      spokenText = "";
    });
  }

  void _showError(String message) {
    _voiceService.speak(message, context: 'error');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: GestureDetector(
        onTap: () {
          // Allow manual navigation for users who prefer touch
          Navigator.pushNamed(context, '/home');
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Welcome text with fade animation
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      'SmartSacco',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Voice status indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isListening ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_off,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Status text
              Text(
                isListening
                    ? 'Listening...'
                    : isSpeaking
                    ? 'Speaking...'
                    : 'Tap to continue or use voice commands',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              if (spokenText.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    'Heard: "$spokenText"',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Text(
                      'Voice Commands:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Say "one" to register\nSay "three" to login',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
