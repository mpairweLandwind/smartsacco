// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import '../services/smartsacco_audio_manager.dart';
import '../services/enhanced_voice_navigation.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  bool isSpeaking = false;
  String spokenText = "";
  int retryCount = 0;
  final int maxRetries = 3;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  final Logger _logger = Logger('SplashPage');

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTTS();
    _requestPermissions();
    _initializeEnhancedVoiceNavigation();
    _startWelcomeSequence();
  }

  // Initialize enhanced voice navigation
  Future<void> _initializeEnhancedVoiceNavigation() async {
    await EnhancedVoiceNavigation().initialize();
    EnhancedVoiceNavigation().setCurrentScreen('splash');

    // Listen for navigation events
    EnhancedVoiceNavigation().navigationEventStream.listen((event) {
      _handleNavigationEvent(event);
    });

    EnhancedVoiceNavigation().voiceCommandStream.listen((event) {
      _handleEnhancedVoiceCommand(event);
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
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

  Future<void> _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    // Set up TTS completion handler
    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
        // Start listening after TTS finishes
        if (!isListening) {
          _startListening();
        }
      }
    });
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showError(
        "Microphone permission is required for voice navigation. Please tap to continue.",
      );
    }
  }

  Future<void> _startWelcomeSequence() async {
    // Register with audio manager
    SmartSaccoAudioManager().registerScreen('splash', flutterTts, speech);
    SmartSaccoAudioManager().activateScreenAudio('splash');

    // Start animations
    _fadeController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _scaleController.forward();

    // Wait a bit then start TTS
    await Future.delayed(Duration(seconds: 1));
    await _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    String welcomeMessage =
        "Welcome to SmartSacco! Say 'register' to create a new account, 'login' to sign in with your PIN, 'voice mode' for voice-first experience, or tap anywhere on the screen to proceed normally. Say 'help' for available commands.";

    setState(() {
      isSpeaking = true;
    });

    await SmartSaccoAudioManager().speakIfActive('splash', welcomeMessage);

    // Start continuous listening for voice commands
    SmartSaccoAudioManager().startContinuousListening('splash');

    // Listen for voice commands
    SmartSaccoAudioManager().voiceCommandStream.listen((event) {
      _handleVoiceCommand(event);
    });
  }

  void _handleVoiceCommand(String command) {
    _logger.info('Voice command received: $command');

    if (command.startsWith('register') || command.contains('register')) {
      _navigateToVoiceRegistration();
    } else if (command.startsWith('login') || command.contains('login')) {
      _navigateToVoiceLogin();
    } else if (command.startsWith('help') || command.contains('help')) {
      _speakHelp();
    } else if (command.startsWith('voice_mode') ||
        command.contains('voice mode')) {
      _navigateToVoiceWelcome();
    } else if (command.startsWith('touch_mode') ||
        command.contains('touch mode')) {
      _navigateToMainApp(accessibilityMode: false);
    } else if (command.startsWith('start_app') || command.contains('start')) {
      _navigateToMainApp(accessibilityMode: false);
    }
  }

  // Handle enhanced voice commands
  void _handleEnhancedVoiceCommand(String event) {
    final parts = event.split(':');
    if (parts.length >= 2) {
      final commandType = parts[0];
      final fullCommand = parts.sublist(1).join(':');

      _logger.info('Enhanced voice command: $commandType - $fullCommand');

      // Process the command through enhanced navigation
      EnhancedVoiceNavigation().processVoiceCommand(fullCommand);
    }
  }

  // Handle navigation events
  void _handleNavigationEvent(String event) {
    _logger.info('Navigation event: $event');

    if (event.startsWith('navigate:')) {
      final screenId = event.split(':')[1];
      _handleScreenNavigation(screenId);
    } else if (event == 'logout') {
      _handleLogout();
    }
  }

  // Handle screen navigation
  void _handleScreenNavigation(String screenId) {
    switch (screenId) {
      case 'voice_register':
        _navigateToVoiceRegistration();
        break;
      case 'voice_login':
        _navigateToVoiceLogin();
        break;
      case 'member_dashboard':
        _navigateToMainApp(accessibilityMode: true);
        break;
      default:
        _logger.info('Unknown screen navigation: $screenId');
    }
  }

  // Handle logout
  void _handleLogout() {
    _navigateToMainApp(accessibilityMode: false);
  }

  void _navigateToVoiceRegistration() async {
    await SmartSaccoAudioManager().speakIfActive(
      'splash',
      "Navigating to voice registration. I'll guide you through creating your account step by step.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/voiceRegister');
      }
    });
  }

  void _navigateToVoiceLogin() async {
    await SmartSaccoAudioManager().speakIfActive(
      'splash',
      "Navigating to voice login. Please prepare to speak your PIN.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/voiceLogin');
      }
    });
  }

  void _navigateToVoiceWelcome() async {
    await SmartSaccoAudioManager().speakIfActive(
      'splash',
      "Navigating to voice-first experience. I'll guide you through everything.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/voiceWelcome');
      }
    });
  }

  void _speakHelp() async {
    await SmartSaccoAudioManager().speakIfActive(
      'splash',
      "Available commands: Say 'register' to create a new account, 'login' to sign in with your PIN, 'voice mode' for voice-first experience, 'touch mode' for normal navigation, or tap the screen to continue. Say 'help' anytime for this list of commands.",
    );
  }

  Future<void> _startListening() async {
    // Stop any existing listening session
    if (isListening) {
      await speech.stop();
    }

    bool available = await speech.initialize(
      onStatus: (val) {
        _logger.info('Speech status: $val'); // Debug log
        if (mounted) {
          setState(() {
            isListening = val == 'listening';
          });

          // Handle different status scenarios
          if (val == 'done' || val == 'notListening') {
            _handleListeningComplete();
          }
        }
      },
      onError: (val) {
        _logger.warning('Speech error: $val'); // Debug log
        if (mounted) {
          setState(() {
            isListening = false;
          });
          _handleSpeechError(val.errorMsg);
        }
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          isListening = true;
          spokenText = "";
        });

        // Start pulse animation for microphone
        _pulseController.repeat(reverse: true);
      }

      await speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              spokenText = val.recognizedWords.toLowerCase();
            });

            _logger.info('Recognized: $spokenText'); // Debug log

            // Check for trigger words
            if (spokenText.contains('register') ||
                spokenText.contains('sign up') ||
                spokenText.contains('create account')) {
              _navigateToVoiceRegistration();
            } else if (spokenText.contains('login') ||
                spokenText.contains('sign in') ||
                spokenText.contains('enter')) {
              _navigateToVoiceLogin();
            } else if (spokenText.contains('help') ||
                spokenText.contains('commands')) {
              _speakHelp();
            }
          }
        },
        listenFor: Duration(seconds: 15), // Increased listening time
        pauseFor: Duration(seconds: 5), // Increased pause time
        partialResults: true, // Enable partial results
        cancelOnError: false, // Don't cancel on minor errors
        listenMode:
            stt.ListenMode.confirmation, // Better for command recognition
      );
    } else {
      _showError("Speech recognition not available. Please tap to continue.");
    }
  }

  void _handleListeningComplete() {
    _pulseController.stop();
    // Auto-restart listening for continuous interaction
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && !isSpeaking) {
        _startListening();
      }
    });
  }

  void _handleSpeechError(String errorMsg) {
    _logger.warning('Speech error: $errorMsg');
    // Provide helpful error message and retry
    if (retryCount < maxRetries) {
      retryCount++;
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _startListening();
        }
      });
    } else {
      _showError(
        "Voice recognition is having trouble. Please tap to continue normally.",
      );
    }
  }

  void _handleVoiceNavigation() async {
    if (mounted) {
      setState(() {
        isListening = false;
      });
    }

    _pulseController.stop();
    speech.stop();

    setState(() {
      isSpeaking = true;
    });

    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
        _navigateToMainApp(accessibilityMode: true);
      }
    });
    await SmartSaccoAudioManager().speakIfActive(
      'splash',
      "Navigating you to the welcome screen.",
    );
  }

  void _navigateToMainApp({bool accessibilityMode = false}) {
    // Stop all audio activities
    speech.stop();
    flutterTts.stop();
    SmartSaccoAudioManager().deactivateScreenAudio('splash');

    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        if (accessibilityMode) {
          Navigator.pushReplacementNamed(context, '/voiceWelcome');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
  }

  void _showError(String message) {
    SmartSaccoAudioManager().speakIfActive('splash', message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 3)),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    flutterTts.stop();
    speech.stop();
    SmartSaccoAudioManager().unregisterScreen('splash');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: GestureDetector(
        onTap: () {
          // Allow manual navigation for users who prefer touch
          _navigateToMainApp(accessibilityMode: false);
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, Colors.blue.shade50],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon with animations
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isListening
                                ? Colors.orange.shade600
                                : Colors.blue.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isListening
                                            ? Colors.orange.shade300
                                            : Colors.blue.shade300)
                                        .withOpacity(0.5),
                                spreadRadius: 5,
                                blurRadius: 15,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening ? Icons.mic : Icons.account_balance,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "SmartSacco",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              SizedBox(height: 10),

              // Subtitle
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "Voice-First Financial Management",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              SizedBox(height: 60),

              // Status indicator
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isListening ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        isListening
                            ? "Listening for voice commands..."
                            : isSpeaking
                            ? "Speaking..."
                            : "Ready for voice commands",
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Voice command hint
              if (spokenText.isNotEmpty)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    margin: EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "Heard: \"$spokenText\"",
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              SizedBox(height: 40),

              // Manual navigation hint
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "Tap anywhere to continue without voice",
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
