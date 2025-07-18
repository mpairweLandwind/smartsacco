// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/smartsacco_audio_manager.dart';

final _logger = Logger('VoiceMemberDashboard');

class VoiceMemberDashboard extends StatefulWidget {
  const VoiceMemberDashboard({super.key});

  @override
  State<VoiceMemberDashboard> createState() => _VoiceMemberDashboardState();
}

class _VoiceMemberDashboardState extends State<VoiceMemberDashboard>
    with TickerProviderStateMixin {
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  String spokenText = "";
  bool isLoading = false;

  // User data
  String memberName = "";
  String memberEmail = "";
  String memberId = "";
  String userRole = "member";

  // Dashboard data
  double savingsBalance = 0.0;
  double loanBalance = 0.0;
  List<Map<String, dynamic>> recentTransactions = [];
  List<Map<String, dynamic>> notifications = [];

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTTS();
    _startDashboardProcess();
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

  Future<void> _startDashboardProcess() async {
    // Register with audio manager
    SmartSaccoAudioManager().registerScreen(
      'blindDashboard',
      flutterTts,
      speech,
    );
    SmartSaccoAudioManager().activateScreenAudio('blindDashboard');

    _fadeController.forward();
    _pulseController.repeat(reverse: true);

    await Future.delayed(Duration(seconds: 1));
    await _loadUserData();
    await _speakWelcomeMessage();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        memberId = user.uid;

        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            memberName = userData['fullName'] ?? 'Member';
            memberEmail = userData['email'] ?? '';
            userRole = userData['role'] ?? 'member';
          });

          // Load dashboard data
          await _loadDashboardData();
        }
      }
    } catch (e) {
      _logger.warning("Error loading user data: $e");
      await SmartSaccoAudioManager().speakIfActive(
        'blindDashboard',
        "Error loading your data. Please try again.",
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load savings balance
      final savingsDoc = await FirebaseFirestore.instance
          .collection('savings')
          .doc(memberId)
          .get();

      if (savingsDoc.exists) {
        final savingsData = savingsDoc.data()!;
        setState(() {
          savingsBalance = (savingsData['balance'] ?? 0.0).toDouble();
        });
      }

      // Load loan balance
      final loanDoc = await FirebaseFirestore.instance
          .collection('loans')
          .doc(memberId)
          .get();

      if (loanDoc.exists) {
        final loanData = loanDoc.data()!;
        setState(() {
          loanBalance = (loanData['outstandingBalance'] ?? 0.0).toDouble();
        });
      }

      // Load recent transactions
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: memberId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        recentTransactions = transactionsQuery.docs
            .map((doc) => doc.data())
            .toList();
      });

      // Load notifications
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: memberId)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      setState(() {
        notifications = notificationsQuery.docs
            .map((doc) => doc.data())
            .toList();
      });
    } catch (e) {
      _logger.warning("Error loading dashboard data: $e");
    }
  }

  Future<void> _speakWelcomeMessage() async {
    String message =
        "Welcome to your SmartSacco dashboard, $memberName! Your savings balance is ${savingsBalance.toStringAsFixed(2)} shillings, and your loan balance is ${loanBalance.toStringAsFixed(2)} shillings. Say 'help' for available commands, 'balance' to hear your balances, 'transactions' for recent activity, or 'navigate' to go to other sections.";

    try {
      await SmartSaccoAudioManager().speakIfActive('blindDashboard', message);

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
              _processVoiceCommand(val.recognizedWords);
            }
          }
        },
        listenFor: Duration(seconds: 15),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
      );
    } else {
      _showError("Speech recognition not available. Please try again.");
    }
  }

  void _processVoiceCommand(String input) {
    setState(() {
      isListening = false;
    });

    String command = input.toLowerCase().trim();

    if (command.contains('help')) {
      _speakHelp();
    } else if (command.contains('balance') || command.contains('balances')) {
      _speakBalances();
    } else if (command.contains('transaction') ||
        command.contains('activity')) {
      _speakTransactions();
    } else if (command.contains('notification') ||
        command.contains('message')) {
      _speakNotifications();
    } else if (command.contains('navigate') ||
        command.contains('go to') ||
        command.contains('menu')) {
      _speakNavigationOptions();
    } else if (command.contains('deposit') || command.contains('save')) {
      _navigateToDeposit();
    } else if (command.contains('withdraw') || command.contains('take out')) {
      _navigateToWithdraw();
    } else if (command.contains('loan') || command.contains('borrow')) {
      _navigateToLoan();
    } else if (command.contains('payment') || command.contains('pay')) {
      _navigateToPayment();
    } else if (command.contains('statement') || command.contains('report')) {
      _navigateToStatement();
    } else if (command.contains('settings') || command.contains('profile')) {
      _navigateToSettings();
    } else if (command.contains('logout') || command.contains('sign out')) {
      _logout();
    } else {
      _showError(
        "I didn't understand that command. Say 'help' for available options.",
      );
    }
  }

  void _speakHelp() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Available commands: Say 'balance' to hear your account balances, 'transactions' for recent activity, 'notifications' for messages, 'navigate' for menu options, 'deposit' to add money, 'withdraw' to take out money, 'loan' for loan services, 'payment' to make payments, 'statement' for reports, 'settings' for your profile, or 'logout' to sign out.",
    );
  }

  void _speakBalances() {
    String message =
        "Your savings balance is ${savingsBalance.toStringAsFixed(2)} shillings, and your loan balance is ${loanBalance.toStringAsFixed(2)} shillings.";

    SmartSaccoAudioManager().speakIfActive('blindDashboard', message);
  }

  void _speakTransactions() {
    if (recentTransactions.isEmpty) {
      SmartSaccoAudioManager().speakIfActive(
        'blindDashboard',
        "You have no recent transactions.",
      );
      return;
    }

    String message = "Your recent transactions: ";
    for (int i = 0; i < recentTransactions.length && i < 3; i++) {
      final transaction = recentTransactions[i];
      final type = transaction['type'] ?? 'transaction';
      final amount = (transaction['amount'] ?? 0.0).toStringAsFixed(2);
      final date = transaction['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              transaction['timestamp'].millisecondsSinceEpoch,
            ).toString().substring(0, 10)
          : 'unknown date';

      message += "${i + 1}. $type of $amount shillings on $date. ";
    }

    SmartSaccoAudioManager().speakIfActive('blindDashboard', message);
  }

  void _speakNotifications() {
    if (notifications.isEmpty) {
      SmartSaccoAudioManager().speakIfActive(
        'blindDashboard',
        "You have no new notifications.",
      );
      return;
    }

    String message = "Your notifications: ";
    for (int i = 0; i < notifications.length && i < 3; i++) {
      final notification = notifications[i];
      final title = notification['title'] ?? 'Notification';
      final message_text = notification['message'] ?? '';

      message += "${i + 1}. $title: $message_text. ";
    }

    SmartSaccoAudioManager().speakIfActive('blindDashboard', message);
  }

  void _speakNavigationOptions() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigation options: Say 'deposit' to add money to your account, 'withdraw' to take out money, 'loan' for loan services, 'payment' to make payments, 'statement' for your account reports, or 'settings' for your profile settings.",
    );
  }

  void _navigateToDeposit() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to deposit page.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/payment');
      }
    });
  }

  void _navigateToWithdraw() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to withdrawal page.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/payment');
      }
    });
  }

  void _navigateToLoan() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to loan services.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/loan');
      }
    });
  }

  void _navigateToPayment() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to payment page.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/payment');
      }
    });
  }

  void _navigateToStatement() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to statement page.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/statement');
      }
    });
  }

  void _navigateToSettings() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Navigating to settings page.",
    );
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamed(context, '/settings');
      }
    });
  }

  void _logout() {
    SmartSaccoAudioManager().speakIfActive(
      'blindDashboard',
      "Logging you out. Thank you for using SmartSacco.",
    );
    Future.delayed(Duration(seconds: 3), () async {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/splash');
      }
    });
  }

  Future<void> _showError(String message) async {
    await SmartSaccoAudioManager().speakIfActive('blindDashboard', message);
    Future.delayed(Duration(seconds: message.length ~/ 10 + 2), () {
      if (mounted) {
        _startListening();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    flutterTts.stop();
    speech.stop();
    SmartSaccoAudioManager().unregisterScreen('blindDashboard');
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
                  color: isLoading
                      ? Colors.orange.shade600
                      : Colors.blue.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isLoading
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
                  isLoading ? Icons.refresh : Icons.dashboard,
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
                isLoading ? 'Loading Dashboard' : 'Voice Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            SizedBox(height: 40),

            // Dashboard info
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
                      "Welcome, $memberName!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBalanceCard(
                          "Savings",
                          savingsBalance,
                          Colors.green,
                        ),
                        _buildBalanceCard("Loan", loanBalance, Colors.red),
                      ],
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

  Widget _buildBalanceCard(String title, double amount, Color color) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
