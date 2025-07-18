import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartsacco/services/notification_service.dart';
import 'package:smartsacco/models/notification.dart';
import 'package:smartsacco/pages/admin/overview.dart';
import 'package:smartsacco/pages/admin/loans_page.dart';
import 'package:smartsacco/pages/admin/member_page.dart';
import 'package:smartsacco/pages/admin/pending_loan_page.dart';
import 'package:smartsacco/pages/admin/active_loan_page.dart';
import 'package:smartsacco/pages/login.dart';
import 'package:intl/intl.dart';

class VoiceAdminDashboard extends StatefulWidget {
  const VoiceAdminDashboard({super.key});

  @override
  State<VoiceAdminDashboard> createState() => _VoiceAdminDashboardState();
}

class _VoiceAdminDashboardState extends State<VoiceAdminDashboard> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;

  String _currentCommand = '';
  String _lastSpokenText = '';
  String _adminName = 'Admin';

  // Dashboard data
  int _totalMembers = 0;
  int _activeLoans = 0;
  int _pendingLoans = 0;
  double _totalSavings = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _loadDashboardData();
    _speakWelcome();
  }

  Future<void> _initializeVoice() async {
    try {
      // Initialize TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Initialize STT
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );

      if (_speechEnabled) {
        _startAutoListening();
      }
    } catch (e) {
      debugPrint('Error initializing voice: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // Get admin name
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        setState(() {
          _adminName = userDoc.data()?['fullName'] ?? 'Admin';
        });
      }

      // Load dashboard statistics
      await _loadStatistics();
      await _loadRecentTransactions();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Total members
      final membersSnapshot = await _firestore.collection('users').get();

      // Active loans
      final activeLoansSnapshot = await _firestore
          .collectionGroup('loans')
          .where('status', isEqualTo: 'Approved')
          .get();

      // Pending loans
      final pendingLoansSnapshot = await _firestore
          .collectionGroup('loans')
          .where('status', isEqualTo: 'Pending Approval')
          .get();

      // Total savings
      final transactionsSnapshot = await _firestore
          .collectionGroup('transactions')
          .where('status', isEqualTo: 'Completed')
          .get();

      double totalDeposits = 0;
      double totalWithdrawals = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final type = (data['type'] ?? '').toString().toLowerCase();

        if (type == 'deposit') {
          totalDeposits += amount;
        } else if (type == 'withdraw') {
          totalWithdrawals += amount;
        }
      }

      setState(() {
        _totalMembers = membersSnapshot.size;
        _activeLoans = activeLoansSnapshot.size;
        _pendingLoans = pendingLoansSnapshot.size;
        _totalSavings = totalDeposits - totalWithdrawals;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('transactions')
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> transactions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = doc.reference.parent.parent?.id;

        String memberName = 'Unknown Member';
        if (userId != null) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              memberName = userDoc.data()?['fullName'] ?? 'Unknown Member';
            }
          } catch (e) {
            debugPrint('Error fetching user details: $e');
          }
        }

        transactions.add({
          'memberName': memberName,
          'amount': (data['amount'] ?? 0).toDouble(),
          'type': data['type'] ?? '',
          'date': data['date'],
        });
      }

      setState(() {
        _recentTransactions = transactions;
      });
    } catch (e) {
      debugPrint('Error loading recent transactions: $e');
    }
  }

  Future<void> _speakWelcome() async {
    await _speak(
      "Welcome to the Smart SACCO Admin Voice Dashboard. "
      "I'm your voice assistant. You can say commands like: "
      "Navigate to overview, View members, Check loans, "
      "Send notification, or Logout. What would you like to do?",
    );
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) return;

    setState(() {
      _isSpeaking = true;
      _lastSpokenText = text;
    });

    try {
      await _flutterTts.speak(text);
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('TTS error: $e');
    } finally {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _startAutoListening() async {
    if (!_speechEnabled || _isListening || _isSpeaking) return;

    setState(() {
      _isListening = true;
      _currentCommand = '';
    });

    try {
      final listenOptions = stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: listenOptions,
        localeId: 'en_US',
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    setState(() {
      _currentCommand = result.recognizedWords.toLowerCase();
    });

    if (result.finalResult) {
      _processVoiceCommand(_currentCommand);
    }
  }

  void _processVoiceCommand(String command) {
    setState(() {
      _isProcessing = true;
    });

    // Navigation commands
    if (command.contains('overview') || command.contains('dashboard')) {
      _navigateToOverview();
    } else if (command.contains('members') ||
        command.contains('view members')) {
      _navigateToMembers();
    } else if (command.contains('loans') || command.contains('check loans')) {
      _navigateToLoans();
    } else if (command.contains('pending') ||
        command.contains('pending loans')) {
      _navigateToPendingLoans();
    } else if (command.contains('active') || command.contains('active loans')) {
      _navigateToActiveLoans();
    }
    // Action commands
    else if (command.contains('send notification') ||
        command.contains('notify')) {
      _showNotificationDialog();
    } else if (command.contains('refresh') || command.contains('update')) {
      _refreshData();
    } else if (command.contains('logout') || command.contains('sign out')) {
      _logout();
    } else if (command.contains('help') || command.contains('commands')) {
      _showHelp();
    } else {
      _speak(
        "I didn't understand that command. Please try again or say help for available commands.",
      );
    }

    setState(() {
      _isProcessing = false;
    });
  }

  void _navigateToOverview() {
    _speak("Navigating to overview dashboard");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OverviewPage()),
    );
  }

  void _navigateToMembers() {
    _speak("Navigating to members page");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MembersPage()),
    );
  }

  void _navigateToLoans() {
    _speak("Navigating to loans page");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoanPage()),
    );
  }

  void _navigateToPendingLoans() {
    _speak("Navigating to pending loans");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PendingLoansPage()),
    );
  }

  void _navigateToActiveLoans() {
    _speak("Navigating to active loans");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActiveLoansPage()),
    );
  }

  void _showNotificationDialog() {
    _speak(
      "Opening notification dialog. Please enter the notification details.",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter notification title',
              ),
              onChanged: (value) => _notificationTitle = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Enter notification message',
              ),
              onChanged: (value) => _notificationMessage = value,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendNotification();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _notificationTitle = '';
  String _notificationMessage = '';

  Future<void> _sendNotification() async {
    if (_notificationTitle.isEmpty || _notificationMessage.isEmpty) {
      _speak("Please provide both title and message for the notification.");
      return;
    }

    try {
      await _notificationService.sendNotificationToAllUsers(
        title: _notificationTitle,
        message: _notificationMessage,
        type: NotificationType.general,
      );

      _speak("Notification sent successfully to all members.");

      setState(() {
        _notificationTitle = '';
        _notificationMessage = '';
      });
    } catch (e) {
      _speak("Error sending notification. Please try again.");
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _refreshData() async {
    _speak("Refreshing dashboard data");
    await _loadDashboardData();
    _speak("Dashboard data updated successfully");
  }

  void _showHelp() {
    _speak(
      "Available voice commands: "
      "Navigate to overview, View members, Check loans, "
      "Pending loans, Active loans, Send notification, "
      "Refresh data, and Logout. "
      "You can also say help anytime to hear these commands again.",
    );
  }

  void _logout() {
    _speak("Logging out. Thank you for using the admin dashboard.");
    FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Admin Dashboard'),
        backgroundColor: const Color(0xFF007C91),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Voice status section
          Container(
            padding: const EdgeInsets.all(16),
            color: _isListening ? Colors.green.shade100 : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  color: _isListening ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isListening
                        ? 'Listening... Say your command'
                        : _isSpeaking
                        ? 'Speaking: $_lastSpokenText'
                        : 'Voice assistant ready',
                    style: TextStyle(
                      color: _isListening
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Current command display
          if (_currentCommand.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Command: $_currentCommand',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Dashboard content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $_adminName!',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use voice commands to navigate and manage the SACCO.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Statistics grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Total Members',
                        _totalMembers.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Active Loans',
                        _activeLoans.toString(),
                        Icons.credit_card,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Pending Loans',
                        _pendingLoans.toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Total Savings',
                        NumberFormat.currency(
                          symbol: 'UGX ',
                        ).format(_totalSavings),
                        Icons.account_balance_wallet,
                        Colors.teal,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent transactions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Transactions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (_recentTransactions.isEmpty)
                            const Center(child: Text('No recent transactions'))
                          else
                            ..._recentTransactions.map(
                              (tx) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: tx['type'] == 'deposit'
                                      ? Colors.green
                                      : Colors.red,
                                  child: Icon(
                                    tx['type'] == 'deposit'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(tx['memberName']),
                                subtitle: Text(
                                  tx['type'].toString().toUpperCase(),
                                ),
                                trailing: Text(
                                  NumberFormat.currency(
                                    symbol: 'UGX ',
                                  ).format(tx['amount']),
                                  style: TextStyle(
                                    color: tx['type'] == 'deposit'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Voice commands help
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice Commands',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildCommandItem(
                            'Navigate to overview',
                            'Go to dashboard overview',
                          ),
                          _buildCommandItem(
                            'View members',
                            'See all SACCO members',
                          ),
                          _buildCommandItem(
                            'Check loans',
                            'View loan applications',
                          ),
                          _buildCommandItem(
                            'Send notification',
                            'Send message to all members',
                          ),
                          _buildCommandItem(
                            'Refresh data',
                            'Update dashboard information',
                          ),
                          _buildCommandItem('Help', 'Show available commands'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startAutoListening,
        backgroundColor: _isListening ? Colors.red : Colors.blue,
        child: Icon(_isListening ? Icons.stop : Icons.mic),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.record_voice_over, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }
}
