// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import '../services/smartsacco_audio_manager.dart';
import '../services/enhanced_voice_navigation.dart';

final _logger = Logger('VoiceRegisterPage');

class VoiceRegisterPage extends StatefulWidget {
  const VoiceRegisterPage({super.key});

  @override
  State<VoiceRegisterPage> createState() => _VoiceRegisterPageState();
}

class _VoiceRegisterPageState extends State<VoiceRegisterPage>
    with TickerProviderStateMixin {
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  String spokenText = "";
  bool isCreatingAccount = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registration data
  String fullName = "";
  String email = "";
  String phoneNumber = "";
  String pin = "";
  String role = "member";

  // Registration step tracking
  int currentStep = 0;
  final List<String> steps = ['fullName', 'email', 'phoneNumber', 'pin'];

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTTS();
    _initializeEnhancedVoiceNavigation();
    _startRegistrationProcess();
  }

  // Initialize enhanced voice navigation
  Future<void> _initializeEnhancedVoiceNavigation() async {
    EnhancedVoiceNavigation().setCurrentScreen('voice_register');

    // Listen for navigation events
    EnhancedVoiceNavigation().navigationEventStream.listen((event) {
      _handleNavigationEvent(event);
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _startRegistrationProcess() async {
    // Register with audio manager
    SmartSaccoAudioManager().registerScreen(
      'voiceRegister',
      flutterTts,
      speech,
    );
    SmartSaccoAudioManager().activateScreenAudio('voiceRegister');

    _fadeController.forward();
    _pulseController.repeat(reverse: true);

    await Future.delayed(Duration(seconds: 1));
    await _speakWelcomeMessage();
  }

  Future<void> _speakWelcomeMessage() async {
    String message =
        "Welcome to SmartSacco voice registration. I'll guide you through creating your account step by step. Let's start with your full name. Please say your complete name clearly.";

    try {
      await SmartSaccoAudioManager().speakIfActive('voiceRegister', message);

      Future.delayed(Duration(seconds: message.length ~/ 10 + 2), () {
        if (mounted) {
          _startListening();
        }
      });
    } catch (e) {
      _logger.warning("TTS Error: $e");
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _startListening();
        }
      });
    }
  }

  Future<void> _startListening() async {
    try {
      await speech.stop();
    } catch (e) {
      _logger.warning("Error stopping speech: $e");
    }

    bool available = await speech.initialize(
      onStatus: (val) {
        _logger.info("Speech status: $val");
        if (mounted) {
          setState(() {
            isListening = val == 'listening';
          });

          if (val == 'notListening' && spokenText.isEmpty) {
            Future.delayed(Duration(seconds: 1), () {
              if (mounted && !isListening) {
                _startListening();
              }
            });
          }
        }
      },
      onError: (val) {
        _logger.warning("Speech error: $val");
        if (mounted) {
          setState(() {
            isListening = false;
          });
          _showError("Sorry, I didn't catch that. Let me try again.");
        }
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          isListening = true;
          spokenText = "";
        });
      }

      speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              spokenText = val.recognizedWords;
            });

            if (val.finalResult) {
              speech.stop();
              _processSpokenInput(val.recognizedWords);
            }
          }
        },
        listenFor: Duration(seconds: 20),
        pauseFor: Duration(seconds: 8),
        partialResults: true,
      );
    } else {
      _showError("Speech recognition not available. Please try again.");
    }
  }

  void _processSpokenInput(String input) {
    setState(() {
      isListening = false;
    });

    if (input.toLowerCase().contains('repeat')) {
      _repeatCurrentStep();
      return;
    }

    if (input.toLowerCase().contains('help')) {
      _speakHelp();
      return;
    }
  }

  // Handle navigation events
  void _handleNavigationEvent(String event) {
    _logger.info('Navigation event: $event');

    if (event.startsWith('navigate:')) {
      final screenId = event.split(':')[1];
      _handleScreenNavigation(screenId);
    } else if (event == 'go_back') {
      Navigator.pop(context);
    }
  }

  // Handle screen navigation
  void _handleScreenNavigation(String screenId) {
    switch (screenId) {
      case 'voice_login':
        Navigator.pushReplacementNamed(context, '/voiceLogin');
        break;
      case 'member_dashboard':
        Navigator.pushReplacementNamed(context, '/member-dashboard');
        break;
      default:
        _logger.info('Unknown screen navigation: $screenId');
    }
  }

  String _extractEmail(String input) {
    // Convert spoken email to proper format
    String email = input
        .toLowerCase()
        .replaceAll(' at ', '@')
        .replaceAll(' dot ', '.')
        .replaceAll(' ', '');

    // Basic email validation
    if (email.contains('@') && email.contains('.')) {
      return email;
    }
    return '';
  }

  String _extractPhoneNumber(String input) {
    // Extract digits from spoken phone number
    String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits;
    }
    return '';
  }

  String _extractPin(String input) {
    // Convert spoken numbers to digits
    Map<String, String> numberWords = {
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'oh': '0',
      'o': '0',
    };

    String processed = input.toLowerCase();
    numberWords.forEach((word, digit) {
      processed = processed.replaceAll(RegExp(r'\b' + word + r'\b'), digit);
    });

    return processed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.') && email.length > 5;
  }

  void _nextStep() {
    if (currentStep < steps.length - 1) {
      currentStep++;
      _askForNextInput();
    } else {
      _confirmRegistration();
    }
  }

  void _goBackStep() {
    if (currentStep > 0) {
      currentStep--;
      _askForNextInput();
    } else {
      _speakWelcomeMessage();
    }
  }

  void _askForNextInput() {
    String message;
    switch (steps[currentStep]) {
      case 'email':
        message =
            "Great! Now please say your email address. For example, say 'john dot doe at gmail dot com'.";
        break;
      case 'phoneNumber':
        message = "Perfect! Now please say your phone number.";
        break;
      case 'pin':
        message =
            "Excellent! Finally, please say a 4-digit PIN for your account. For example, say 'one two three four'.";
        break;
      default:
        message = "Please continue with the registration.";
    }
    _askForInputAgain(message);
  }

  void _askForInputAgain(String message) {
    SmartSaccoAudioManager().speakIfActive('voiceRegister', message);
    Future.delayed(Duration(seconds: message.length ~/ 10 + 2), () {
      if (mounted) {
        _startListening();
      }
    });
  }

  void _confirmRegistration() async {
    String confirmationMessage =
        "Please confirm your details. Your name is $fullName, email is $email, phone is $phoneNumber, and PIN is $pin. Say 'confirm' to create your account, or 'repeat' to start over.";

    await SmartSaccoAudioManager().speakIfActive(
      'voiceRegister',
      confirmationMessage,
    );

    // Listen for confirmation
    SmartSaccoAudioManager().startContinuousListening('voiceRegister');
    SmartSaccoAudioManager().voiceCommandStream.listen((event) {
      if (event.startsWith('confirm')) {
        _completeRegistration();
      } else if (event.startsWith('repeat')) {
        _resetRegistration();
      }
    });
  }

  void _resetRegistration() {
    setState(() {
      currentStep = 0;
      fullName = "";
      email = "";
      phoneNumber = "";
      pin = "";
    });
    _speakWelcomeMessage();
  }

  void _repeatCurrentStep() {
    _askForNextInput();
  }

  void _speakHelp() {
    SmartSaccoAudioManager().speakIfActive(
      'voiceRegister',
      "Voice registration help. Say your information clearly when prompted. Say 'repeat' to hear the current step again, 'back' to go to the previous step, or 'help' for this message. You can also say 'confirm' when reviewing your details.",
    );
  }

  // Firebase Registration Method
  Future<void> _completeRegistration() async {
    setState(() {
      isCreatingAccount = true;
    });

    try {
      // Announce that account creation is starting
      await SmartSaccoAudioManager().speakIfActive(
        'voiceRegister',
        "Creating your account, please wait...",
      );

      // Create a temporary password using email and PIN
      String temporaryPassword = "$pin${email.substring(0, 2)}Temp123!";

      // Create Firebase Auth user
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email,
            password: temporaryPassword,
          );

      // Update the user's display name
      await userCredential.user?.updateDisplayName(fullName);

      // Store additional user data in Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': role,
        'pin': pin,
        'createdAt': FieldValue.serverTimestamp(),
        'registrationMethod': 'voice',
        'uid': userCredential.user?.uid,
      });

      // Success message
      await SmartSaccoAudioManager().speakIfActive(
        'voiceRegister',
        "Registration successful! Your account has been created. Welcome to SmartSacco, $fullName! You can now login using your PIN. Navigating to login screen.",
      );

      // Navigate to dashboard page
      Future.delayed(Duration(seconds: 4), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/voiceLogin');
        }
      });
    } catch (e) {
      setState(() {
        isCreatingAccount = false;
      });

      String errorMessage = "Sorry, there was an error creating your account. ";
      if (e.toString().contains('email-already-in-use')) {
        errorMessage +=
            "This email is already registered. Please try a different email or login instead.";
      } else if (e.toString().contains('weak-password')) {
        errorMessage += "Please try again with a stronger PIN.";
      } else {
        errorMessage += "Please check your internet connection and try again.";
      }

      await SmartSaccoAudioManager().speakIfActive(
        'voiceRegister',
        errorMessage,
      );

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          _startListening();
        }
      });
    }
  }

  Future<void> _showError(String message) async {
    await SmartSaccoAudioManager().speakIfActive('voiceRegister', message);
    Future.delayed(Duration(seconds: message.length ~/ 10 + 2), () {
      if (mounted) {
        _startListening();
      }
    });
  }

  String _getCurrentStatusText() {
    if (isCreatingAccount) {
      return "Creating Account...";
    } else if (isListening) {
      return "Listening...";
    } else {
      return "Voice Registration";
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    flutterTts.stop();
    speech.stop();
    SmartSaccoAudioManager().unregisterScreen('voiceRegister');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Container(
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
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isCreatingAccount
                      ? Colors.orange.shade600
                      : Colors.blue.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isCreatingAccount
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
                  isCreatingAccount ? Icons.person_add : Icons.mic,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: 30),

            // Title
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                isCreatingAccount ? 'Creating Account' : 'Voice Registration',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            SizedBox(height: 40),

            // Current step instruction
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _getCurrentStatusText(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 15),
                    if (currentStep < steps.length)
                      Text(
                        "Step ${currentStep + 1} of ${steps.length}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    if (spokenText.isNotEmpty) ...[
                      SizedBox(height: 15),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Heard: \"$spokenText\"",
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.blue.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // Progress indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(steps.length, (index) {
                  return Container(
                    width: 12,
                    height: 12,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index <= currentStep
                          ? Colors.blue.shade600
                          : Colors.blue.shade200,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),

            SizedBox(height: 40),

            // Help button
            FadeTransition(
              opacity: _fadeAnimation,
              child: TextButton.icon(
                onPressed: _speakHelp,
                icon: Icon(Icons.help, color: Colors.blue.shade600),
                label: Text(
                  "Voice Help",
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
