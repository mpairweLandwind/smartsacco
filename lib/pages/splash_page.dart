// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:smartsacco/services/enhanced_voice_service.dart';
import 'package:logging/logging.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();
  final Logger _logger = Logger('SplashPage');

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Voice state
  bool isListening = false;
  bool isSpeaking = false;
  String spokenText = "";
  int retryCount = 0;
  final int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeVoiceService();
    _startWelcomeSequence();
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

  Future<void> _initializeVoiceService() async {
    try {
      await _voiceService.initialize(
        onSpeechResult: _handleSpeechResult,
        onSpeechError: _handleSpeechError,
        onListeningStateChanged: _handleListeningStateChanged,
        onSpeakingStateChanged: _handleSpeakingStateChanged,
      );
      _logger.info('Enhanced voice service initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize voice service: $e');
      _showError(
        "Voice service initialization failed. Please tap to continue.",
      );
    }
  }

  void _handleSpeechResult(String text) {
    if (mounted) {
      setState(() {
        spokenText = text.toLowerCase();
      });

      _logger.info('Recognized: $spokenText');

      // Enhanced trigger word detection with accent variations
      List<String> triggerWords = [
        'one',
        '1',
        'won',
        'wan',
        'wun',
        'first',
        'start',
      ];
      bool hasTriggerWord = triggerWords.any(
        (word) => spokenText.contains(word),
      );

      if (hasTriggerWord) {
        _handleVoiceNavigation();
      }
    }
  }

  void _handleSpeechError(String error) {
    _logger.warning('Speech error: $error');
    _handleSpeechErrorInternal(error);
  }

  void _handleListeningStateChanged(bool listening) {
    if (mounted) {
      setState(() {
        isListening = listening;
      });

      if (listening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  void _handleSpeakingStateChanged(bool speaking) {
    if (mounted) {
      setState(() {
        isSpeaking = speaking;
      });
    }
  }

  Future<void> _startWelcomeSequence() async {
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
        "Welcome to SmartSacco application. If you are visually impaired, say 'one' to continue with voice navigation, or tap anywhere on the screen to proceed normally.";

    await _voiceService.speak(welcomeMessage);

    // Start listening after speaking
    await Future.delayed(Duration(seconds: 1));
    await _startListening();
  }

  Future<void> _startListening() async {
    try {
      await _voiceService.startListening(
        triggerWords: ['one', '1', 'won', 'wan', 'wun', 'first', 'start'],
        listenFor: Duration(seconds: 10), // Reduced from 15 to 10
        pauseFor: Duration(seconds: 3), // Reduced from 5 to 3
      );
    } catch (e) {
      _logger.severe('Failed to start listening: $e');
      _showError("Speech recognition not available. Please tap to continue.");
    }
  }

  void _handleListeningComplete() {
    _pulseController.stop();

    // If we haven't detected the trigger word and haven't exceeded retries
    List<String> triggerWords = [
      'one',
      '1',
      'won',
      'wan',
      'wun',
      'first',
      'start',
    ];
    bool hasTriggerWord = triggerWords.any((word) => spokenText.contains(word));

    if (!hasTriggerWord && retryCount < maxRetries) {
      retryCount++;

      String retryMessage = retryCount == 1
          ? "I didn't catch that. Please say 'one' clearly to continue with voice navigation."
          : retryCount == 2
          ? "Let's try again. Say 'one' to continue with voice navigation."
          : "One more time. Say 'one' for voice navigation, or tap the screen to continue normally.";

      _speakAndRetry(retryMessage);
    } else if (retryCount >= maxRetries) {
      _speakAndRetry(
        "No problem. You can tap anywhere on the screen to continue.",
      );
    }
  }

  void _handleSpeechErrorInternal(String errorMsg) {
    _pulseController.stop();

    _logger.warning('Speech error details: $errorMsg');

    // Handle specific error types
    if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      _speakAndRetry(
        "Network issue detected. Please check your connection and try saying 'one' again.",
      );
    } else if (errorMsg.contains('no-speech') ||
        errorMsg.contains('speech-timeout') ||
        errorMsg.contains('error_speech_timeout')) {
      // Handle speech timeout more gracefully
      if (retryCount < maxRetries) {
        retryCount++;
        _speakAndRetry(
          "I didn't hear anything. Please say 'one' clearly to continue with voice navigation.",
        );
      } else {
        _speakAndRetry(
          "Voice recognition is having trouble. You can tap the screen to continue normally.",
        );
      }
    } else if (retryCount < maxRetries) {
      retryCount++;
      _speakAndRetry(
        "Let's try again. Say 'one' to continue with voice navigation.",
      );
    } else {
      _speakAndRetry(
        "Voice recognition is having trouble. Please tap the screen to continue.",
      );
    }
  }

  Future<void> _speakAndRetry(String message) async {
    await _voiceService.speak(message);

    // Start listening again after speaking with a longer delay for better stability
    await Future.delayed(Duration(seconds: 3));
    await _startListening();
  }

  void _handleVoiceNavigation() async {
    await _voiceService.stopListening();
    await _voiceService.speak("Navigating you to the welcome screen.");

    // Navigate after speaking
    await Future.delayed(Duration(seconds: 2));
    _navigateToMainApp(accessibilityMode: true);
  }

  void _navigateToMainApp({bool accessibilityMode = false}) {
    // Stop all audio activities
    _voiceService.stopListening();
    _voiceService.stopSpeaking();

    // Show a brief message before navigating
    if (accessibilityMode) {
      _voiceService.speak("Taking you to voice navigation.");
    } else {
      _voiceService.speak("Taking you to the main app.");
    }

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
    _voiceService.speak(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Skip Voice',
            onPressed: () => _navigateToMainApp(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: GestureDetector(
        onTap: () => _navigateToMainApp(),
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
              // Logo/Icon
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade300.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 15,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/smartsacco.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to icon if image fails to load
                              return Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.account_balance,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 30),

              // App Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'SmartSacco',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              SizedBox(height: 10),

              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Your Smart Financial Partner',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              SizedBox(height: 50),

              // Listening indicator
              if (isListening)
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red.shade400,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.mic,
                              size: 40,
                              color: Colors.red.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Listening... Say "one" to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (retryCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Attempt ${retryCount + 1} of ${maxRetries + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade500,
                          ),
                        ),
                      ),
                  ],
                ),

              // Voice configuration indicator
              if (!isListening && !isSpeaking)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    'Enhanced voice recognition active',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade400,
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
