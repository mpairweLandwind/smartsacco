import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import '../services/smartsacco_voice_navigation.dart';

class VoiceSplashScreen extends StatefulWidget {
  const VoiceSplashScreen({super.key});

  @override
  State<VoiceSplashScreen> createState() => _VoiceSplashScreenState();
}

class _VoiceSplashScreenState extends State<VoiceSplashScreen>
    with TickerProviderStateMixin {
  final Logger _logger = Logger('VoiceSplashScreen');
  final SmartSaccoVoiceNavigation _voiceNav = SmartSaccoVoiceNavigation();

  FlutterTts flutterTts = FlutterTts();
  SpeechToText speech = SpeechToText();

  bool isListening = false;
  bool isSpeaking = false;
  bool isInitialized = false;
  String spokenText = "";
  String currentStep = "initializing";

  // Animation controllers
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
    _initializeVoiceSystem();
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

  Future<void> _initializeVoiceSystem() async {
    try {
      setState(() {
        currentStep = "requesting_permissions";
      });

      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _showError("Microphone permission is required for voice navigation");
        return;
      }

      setState(() {
        currentStep = "initializing_voice";
      });

      // Initialize voice navigation system
      bool initialized = await _voiceNav.initialize();
      if (!initialized) {
        _showError("Failed to initialize voice navigation system");
        return;
      }

      setState(() {
        currentStep = "ready";
        isInitialized = true;
      });

      // Start animations
      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      _scaleController.forward();

      // Set current screen for voice navigation
      _voiceNav.setCurrentScreen('splash');

      // Listen for voice commands
      _voiceNav.voiceCommandStream.listen(_handleVoiceCommand);
      _voiceNav.navigationStream.listen(_handleNavigation);

      // Start welcome sequence
      await Future.delayed(const Duration(seconds: 1));
      await _speakWelcome();
    } catch (e) {
      _logger.severe('Error initializing voice system: $e');
      _showError("Error initializing voice system. Please try again.");
    }
  }

  Future<void> _speakWelcome() async {
    const String welcomeMessage = """
    Welcome to SmartSacco Voice Navigation!
    
    I'm your voice assistant. I'll help you navigate the app using voice commands.
    
    To get started, say one of these options:
    - "Register" or "one" to create a new account
    - "Login" or "three" to sign in to your existing account
    - "Help" to hear all available commands
    - "Settings" to customize voice preferences
    
    I'm listening for your command now.
    """;

    setState(() {
      isSpeaking = true;
    });

    await flutterTts.speak(welcomeMessage);

    // Start listening after speaking
    if (mounted) {
      setState(() {
        isSpeaking = false;
      });
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!isInitialized) return;

    try {
      setState(() {
        isListening = true;
        spokenText = "";
      });

      _pulseController.repeat(reverse: true);

      await _voiceNav.startListening();
    } catch (e) {
      _logger.warning('Error starting listening: $e');
      setState(() {
        isListening = false;
      });
    }
  }

  void _handleVoiceCommand(String command) {
    if (mounted) {
      setState(() {
        spokenText = command;
      });
    }

    _logger.info('Voice command received: $command');

    // Process the command
    _processCommand(command);
  }

  void _handleNavigation(String navigation) {
    _logger.info('Navigation command: $navigation');

    if (navigation.startsWith('navigate:')) {
      String route = navigation.substring(9); // Remove 'navigate:' prefix
      _navigateToRoute(route);
    }
  }

  void _processCommand(String command) {
    String lowerCommand = command.toLowerCase();

    if (lowerCommand.contains('register') ||
        lowerCommand.contains('sign up') ||
        lowerCommand.contains('create account') ||
        lowerCommand.contains('new user') ||
        lowerCommand.contains('one') ||
        lowerCommand.contains('1')) {
      _confirmAction('register', 'register');
    } else if (lowerCommand.contains('login') ||
        lowerCommand.contains('sign in') ||
        lowerCommand.contains('existing user') ||
        lowerCommand.contains('three') ||
        lowerCommand.contains('3')) {
      _confirmAction('login', 'login');
    } else if (lowerCommand.contains('help') ||
        lowerCommand.contains('what can i do') ||
        lowerCommand.contains('options') ||
        lowerCommand.contains('commands')) {
      _speakHelp();
    } else if (lowerCommand.contains('settings') ||
        lowerCommand.contains('preferences') ||
        lowerCommand.contains('customize')) {
      _navigateToRoute('/settings');
    } else {
      _speakUnrecognizedCommand();
    }
  }

  Future<void> _confirmAction(String action, String displayName) async {
    String confirmationMessage =
        "Did you say $displayName? Say 'yes' to confirm or 'no' to cancel.";

    setState(() {
      isSpeaking = true;
    });

    await flutterTts.speak(confirmationMessage);

    setState(() {
      isSpeaking = false;
    });

    // Listen for confirmation
    _startListening();
  }

  Future<void> _speakHelp() async {
    const String helpMessage = """
    Here are all the available voice commands:
    
    Navigation:
    - "Register" or "one" - Create a new account
    - "Login" or "three" - Sign in to existing account
    - "Settings" - Customize voice preferences
    
    General:
    - "Help" - Hear this help message again
    - "Stop listening" - Pause voice recognition
    - "Start listening" - Resume voice recognition
    
    I'm ready for your next command.
    """;

    setState(() {
      isSpeaking = true;
    });

    await flutterTts.speak(helpMessage);

    setState(() {
      isSpeaking = false;
    });

    _startListening();
  }

  Future<void> _speakUnrecognizedCommand() async {
    const String message =
        "I didn't understand that command. Say 'help' to hear all available options, or try saying 'register' or 'login'.";

    setState(() {
      isSpeaking = true;
    });

    await flutterTts.speak(message);

    setState(() {
      isSpeaking = false;
    });

    _startListening();
  }

  void _navigateToRoute(String route) {
    _logger.info('Navigating to: $route');

    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  void _showError(String message) {
    _logger.severe(message);
    flutterTts.speak(message);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _voiceNav.stopListening();
    _voiceNav.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: GestureDetector(
        onTap: () {
          // Allow manual navigation for users who prefer touch
          Navigator.pushReplacementNamed(context, '/home');
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

              // App title with fade animation
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Column(
                      children: [
                        Text(
                          'SmartSacco',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Voice Navigation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Status indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isListening
                            ? Colors.green
                            : isSpeaking
                            ? Colors.orange
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        isListening
                            ? Icons.mic
                            : isSpeaking
                            ? Icons.volume_up
                            : Icons.mic_off,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Status text
              Text(
                isListening
                    ? 'Listening for voice commands...'
                    : isSpeaking
                    ? 'Speaking...'
                    : currentStep == "initializing"
                    ? 'Initializing voice system...'
                    : currentStep == "requesting_permissions"
                    ? 'Requesting permissions...'
                    : currentStep == "initializing_voice"
                    ? 'Setting up voice recognition...'
                    : 'Ready for voice commands',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              if (spokenText.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
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
                    textAlign: TextAlign.center,
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
                      'Say "register" or "one" to create account\nSay "login" or "three" to sign in\nSay "help" for all commands',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Tap screen for manual navigation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
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
