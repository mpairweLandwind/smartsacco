// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:smartsacco/services/enhanced_voice_service.dart';
import 'package:logging/logging.dart';

class VoiceWelcomeScreen extends StatefulWidget {
  const VoiceWelcomeScreen({super.key});

  @override
  _VoiceWelcomeScreenState createState() => _VoiceWelcomeScreenState();
}

class _VoiceWelcomeScreenState extends State<VoiceWelcomeScreen>
    with TickerProviderStateMixin {
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();
  final Logger _logger = Logger('VoiceWelcomeScreen');

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
  
  // Confirmation state
  bool awaitingConfirmation = false;
  String pendingAction = "";

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeVoiceService();
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
      _handleVoiceNavigation();
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
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _scaleController.forward();

    await Future.delayed(const Duration(seconds: 1));
    await _speakWelcome();
  }

  Future<void> _speakWelcome() async {
    const String welcomeMessage =
        "Welcome Back again. To register say one and to login say three";

    await _voiceService.speak(welcomeMessage);

    // Start listening after speaking
    await Future.delayed(Duration(seconds: 1));
    await _startListening();
  }

  Future<void> _startListening() async {
    try {
      List<String> triggerWords = [
        'one',
        '1',
        'won',
        'wan',
        'wun',
        'first',
        'register',
        'three',
        '3',
        'tree',
        'free',
        'third',
        'login',
        'yes',
        'yeah',
        'yep',
        'yup',
        'sure',
        'okay',
        'ok',
        'no',
        'nope',
        'nah',
        'negative',
      ];

      await _voiceService.startListening(
        triggerWords: triggerWords,
        listenFor: Duration(seconds: 15),
        pauseFor: Duration(seconds: 5),
      );
    } catch (e) {
      _logger.severe('Failed to start listening: $e');
      _showError("Speech recognition not available. Please tap to continue.");
    }
  }

  void _handleListeningComplete() {
    _pulseController.stop();
    
    if (!awaitingConfirmation) {
      // If we're not awaiting confirmation and haven't heard a valid command
      List<String> validCommands = [
        'one',
        '1',
        'won',
        'wan',
        'wun',
        'first',
        'register',
        'three',
        '3',
        'tree',
        'free',
        'third',
        'login',
      ];

      bool hasValidCommand = validCommands.any(
        (word) => spokenText.contains(word),
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
      List<String> confirmationWords = [
        'yes',
        'yeah',
        'yep',
        'yup',
        'sure',
        'okay',
        'ok',
        'no',
        'nope',
        'nah',
        'negative',
      ];

      bool hasConfirmation = confirmationWords.any(
        (word) => spokenText.contains(word),
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

  void _handleSpeechErrorInternal(String errorMsg) {
    _pulseController.stop();
    
    print('Speech error details: $errorMsg');
    
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
    await _voiceService.speak(message);
    
    // Start listening again after speaking
    await Future.delayed(Duration(seconds: 2));
    await _startListening();
  }

  void _handleVoiceNavigation() {
    print("Handling voice navigation with text: $spokenText");
    
    if (awaitingConfirmation) {
      _handleConfirmation();
    } else {
      _handleInitialCommand();
    }
  }

  void _handleInitialCommand() {
    List<String> registerWords = [
      'one',
      '1',
      'won',
      'wan',
      'wun',
      'first',
      'register',
    ];
    List<String> loginWords = ['three', '3', 'tree', 'free', 'third', 'login'];

    if (registerWords.any((word) => spokenText.contains(word))) {
      print("Detected register command - requesting confirmation");
      _requestConfirmation("register", "one");
    } else if (loginWords.any((word) => spokenText.contains(word))) {
      print("Detected login command - requesting confirmation");
      _requestConfirmation("login", "three");
    } else {
      print("Unrecognized command: $spokenText");
      _speakAndRetry(
        "I didn't catch that. Please say 'one' to register or 'three' to login.",
      );
    }
  }

  void _requestConfirmation(String action, String number) async {
    print("Action: $action");
    print("Number: $number");

    setState(() {
      awaitingConfirmation = true;
      pendingAction = action;
      isListening = false;
      retryCount = 0;
      spokenText = ""; // Clear previous spoken text
    });

    _pulseController.stop();
    await _voiceService.stopListening();

    String confirmationMessage =
        "Did you say $number to $action? Say yes to confirm or no to cancel.";

    setState(() {
      isSpeaking = true;
    });

    await _voiceService.speak(confirmationMessage);

    // Start listening for confirmation
    await Future.delayed(Duration(seconds: 1));
    await _startListening();
  }

  void _handleConfirmation() {
    List<String> yesWords = ['yes', 'yeah', 'yep', 'yup', 'sure', 'okay', 'ok'];
    List<String> noWords = ['no', 'nope', 'nah', 'negative'];

    if (yesWords.any((word) => spokenText.contains(word))) {
      _confirmAction();
    } else if (noWords.any((word) => spokenText.contains(word))) {
      _cancelAction();
    } else {
      print("Unrecognized confirmation: $spokenText");
      _speakAndRetry("Please say 'yes' to confirm or 'no' to cancel.");
    }
  }

  void _confirmAction() async {
    setState(() {
      isListening = false;
      awaitingConfirmation = false;
    });
    
    _pulseController.stop();
    await _voiceService.stopListening();
    
    if (pendingAction == "register") {
      await _voiceService.speak("Navigating to registration.");
      await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/voiceRegister');
        }
    } else if (pendingAction == "login") {
      await _voiceService.speak("Navigating to login.");
      await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/voiceLogin');
        }
    }
  }

  void _cancelAction() async {
    setState(() {
      isListening = false;
      awaitingConfirmation = false;
    });

    _pulseController.stop();
    await _voiceService.stopListening();

    await _speakWelcomeAfterCancel();

    // Start listening again
    await Future.delayed(Duration(seconds: 2));
    await _startListening();
  }

  void _resetConfirmationState() {
    setState(() {
      awaitingConfirmation = false;
      pendingAction = "";
      retryCount = 0;
      spokenText = "";
    });
  }

  Future<void> _speakWelcomeAfterCancel() async {
    await _voiceService.speak(
      "Navigating you back to home screen. Welcome Back again. To register say one and to login say three",
    );
  }

  void _showError(String message) {
    _voiceService.speak(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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
        onTap: () {
          if (!awaitingConfirmation) {
            Navigator.pushReplacementNamed(context, '/home');
          }
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
              // Logo/Icon
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
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
                        child: Icon(
                          Icons.voice_chat,
                          size: 60,
                          color: Colors.white,
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
                  'Voice Welcome',
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
                  'Enhanced Voice Navigation',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              SizedBox(height: 50),

              // Instructions
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'Say "one" to register or "three" to login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Action buttons
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.shade400,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_add,
                        size: 40,
                        color: Colors.green.shade600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange.shade400,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.login,
                        size: 40,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
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
                      awaitingConfirmation
                          ? 'Listening for confirmation...'
                          : 'Listening... Say "one" or "three"',
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
