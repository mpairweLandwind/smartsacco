// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartsacco/pages/loan.dart';
import 'package:smartsacco/models/notification.dart';
import 'package:smartsacco/pages/loanapplication.dart';
import 'package:smartsacco/models/momopayment.dart';
import 'package:smartsacco/pages/login.dart';
import 'package:smartsacco/pages/feedback.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smartsacco/services/momoservices.dart';
import 'package:smartsacco/services/smartsacco_audio_manager.dart';
import 'package:smartsacco/services/enhanced_voice_navigation.dart';

class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key});

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  final Color _savingsColor = const Color(0xFF4CAF50);
  final Color _activeLoansColor = const Color(0xFF9C27B0);
  final Color _overdueColor = const Color(0xFFFF9800);
  final Color _totalDueColor = const Color(0xFF009688);
  final Color _primaryColor = Colors.blue;
  final Color _bgColor = const Color(0xFFF5F6FA);
  final Color _textSecondary = const Color.fromARGB(255, 8, 56, 71);

  int _currentIndex = 0;
  int _unreadNotifications = 0;
  String memberId = '';
  String memberName = '';
  String memberEmail = '';

  double _currentSavings = 0;
  List<Loan> _loans = [];
  List<AppNotification> _notifications = [];
  List<SavingsHistory> _savingsHistory = [];
  final List<Transaction> _transactions = [];

  FlutterTts flutterTts = FlutterTts();
  bool _awaitingDepositVoiceConfirmation = false;
  final double _pendingDepositAmount = 0;

  @override
  void initState() {
    super.initState();
    print('MemberDashboard initialized');
    _fetchTransactions();
    _initializeVoiceNavigation();
  }

  // Initialize voice navigation for member dashboard
  Future<void> _initializeVoiceNavigation() async {
    // Initialize enhanced voice navigation
    EnhancedVoiceNavigation().setCurrentScreen('member_dashboard');

    // Listen for navigation events
    EnhancedVoiceNavigation().navigationEventStream.listen((event) {
      _handleNavigationEvent(event);
    });

    // Provide welcome message
    await _speakWelcome();
  }

  // Handle voice commands for member dashboard
  void _handleVoiceCommand(String command) {
    print('Voice command received: $command');

    if (command.startsWith('check_balance') || command.contains('balance')) {
      _speakBalance();
    } else if (command.startsWith('make_deposit') ||
        command.contains('deposit')) {
      _showEnhancedDepositDialog();
    } else if (command.startsWith('go_loans') ||
        command.contains('loans') ||
        command.contains('my loans')) {
      _navigateToLoans();
    } else if (command.startsWith('go_transactions') ||
        command.contains('transactions') ||
        command.contains('history')) {
      _navigateToTransactions();
    } else if (command.startsWith('go_settings') ||
        command.contains('settings')) {
      _navigateToSettings();
    } else if (command.startsWith('apply_loan') ||
        command.contains('apply loan')) {
      _navigateToLoanApplication();
    } else if (command.startsWith('help') || command.contains('help')) {
      _speakHelp();
    } else if (command.startsWith('logout') || command.contains('logout')) {
      _handleLogout();
    } else if (command.startsWith('go_back') || command.contains('back')) {
      _handleGoBack();
    }
  }

  // Speak welcome message
  Future<void> _speakWelcome() async {
    await flutterTts.speak(
      "Welcome to your member dashboard, $memberName. You can check your balance, view loans, make deposits, and more.",
    );
  }

  // Speak current balance
  Future<void> _speakBalance() async {
    final balanceMessage =
        "Your current savings balance is ${_formatCurrency(_currentSavings)}. You have ${_loans.length} active loans.";
    await flutterTts.speak(balanceMessage);
  }

  // Speak help information
  Future<void> _speakHelp() async {
    await flutterTts.speak(
      "Available commands: check balance, make deposit, my loans, transactions, settings, apply loan, help, logout.",
    );
  }

  // Navigate to loans
  void _navigateToLoans() {
    Navigator.pushNamed(context, '/loans');
  }

  // Navigate to transactions
  void _navigateToTransactions() {
    setState(() {
      _currentIndex = 1; // Switch to transactions tab
    });
  }

  // Navigate to settings
  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  // Navigate to loan application
  void _navigateToLoanApplication() {
    Navigator.pushNamed(context, '/loan-application');
  }

  // Handle logout
  void _handleLogout() async {
    await flutterTts.speak("Logging you out. Thank you for using SmartSacco.");
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  // Handle go back
  void _handleGoBack() {
    Navigator.pop(context);
  }

  // Handle navigation events
  void _handleNavigationEvent(String event) {
    print('Navigation event: $event');

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
      case 'savings':
        _navigateToSavings();
        break;
      case 'loans':
        _navigateToLoans();
        break;
      case 'deposits':
        _showEnhancedDepositDialog();
        break;
      case 'transactions':
        _navigateToTransactions();
        break;
      case 'settings':
        _navigateToSettings();
        break;
      case 'loan_application':
        _navigateToLoanApplication();
        break;
      default:
        print('Unknown screen navigation: $screenId');
    }
  }

  // Navigate to savings
  void _navigateToSavings() {
    // This would navigate to a dedicated savings screen
    // For now, we'll show the savings information in a dialog
    _showSavingsDialog();
  }

  // Show savings dialog
  void _showSavingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Your Savings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Balance: ${_formatCurrency(_currentSavings)}'),
            SizedBox(height: 10),
            Text('Active Loans: ${_loans.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchTransactions() async {
    print('Fetching transactions for member dashboard');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      memberId = user.uid;
      print('Current user ID: $memberId');

      final memberDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();

      print('Member document data: ${memberDoc.data()}');

      setState(() {
        memberName = memberDoc['fullName'] ?? 'Member';
        memberEmail = memberDoc['email'] ?? 'member@sacco.com';
      });

      print('Member name: $memberName, email: $memberEmail');

      _fetchSavingsData();
      _fetchLoansData();
      _fetchNotifications();
    } else {
      print('No current user found in MemberDashboard');
    }
  }

  Future<void> _fetchSavingsData() async {
    final savingsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(memberId)
        .collection('savings')
        .orderBy('date', descending: true)
        .get();

    double totalSavings = 0;
    List<SavingsHistory> history = [];

    for (var doc in savingsSnapshot.docs) {
      final amount = doc['amount']?.toDouble() ?? 0;
      totalSavings += amount;
      history.add(
        SavingsHistory(
          amount: amount,
          date: doc['date'].toDate(),
          type: doc['type'] ?? 'Deposit',
          transactionId: doc.id,
        ),
      );
    }

    setState(() {
      _currentSavings = totalSavings;
      _savingsHistory = history;
    });
  }

  Future<void> _fetchLoansData() async {
    final loansSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(memberId)
        .collection('loans')
        .where('status', whereIn: ['Active', 'Overdue', 'Pending'])
        .get();

    List<Loan> loans = [];

    for (var doc in loansSnapshot.docs) {
      final payments = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('loans')
          .doc(doc.id)
          .collection('payments')
          .get();

      loans.add(
        Loan(
          id: doc.id,
          amount: doc['amount']?.toDouble() ?? 0,
          remainingBalance: doc['remainingBalance']?.toDouble() ?? 0,
          disbursementDate: doc['disbursementDate']?.toDate() ?? DateTime.now(),
          dueDate: doc['dueDate']?.toDate() ?? DateTime.now(),
          status: doc['status'] ?? 'Pending',
          type: doc['type'] ?? 'Personal',
          interestRate: doc['interestRate']?.toDouble() ?? 12.0,
          totalRepayment: doc['totalRepayment']?.toDouble() ?? 0,
          repaymentPeriod: doc['repaymentPeriod']?.toInt() ?? 12,
          payments: payments.docs
              .map(
                (p) => Payment(
                  amount: p['amount']?.toDouble() ?? 0,
                  date: p['date']?.toDate() ?? DateTime.now(),
                  reference: p['reference'] ?? '',
                ),
              )
              .toList(),
        ),
      );
    }

    setState(() {
      _loans = loans;
    });
  }

  Future<void> _fetchNotifications() async {
    final notificationsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(memberId)
        .collection('notifications')
        .orderBy('date', descending: true)
        .limit(10)
        .get();

    int unread = 0;
    List<AppNotification> notifications = [];

    for (var doc in notificationsSnapshot.docs) {
      final isRead = doc['isRead'] ?? false;
      if (!isRead) unread++;

      notifications.add(
        AppNotification(
          id: doc.id,
          title: doc['title'] ?? 'Notification',
          message: doc['message'] ?? '',
          date: doc['date']?.toDate() ?? DateTime.now(),
          type: NotificationType.values[doc['type'] ?? 0],
          isRead: isRead,
          actionUrl: doc['actionUrl'],
        ),
      );
    }

    if (mounted) {
      setState(() {
        _notifications = notifications;
        _unreadNotifications = unread;
      });

      // Voice feedback for new notifications
      if (unread > 0) {
        _speakVoiceFeedback(
          "You have $_unreadNotifications unread notifications",
        );
      }
    }
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _showLoanApplication() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanApplicationScreen(
          memberId: memberId,
          memberSavings: _currentSavings,
          onSubmit: (application) async {
            try {
              final amount = application['amount'];
              final interestRate = application['interestRate'];
              final repaymentPeriod = application['repaymentPeriod'];
              final interest =
                  (amount * interestRate / 100) * (repaymentPeriod / 12);
              final totalRepayment = amount + interest;
              final monthlyPayment = repaymentPeriod > 0
                  ? totalRepayment / repaymentPeriod
                  : 0;

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(memberId)
                  .collection('loans')
                  .add({
                    'amount': amount,
                    'remainingBalance': totalRepayment,
                    'disbursementDate': DateTime.now(),
                    'dueDate': DateTime.now().add(
                      Duration(days: repaymentPeriod * 30),
                    ),
                    'status': 'Pending Approval',
                    'type': application['type'] ?? 'Personal',
                    'interestRate': interestRate,
                    'totalRepayment': totalRepayment,
                    'monthlyPayment': monthlyPayment,
                    'purpose': application['purpose'],
                    'applicationDate': DateTime.now(),
                  });

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(memberId)
                  .collection('notifications')
                  .add({
                    'title': 'Loan Application Submitted',
                    'message':
                        'Your loan application of ${_formatCurrency(amount)} is under review',
                    'date': DateTime.now(),
                    'type': NotificationType.loan.index,
                    'isRead': false,
                  });

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loan application submitted!')),
              );

              _fetchLoansData();
              _fetchNotifications();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error submitting application: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  void _makePayment(Loan loan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MomoPaymentPage(
          amount: loan.nextPaymentAmount,
          onPaymentComplete: (success) async {
            if (success) {
              try {
                final paymentAmount = loan.nextPaymentAmount;
                final paymentRef = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberId)
                    .collection('loans')
                    .doc(loan.id)
                    .collection('payments')
                    .add({
                      'amount': paymentAmount,
                      'date': DateTime.now(),
                      'reference':
                          'MOMO-${DateTime.now().millisecondsSinceEpoch}',
                    });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberId)
                    .collection('loans')
                    .doc(loan.id)
                    .update({
                      'remainingBalance': loan.remainingBalance - paymentAmount,
                      'nextPaymentDate': DateTime.now().add(
                        const Duration(days: 30),
                      ),
                    });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberId)
                    .collection('transactions')
                    .add({
                      'amount': paymentAmount,
                      'date': DateTime.now(),
                      'type': 'Loan Repayment',
                      'status': 'Completed',
                      'method': 'Mobile Money',
                      'loanId': loan.id,
                      'paymentId': paymentRef.id,
                    });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(memberId)
                    .collection('notifications')
                    .add({
                      'title': 'Payment Received',
                      'message':
                          'Your payment of ${_formatCurrency(paymentAmount)} for loan ${loan.id.substring(0, 8)} has been received',
                      'date': DateTime.now(),
                      'type': NotificationType.payment.index,
                      'isRead': false,
                    });

                _fetchLoansData();
                _fetchNotifications();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment successful!')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error recording payment: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showNotifications() {
    setState(() => _currentIndex = 3);

    for (var notification in _notifications.where((n) => !n.isRead)) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('notifications')
          .doc(notification.id)
          .update({'isRead': true});
    }

    _fetchNotifications();
  }

  void _submitFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SaccoFeedbackPage()),
    );
  }

  double _calculateTotalDue() {
    return _loans.fold(0, (acc, loan) => acc + loan.nextPaymentAmount);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
    ).format(amount);
  }

  // Voice feedback methods
  Future<void> _speakVoiceFeedback(String message) async {
    try {
      await flutterTts.speak(message);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _speak(String message) async {
    try {
      await flutterTts.speak(message);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _voiceConfirmDeposit(double amount, String method) async {
    final confirmMessage =
        "Confirm deposit of ${_formatCurrency(amount)} via $method. Say yes to confirm or no to cancel.";
    await _speak(confirmMessage);

    // In a real implementation, you would integrate with speech recognition
    // For now, we'll use a simple dialog
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Deposit'),
          content: Text(
            'Confirm deposit of ${_formatCurrency(amount)} via $method?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _processDeposit(amount, method);
      }
    }
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Savings';
      case 2:
        return 'Transactions';
      case 3:
        return 'Notifications';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotifications,
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_unreadNotifications',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _getCurrentScreen(int activeLoans, int overdueLoans, double totalDue) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen(activeLoans, overdueLoans, totalDue);
      case 1:
        return _buildSavingsScreen();
      case 2:
        return _buildTransactionsScreen();
      case 3:
        return _buildNotificationsScreen();
      default:
        return _buildHomeScreen(activeLoans, overdueLoans, totalDue);
    }
  }

  Widget _buildHomeScreen(int activeLoans, int overdueLoans, double totalDue) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildStatsGrid(_currentSavings, activeLoans, overdueLoans, totalDue),
          const SizedBox(height: 20),
          _buildQuickActionsSection(),
          const SizedBox(height: 20),
          _buildDuePaymentsSection(),
          const SizedBox(height: 20),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.person, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  memberName.length > 20
                      ? '${memberName.substring(0, 20)}...'
                      : memberName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  memberEmail.length > 30
                      ? '${memberEmail.substring(0, 30)}...'
                      : memberEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    double savings,
    int activeLoans,
    int overdueLoans,
    double totalDue,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        GestureDetector(
          onTap: () => _showSavingsDetails(),
          child: _buildStatCard(
            'Savings',
            _formatCurrency(savings),
            _savingsColor,
            Icons.savings,
          ),
        ),
        GestureDetector(
          onTap: () => _showActiveLoans(),
          child: _buildStatCard(
            'Active Loans',
            activeLoans.toString(),
            _activeLoansColor,
            Icons.credit_card,
          ),
        ),
        GestureDetector(
          onTap: () => _showOverdueLoans(),
          child: _buildStatCard(
            'Overdue',
            overdueLoans.toString(),
            _overdueColor,
            Icons.warning,
          ),
        ),
        GestureDetector(
          onTap: () => _showTotalDueDetails(),
          child: _buildStatCard(
            'Total Due',
            _formatCurrency(totalDue),
            _totalDueColor,
            Icons.payment,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Deposit',
                  Icons.add_circle,
                  Colors.green,
                  _showDepositDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Withdraw',
                  Icons.remove_circle,
                  Colors.orange,
                  _initiateWithdrawal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Apply Loan',
                  Icons.credit_card,
                  _primaryColor,
                  _showLoanApplication,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Transactions',
                  Icons.receipt_long,
                  Colors.purple,
                  () => setState(() => _currentIndex = 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuePaymentsSection() {
    final duePayments = _loans
        .where((loan) => loan.status == 'Active' || loan.status == 'Overdue')
        .toList();

    if (duePayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 40, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              'No Due Payments',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have no active or overdue loans at this time',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.green.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Loan Repayments Due',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...duePayments.map((loan) => _buildLoanDueCard(loan)),
        ],
      ),
    );
  }

  Widget _buildLoanDueCard(Loan loan) {
    final isOverdue = loan.status == 'Overdue';
    final nextPaymentDate = loan.payments.isEmpty
        ? loan.disbursementDate.add(const Duration(days: 30))
        : loan.payments.last.date.add(const Duration(days: 30));
    final daysRemaining = nextPaymentDate.difference(DateTime.now()).inDays;
    final nextPaymentAmount = loan.totalRepayment / loan.repaymentPeriod;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan ${loan.id.substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(nextPaymentAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOverdue ? 'OVERDUE' : 'DUE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverdue
                    ? 'Overdue by ${daysRemaining.abs()} days'
                    : 'Due in $daysRemaining days',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isOverdue ? Colors.red : Colors.orange,
                ),
              ),
              ElevatedButton(
                onPressed: () => _makePayment(loan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOverdue ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Pay Now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No Recent Transactions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your transaction history will appear here',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 2),
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._transactions.take(3).map((txn) => _buildTransactionCard(txn)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction txn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(txn.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTransactionIcon(txn.type),
              color: _getStatusColor(txn.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.type,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${DateFormat('MMM d').format(txn.date)} • ${txn.method}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(txn.amount),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(txn.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  txn.status,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(txn.status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return Icons.add_circle;
      case 'withdrawal':
        return Icons.remove_circle;
      case 'loan repayment':
        return Icons.credit_card;
      default:
        return Icons.receipt;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showSavingsDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SavingsDetailsScreen(
        currentSavings: _currentSavings,
        savingsHistory: _savingsHistory,
      ),
    );
  }

  void _showActiveLoans() {
    final activeLoans = _loans
        .where((loan) => loan.status == 'Active')
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LoansListScreen(
        loans: activeLoans,
        title: 'Active Loans',
        onPayment: _makePayment,
      ),
    );
  }

  void _showOverdueLoans() {
    final overdueLoans = _loans
        .where((loan) => loan.status == 'Overdue')
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LoansListScreen(
        loans: overdueLoans,
        title: 'Overdue Loans',
        onPayment: _makePayment,
      ),
    );
  }

  void _showTotalDueDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TotalDueScreen(
        loans: _loans,
        totalDue: _calculateTotalDue(),
        onPayment: _makePayment,
      ),
    );
  }

  Widget _buildSavingsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 20),
          _buildSavingsBalanceCard(),
          const SizedBox(height: 20),
          _buildEnhancedTransactionHistory(),
        ],
      ),
    );
  }

  Widget _buildSavingsBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green[50]!, Colors.green[100]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.savings, size: 48, color: Colors.green[700]),
              ),
              const SizedBox(height: 16),
              Text(
                'Savings Account Balance',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(_currentSavings),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _showEnhancedDepositDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Make Deposit',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedTransactionHistory() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                ),
                if (_transactions.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 2),
                    child: Text(
                      'View All',
                      style: GoogleFonts.poppins(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_transactions.isEmpty)
              _buildEmptyTransactionState()
            else
              _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactionState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: _transactions
          .take(5)
          .map((txn) => _buildEnhancedTransactionCard(txn))
          .toList(),
    );
  }

  Widget _buildEnhancedTransactionCard(Transaction txn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(txn.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getTransactionIcon(txn.type),
              color: _getStatusColor(txn.status),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.type,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, y').format(txn.date),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.payment, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        txn.method,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatCurrency(txn.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(txn.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getStatusColor(txn.status).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  txn.status,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(txn.status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEnhancedDepositDialog() async {
    final amountController = TextEditingController();
    String selectedMethod = 'Mobile Money';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(
              'Make Deposit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (UGX)',
                  prefixText: 'UGX ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Mobile Money',
                    child: Row(
                      children: [
                        Icon(Icons.phone_android, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Mobile Money'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Bank Transfer',
                    child: Row(
                      children: [
                        Icon(Icons.account_balance, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Bank Transfer'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedMethod = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                _voiceConfirmDeposit(amount, selectedMethod);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Deposit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Keep the original deposit dialog for backward compatibility
  Future<void> _showDepositDialog() async {
    await _showEnhancedDepositDialog();
  }

  Future<void> _processDeposit(
    double amount,
    String method, {
    bool voiceConfirmed = false,
  }) async {
    if (!_awaitingDepositVoiceConfirmation && !voiceConfirmed) {
      _voiceConfirmDeposit(amount, method);
      return;
    }
    setState(() => _awaitingDepositVoiceConfirmation = false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('savings')
          .add({
            'amount': amount,
            'date': DateTime.now(),
            'type': 'Deposit',
            'method': method,
          });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('transactions')
          .add({
            'amount': amount,
            'date': DateTime.now(),
            'type': 'Deposit',
            'status': 'Completed',
            'method': method,
          });

      setState(() {
        _currentSavings += amount;
      });

      _speak("Deposit of ${_formatCurrency(amount)} successful.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deposit of ${_formatCurrency(amount)} successful'),
        ),
      );

      _fetchSavingsData();
    } catch (e) {
      _speak("There was an error processing your deposit. Please try again.");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing deposit: $e')));
    }
  }

  Widget _buildTransactionsScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _filterTransactions,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _transactions.length,
            itemBuilder: (context, index) =>
                _buildTransactionCard(_transactions[index]),
          ),
        ),
      ],
    );
  }

  void _filterTransactions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    String selectedType = 'All';
    String selectedStatus = 'All';
    DateTime? startDate;
    DateTime? endDate;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: _primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Filter Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transaction Type Filter
                        _buildFilterSection(
                          'Transaction Type',
                          Icons.category,
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _primaryColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items:
                                [
                                      'All',
                                      'Deposit',
                                      'Withdrawal',
                                      'Loan Payment',
                                      'Fee',
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedType = value!;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Status Filter
                        _buildFilterSection(
                          'Status',
                          Icons.info_outline,
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _primaryColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            items: ['All', 'Completed', 'Pending', 'Failed']
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      status,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedStatus = value!;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Date Range Filter
                        _buildFilterSection(
                          'Date Range',
                          Icons.calendar_today,
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateButton(
                                      'Start Date',
                                      startDate,
                                      Icons.calendar_today,
                                      () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now().subtract(
                                            const Duration(days: 30),
                                          ),
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365),
                                          ),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            startDate = date;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDateButton(
                                      'End Date',
                                      endDate,
                                      Icons.calendar_today,
                                      () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 365),
                                          ),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            endDate = date;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (startDate != null || endDate != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: _primaryColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          startDate != null && endDate != null
                                              ? '${DateFormat('MMM d, y').format(startDate!)} - ${DateFormat('MMM d, y').format(endDate!)}'
                                              : startDate != null
                                              ? 'From: ${DateFormat('MMM d, y').format(startDate!)}'
                                              : 'To: ${DateFormat('MMM d, y').format(endDate!)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              selectedType = 'All';
                              selectedStatus = 'All';
                              startDate = null;
                              endDate = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _applyFilters(
                              selectedType,
                              selectedStatus,
                              startDate,
                              endDate,
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDateButton(
    String label,
    DateTime? selectedDate,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selectedDate != null
                      ? _primaryColor
                      : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('MMM d, y').format(selectedDate)
                        : label,
                    style: GoogleFonts.poppins(
                      color: selectedDate != null
                          ? _primaryColor
                          : Colors.grey[600],
                      fontWeight: selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyFilters(
    String type,
    String status,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    setState(() {
      _currentIndex = 2; // Switch to transactions tab
    });

    // Apply filters to transactions
    final filteredTransactions = _transactions.where((txn) {
      // Type filter
      if (type != 'All' && txn.type != type) return false;

      // Status filter
      if (status != 'All' && txn.status != status) return false;

      // Date range filter
      if (startDate != null && txn.date.isBefore(startDate)) return false;
      if (endDate != null && txn.date.isAfter(endDate)) return false;

      return true;
    }).toList();

    // Show filtered results
    _showFilteredResults(
      filteredTransactions,
      type,
      status,
      startDate,
      endDate,
    );
  }

  void _showFilteredResults(
    List<Transaction> filteredTransactions,
    String type,
    String status,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filtered Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (type != 'All')
                          _buildFilterChip('Type: $type', Icons.category),
                        if (status != 'All')
                          _buildFilterChip(
                            'Status: $status',
                            Icons.info_outline,
                          ),
                        if (startDate != null)
                          _buildFilterChip(
                            'From: ${DateFormat('MMM d, y').format(startDate)}',
                            Icons.calendar_today,
                          ),
                        if (endDate != null)
                          _buildFilterChip(
                            'To: ${DateFormat('MMM d, y').format(endDate)}',
                            Icons.calendar_today,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${filteredTransactions.length} transaction${filteredTransactions.length == 1 ? '' : 's'} found',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction List
              Flexible(
                child: filteredTransactions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildTransactionCard(
                            filteredTransactions[index],
                          ),
                        ),
                      ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exportFilteredResults(filteredTransactions);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Export',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildFilterChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters to see more results',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _exportFilteredResults(List<Transaction> transactions) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting ${transactions.length} transactions...'),
        backgroundColor: _primaryColor,
      ),
    );
  }

  void _showTransactionDetails(Transaction txn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID:', txn.id),
            _buildDetailRow('Type:', txn.type),
            _buildDetailRow('Amount:', _formatCurrency(txn.amount)),
            _buildDetailRow('Date:', DateFormat('MMM d, y').format(txn.date)),
            _buildDetailRow('Method:', txn.method),
            _buildDetailRow('Status:', txn.status),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildNotificationsScreen() {
    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) =>
          _buildNotificationCard(_notifications[index]),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          _getNotificationIcon(notification.type),
          color: _getNotificationColor(notification.type),
        ),
        title: Text(notification.title),
        subtitle: Text(notification.message),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(DateFormat('MMM d').format(notification.date)),
            if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        onTap: () => _viewNotification(notification),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.loan:
        return Icons.money;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.payment:
        return Colors.green;
      case NotificationType.loan:
        return Colors.purple;
      case NotificationType.promotion:
        return Colors.orange;
      case NotificationType.general:
        return Colors.blue;
    }
  }

  void _viewNotification(AppNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 16),
            Text(
              DateFormat('MMM d, y hh:mm a').format(notification.date),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (notification.actionUrl != null)
            TextButton(
              onPressed: () {
                // Handle action URL
                Navigator.pop(context);
              },
              child: const Text('View Details'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      selectedItemColor: _primaryColor,
      unselectedItemColor: _textSecondary,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Savings'),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
      ],
    );
  }

  // Add withdrawal functionality
  void _initiateWithdrawal() {
    showDialog(
      context: context,
      builder: (context) => _buildWithdrawalDialog(),
    );
  }

  Widget _buildWithdrawalDialog() {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedMethod = 'MTN MoMo';

    return AlertDialog(
      title: const Text('Withdraw Funds'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (UGX)',
              prefixText: 'UGX ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+256 ',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedMethod,
            decoration: const InputDecoration(labelText: 'Withdrawal Method'),
            items: ['MTN MoMo', 'Airtel Money', 'Bank Transfer']
                .map(
                  (method) =>
                      DropdownMenuItem(value: method, child: Text(method)),
                )
                .toList(),
            onChanged: (value) {
              selectedMethod = value!;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(amountController.text);
            final phone = phoneController.text;

            if (amount != null && amount > 0 && phone.isNotEmpty) {
              Navigator.pop(context);
              _confirmWithdrawal(amount, phone, selectedMethod);
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter valid amount and phone number'),
                ),
              );
            }
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }

  void _confirmWithdrawal(double amount, String phone, String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${_formatCurrency(amount)}'),
            Text('Phone: +256 $phone'),
            Text('Method: $method'),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to proceed with this withdrawal?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processWithdrawal(amount, phone, method);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal(
    double amount,
    String phone,
    String method,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Processing withdrawal...'),
            ],
          ),
        ),
      );

      // Process withdrawal based on method
      Map<String, dynamic> result;
      if (method == 'MTN MoMo') {
        result = await _processMTNWithdrawal(amount, phone);
      } else {
        result = {
          'success': false,
          'message': 'Withdrawal method not yet supported',
        };
      }

      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        // Add transaction record
        await _addWithdrawalTransaction(amount, method, result['reference']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal successful! Reference: ${result['reference']}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh data
        _fetchTransactions();
        _fetchSavingsData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing withdrawal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _processMTNWithdrawal(
    double amount,
    String phone,
  ) async {
    try {
      // Create MoMo service instance
      final momoService = MomoService();

      // Format phone number
      final formattedPhone = phone.startsWith('0') ? phone.substring(1) : phone;
      final fullPhone = '256$formattedPhone';

      // Process transfer
      final result = await momoService.transferMoney(
        phoneNumber: fullPhone,
        amount: amount,
        externalId: 'WITHDRAWAL_${DateTime.now().millisecondsSinceEpoch}',
        payeeMessage: 'SACCO Withdrawal',
      );

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error processing MTN transfer: $e'};
    }
  }

  Future<void> _addWithdrawalTransaction(
    double amount,
    String method,
    String reference,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('transactions')
          .add({
            'amount': amount,
            'type': 'Withdrawal',
            'method': method,
            'status': 'Completed',
            'date': FieldValue.serverTimestamp(),
            'reference': reference,
            'phoneNumber': '', // Will be filled from withdrawal data
          });
    } catch (e) {
      debugPrint('Error adding withdrawal transaction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLoans = _loans.where((loan) => loan.status == 'Active').length;
    final overdueLoans = _loans
        .where((loan) => loan.status == 'Overdue')
        .length;
    final totalDue = _calculateTotalDue();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        actions: [
          if (_currentIndex == 0) _buildNotificationBadge(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _getCurrentScreen(activeLoans, overdueLoans, totalDue),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showLoanApplication,
              backgroundColor: _primaryColor,
              child: const Icon(Icons.add),
            )
          : _currentIndex == 3
          ? FloatingActionButton(
              onPressed: _submitFeedback,
              child: const Icon(Icons.feedback),
            )
          : null,
    );
  }
}

class SavingsDetailsScreen extends StatelessWidget {
  final double currentSavings;
  final List<SavingsHistory> savingsHistory;

  const SavingsDetailsScreen({
    super.key,
    required this.currentSavings,
    required this.savingsHistory,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Savings Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildEnhancedBalanceCard(context),
              const SizedBox(height: 20),
              Expanded(
                child: _buildEnhancedHistoryList(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedBalanceCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green[50]!, Colors.green[100]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 32,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Current Savings Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat.currency(symbol: 'UGX ').format(currentSavings),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedHistoryList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    if (savingsHistory.isEmpty) {
      return _buildEmptyHistoryState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction History',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: savingsHistory.length,
            itemBuilder: (context, index) {
              final item = savingsHistory[index];
              return _buildEnhancedHistoryItem(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transaction history',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your savings transactions will appear here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHistoryItem(BuildContext context, SavingsHistory item) {
    final isDeposit = item.type == 'Deposit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDeposit ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isDeposit ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, y').format(item.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat.jm().format(item.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.currency(symbol: 'UGX ').format(item.amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDeposit ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoansListScreen extends StatelessWidget {
  final List<Loan> loans;
  final String title;
  final Function(Loan) onPayment;

  const LoansListScreen({
    super.key,
    required this.loans,
    required this.title,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Icon(Icons.drag_handle),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: loans.length,
                  itemBuilder: (context, index) {
                    final loan = loans[index];
                    final nextPaymentDate = loan.payments.isEmpty
                        ? loan.disbursementDate.add(const Duration(days: 30))
                        : loan.payments.last.date.add(const Duration(days: 30));
                    final daysRemaining = nextPaymentDate
                        .difference(DateTime.now())
                        .inDays;
                    final isOverdue = daysRemaining < 0;
                    final nextPaymentAmount =
                        loan.totalRepayment /
                        (loan.dueDate.difference(loan.disbursementDate).inDays /
                            30);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Loan #${loan.id.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Chip(
                                  label: Text(loan.status),
                                  backgroundColor: loan.status == 'Active'
                                      ? Colors.purple[100]
                                      : Colors.orange[100],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildLoanDetailRow(
                              'Original Amount:',
                              NumberFormat.currency(
                                symbol: 'UGX ',
                              ).format(loan.amount),
                            ),
                            _buildLoanDetailRow(
                              'Remaining Balance:',
                              NumberFormat.currency(
                                symbol: 'UGX ',
                              ).format(loan.remainingBalance),
                            ),
                            _buildLoanDetailRow(
                              'Next Payment:',
                              NumberFormat.currency(
                                symbol: 'UGX ',
                              ).format(nextPaymentAmount),
                            ),
                            _buildLoanDetailRow(
                              'Due Date:',
                              '${DateFormat('MMM d, y').format(nextPaymentDate)} '
                                  '(${isOverdue ? 'Overdue ${-daysRemaining} days' : 'Due in $daysRemaining days'})',
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => onPayment(loan),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                ),
                                child: const Text('Make Payment'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

class TotalDueScreen extends StatelessWidget {
  final List<Loan> loans;
  final double totalDue;
  final Function(Loan) onPayment;

  const TotalDueScreen({
    super.key,
    required this.loans,
    required this.totalDue,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final activeLoans = loans.where((loan) => loan.status == 'Active').toList();
    final overdueLoans = loans
        .where((loan) => loan.status == 'Overdue')
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Icon(Icons.drag_handle),
              const SizedBox(height: 10),
              Text(
                'Total Due Summary',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Total Amount Due',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        NumberFormat.currency(symbol: 'UGX ').format(totalDue),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (overdueLoans.isNotEmpty) ...[
                _buildLoanTypeSection('Overdue Loans', overdueLoans, context),
                const SizedBox(height: 16),
              ],
              if (activeLoans.isNotEmpty) ...[
                _buildLoanTypeSection('Active Loans', activeLoans, context),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanTypeSection(
    String title,
    List<Loan> loans,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...loans.map((loan) {
          final nextPaymentDate = loan.payments.isEmpty
              ? loan.disbursementDate.add(const Duration(days: 30))
              : loan.payments.last.date.add(const Duration(days: 30));
          final daysRemaining = nextPaymentDate
              .difference(DateTime.now())
              .inDays;
          final isOverdue = daysRemaining < 0;
          final nextPaymentAmount =
              loan.totalRepayment /
              (loan.dueDate.difference(loan.disbursementDate).inDays / 30);

          return ListTile(
            title: Text('Loan #${loan.id.substring(0, 8)}'),
            subtitle: Text(
              'Next Payment: ${NumberFormat.currency(symbol: 'UGX ').format(nextPaymentAmount)}\n'
              'Due: ${DateFormat('MMM d').format(nextPaymentDate)} '
              '(${isOverdue ? 'Overdue ${-daysRemaining} days' : 'Due in $daysRemaining days'})',
            ),
            trailing: ElevatedButton(
              onPressed: () => onPayment(loan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Pay'),
            ),
          );
        }),
      ],
    );
  }
}

class SavingsHistory {
  final double amount;
  final DateTime date;
  final String type;
  final String transactionId;

  SavingsHistory({
    required this.amount,
    required this.date,
    required this.type,
    required this.transactionId,
  });
}

class Transaction {
  final String id;
  final double amount;
  final DateTime date;
  final String type;
  final String status;
  final String method;
  final String? loanId;
  final String? paymentId;

  Transaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    required this.method,
    this.loanId,
    this.paymentId,
  });
}
