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
import 'package:smartsacco/services/momoservices.dart';
import 'package:smartsacco/services/user_preferences_service.dart';

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

  bool _isBlindUser = false;

  @override
  void initState() {
    super.initState();
    print('MemberDashboard initialized');
    _checkUserMode();
    _fetchTransactions();
  }

  // Check if user is blind to conditionally enable/disable features
  Future<void> _checkUserMode() async {
    final accessibilityMode = UserPreferencesService().getAccessibilityMode();
    setState(() {
      _isBlindUser = accessibilityMode == 'blind';
    });
    print('User mode: ${_isBlindUser ? 'Blind' : 'Sighted'}');
  }

  // Speak welcome message
  Future<void> _speakWelcome() async {
    // This functionality has been removed as per instructions
  }

  // Speak current balance
  Future<void> _speakBalance() async {
    // This functionality has been removed as per instructions
  }

  // Speak help information
  Future<void> _speakHelp() async {
    // This functionality has been removed as per instructions
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
    // This functionality has been removed as per instructions
  }

  // Handle go back
  void _handleGoBack() {
    Navigator.pop(context);
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
    print('🔄 Fetching transactions for member dashboard');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      memberId = user.uid;
      print('✅ Current user ID: $memberId');

      try {
        final memberDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();

        if (memberDoc.exists) {
          print('✅ Member document found: ${memberDoc.data()}');

          setState(() {
            memberName = memberDoc['fullName'] ?? 'Member';
            memberEmail = memberDoc['email'] ?? 'member@sacco.com';
          });

          print('✅ Member details loaded:');
          print('   - Name: $memberName');
          print('   - Email: $memberEmail');

          // Fetch all data in parallel for better performance
          await Future.wait([
            _fetchSavingsData(),
            _fetchLoansData(),
            _fetchNotifications(),
            _fetchTransactionHistory(),
          ]);

          print('✅ All data fetched successfully');
        } else {
          print('❌ Member document not found for ID: $memberId');
          // Handle missing member document
          _showErrorDialog(
            'Data Error',
            'Member data not found. Please contact support.',
          );
        }
      } catch (e) {
        print('❌ Error fetching member data: $e');
        debugPrint('Error fetching member data: $e');
        _showErrorDialog('Connection Error', 'Failed to load member data: $e');
      }
    } else {
      print('❌ No current user found in MemberDashboard');
      _showErrorDialog(
        'Authentication Error',
        'User not authenticated. Please login again.',
      );
    }
  }

  // New method to fetch transaction history
  Future<void> _fetchTransactionHistory() async {
    try {
      print('🔄 Fetching transaction history for member: $memberId');

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      List<Transaction> transactions = [];

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();

        // Validate transaction data
        if (data['amount'] != null && data['date'] != null) {
          transactions.add(
            Transaction(
              id: doc.id,
              amount: data['amount']?.toDouble() ?? 0,
              type: data['type'] ?? 'Unknown',
              date: data['date']?.toDate() ?? DateTime.now(),
              status: data['status'] ?? 'Pending',
              method: data['method'] ?? 'Unknown',
              description: data['description'] ?? '',
            ),
          );
        } else {
          print('⚠️ Skipping invalid transaction: ${doc.id}');
        }
      }

      if (mounted) {
        setState(() {
          _transactions.clear();
          _transactions.addAll(transactions);
        });
      }

      print('✅ Transaction history fetched:');
      print('   - Total transactions: ${transactions.length}');
      print(
        '   - Recent transactions: ${transactions.take(5).map((t) => '${t.type}: ${_formatCurrency(t.amount)}').join(', ')}',
      );
    } catch (e) {
      print('❌ Error fetching transaction history: $e');
      debugPrint('Error fetching transaction history: $e');
    }
  }

  Future<void> _fetchSavingsData() async {
    try {
      print('🔄 Fetching savings data for member: $memberId');

      final savingsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('savings')
          .orderBy('date', descending: true)
          .get();

      double totalSavings = 0;
      List<SavingsHistory> history = [];

      for (var doc in savingsSnapshot.docs) {
        final data = doc.data();

        // Validate savings data
        if (data['amount'] != null && data['date'] != null) {
          final amount = data['amount']?.toDouble() ?? 0;
          totalSavings += amount;
          history.add(
            SavingsHistory(
              amount: amount,
              date: data['date'].toDate(),
              type: data['type'] ?? 'Deposit',
              transactionId: doc.id,
            ),
          );
        } else {
          print('⚠️ Skipping invalid savings record: ${doc.id}');
        }
      }

      if (mounted) {
        setState(() {
          _currentSavings = totalSavings;
          _savingsHistory = history;
        });
      }

      print('✅ Savings data fetched:');
      print('   - Total savings: ${_formatCurrency(totalSavings)}');
      print('   - Number of transactions: ${history.length}');
      print('   - Previous balance: ${_formatCurrency(_currentSavings)}');
      print('   - New balance: ${_formatCurrency(_currentSavings)}');
      print(
        '   - Balance change: ${_formatCurrency(totalSavings - _currentSavings)}',
      );
    } catch (e) {
      print('❌ Error fetching savings data: $e');
      debugPrint('Error fetching savings data: $e');
    }
  }

  Future<void> _fetchLoansData() async {
    try {
      print('🔄 Fetching loans data for member: $memberId');

      // Fetch all loans with different statuses
      final loansSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('loans')
          .where(
            'status',
            whereIn: [
              'Active',
              'Approved',
              'Overdue',
              'Pending',
              'Pending Approval',
              'Rejected',
            ],
          )
          .get();

      List<Loan> loans = [];

      for (var doc in loansSnapshot.docs) {
        final loanData = doc.data();

        // Validate loan data
        if (loanData['amount'] != null) {
          final status = loanData['status'] ?? 'Pending';

          // Fetch payments for this loan
          try {
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
                amount: loanData['amount']?.toDouble() ?? 0,
                remainingBalance: loanData['remainingBalance']?.toDouble() ?? 0,
                disbursementDate:
                    loanData['disbursementDate']?.toDate() ?? DateTime.now(),
                dueDate: loanData['dueDate']?.toDate() ?? DateTime.now(),
                status: status,
                type: loanData['type'] ?? 'Personal',
                interestRate: loanData['interestRate']?.toDouble() ?? 12.0,
                totalRepayment: loanData['totalRepayment']?.toDouble() ?? 0,
                repaymentPeriod: loanData['repaymentPeriod']?.toInt() ?? 12,
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
          } catch (paymentError) {
            print(
              '⚠️ Error fetching payments for loan ${doc.id}: $paymentError',
            );
            // Add loan without payments
            loans.add(
              Loan(
                id: doc.id,
                amount: loanData['amount']?.toDouble() ?? 0,
                remainingBalance: loanData['remainingBalance']?.toDouble() ?? 0,
                disbursementDate:
                    loanData['disbursementDate']?.toDate() ?? DateTime.now(),
                dueDate: loanData['dueDate']?.toDate() ?? DateTime.now(),
                status: status,
                type: loanData['type'] ?? 'Personal',
                interestRate: loanData['interestRate']?.toDouble() ?? 12.0,
                totalRepayment: loanData['totalRepayment']?.toDouble() ?? 0,
                repaymentPeriod: loanData['repaymentPeriod']?.toInt() ?? 12,
                payments: [],
              ),
            );
          }
        } else {
          print('⚠️ Skipping invalid loan: ${doc.id}');
        }
      }

      if (mounted) {
        setState(() {
          _loans = loans;
        });

        print('✅ Loans data updated:');
        print('   - Total loans: ${loans.length}');
        print(
          '   - Active loans: ${loans.where((l) => l.status == 'Active' || l.status == 'Approved').length}',
        );
        print(
          '   - Pending loans: ${loans.where((l) => l.status == 'Pending' || l.status == 'Pending Approval').length}',
        );
        print(
          '   - Overdue loans: ${loans.where((l) => l.status == 'Overdue').length}',
        );
        print(
          '   - Rejected loans: ${loans.where((l) => l.status == 'Rejected').length}',
        );
      }
    } catch (e) {
      print('❌ Error fetching loans data: $e');
      debugPrint('Error fetching loans data: $e');
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      print('🔄 Fetching notifications for member: $memberId');

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
        final data = doc.data();
        final isRead = data['isRead'] ?? false;
        if (!isRead) unread++;

        notifications.add(
          AppNotification(
            id: doc.id,
            title: data['title'] ?? 'Notification',
            message: data['message'] ?? '',
            date: data['date']?.toDate() ?? DateTime.now(),
            type: NotificationType.values[data['type'] ?? 0],
            isRead: isRead,
            actionUrl:
                data['actionUrl'], // This field is optional and can be null
          ),
        );
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _unreadNotifications = unread;
        });

        print('✅ Notifications fetched:');
        print('   - Total notifications: ${notifications.length}');
        print('   - Unread notifications: $unread');

        // Voice feedback for new notifications
        if (unread > 0) {
          // This functionality has been removed as per instructions
        }
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      debugPrint('Error fetching notifications: $e');
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
    return _loans.fold(0, (acc, loan) {
      // Only include active and approved loans
      if (loan.status != 'Active' && loan.status != 'Approved') {
        return acc;
      }

      // Calculate the next payment date
      final nextPaymentDate = loan.payments.isEmpty
          ? loan.disbursementDate.add(const Duration(days: 30))
          : loan.payments.last.date.add(const Duration(days: 30));

      // Check if the next payment is overdue or due soon
      final daysUntilPayment = nextPaymentDate
          .difference(DateTime.now())
          .inDays;
      final isOverdue = daysUntilPayment < 0;
      final isDueSoon = daysUntilPayment <= 7 && daysUntilPayment >= 0;

      // Calculate overdue amount if applicable
      double overdueAmount = 0;
      if (isOverdue) {
        // Calculate how many months are overdue
        final overdueMonths = (daysUntilPayment.abs() / 30).ceil();
        overdueAmount = loan.monthlyPayment * overdueMonths;
      }

      // Return the appropriate amount based on payment status
      if (isOverdue) {
        return acc + overdueAmount;
      } else if (isDueSoon) {
        return acc + loan.monthlyPayment;
      } else {
        // For loans that are not due yet, only include if they're overdue
        return acc;
      }
    });
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
    ).format(amount);
  }

  // Voice feedback methods
  Future<void> _speakVoiceFeedback(String message) async {
    // This functionality has been removed as per instructions
  }

  Future<void> _speak(String message) async {
    // This functionality has been removed as per instructions
  }

  // Voice confirmation deposit method removed as per instructions

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
    // Calculate additional stats
    final pendingLoans = _loans
        .where(
          (loan) =>
              loan.status == 'Pending' || loan.status == 'Pending Approval',
        )
        .length;
    final totalDeposits = _savingsHistory
        .where((item) => item.type.toLowerCase().contains('deposit'))
        .fold(0.0, (sum, item) => sum + item.amount);
    final totalWithdrawals = _savingsHistory
        .where((item) => item.type.toLowerCase().contains('withdraw'))
        .fold(0.0, (sum, item) => sum + item.amount);
    final recentTransactions = _savingsHistory.take(5).length;

    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final childAspectRatio = isSmallScreen ? 1.5 : 1.3;

    return Column(
      children: [
        // First row - Main financial info
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            GestureDetector(
              onTap: () => _showSavingsDetails(),
              child: Stack(
                children: [
                  _buildStatCard(
                    'Current Savings',
                    _formatCurrency(savings),
                    _savingsColor,
                    Icons.account_balance_wallet,
                    subtitle: 'Available Balance',
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await _verifyBalanceCalculation();
                        await _fetchSavingsData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showActiveLoans(),
              child: _buildStatCard(
                'Active Loans',
                activeLoans.toString(),
                _activeLoansColor,
                Icons.credit_card,
                subtitle: 'Currently Active',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - Loan status
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            GestureDetector(
              onTap: () => _showPendingLoans(),
              child: _buildStatCard(
                'Pending Loans',
                pendingLoans.toString(),
                Colors.blue,
                Icons.pending_actions,
                subtitle: 'Awaiting Approval',
              ),
            ),
            GestureDetector(
              onTap: () => _showOverdueLoans(),
              child: _buildStatCard(
                'Overdue Loans',
                overdueLoans.toString(),
                _overdueColor,
                Icons.warning,
                subtitle: 'Requires Attention',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Third row - Transaction summary
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            GestureDetector(
              onTap: () => _showDepositHistory(),
              child: _buildStatCard(
                'Total Deposits',
                _formatCurrency(totalDeposits),
                Colors.green,
                Icons.trending_up,
                subtitle: 'All Time',
              ),
            ),
            GestureDetector(
              onTap: () => _showWithdrawalHistory(),
              child: _buildStatCard(
                'Total Withdrawals',
                _formatCurrency(totalWithdrawals),
                Colors.red,
                Icons.trending_down,
                subtitle: 'All Time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Fourth row - Additional info
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            GestureDetector(
              onTap: () => _showTotalDueDetails(),
              child: _buildStatCard(
                'Total Due',
                _formatCurrency(totalDue),
                _totalDueColor,
                Icons.payment,
                subtitle: 'Loan Repayments',
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: _buildStatCard(
                'Recent Transactions',
                recentTransactions.toString(),
                Colors.purple,
                Icons.receipt_long,
                subtitle: 'Last 5 Transactions',
              ),
            ),
          ],
        ),
      ],
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
                  _isBlindUser ? Colors.grey : Colors.orange,
                  _isBlindUser
                      ? () {
                          // This functionality has been removed as per instructions
                        }
                      : _initiateWithdrawal,
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
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isDisabled = color == Colors.grey;

    return Container(
      height: isSmallScreen ? 70 : 80,
      decoration: BoxDecoration(
        color: color.withOpacity(isDisabled ? 0.05 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDisabled ? 0.2 : 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isDisabled ? Colors.grey[400] : color,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isDisabled ? Colors.grey[400] : color,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDisabled && title == 'Withdraw') ...[
                  SizedBox(height: isSmallScreen ? 2 : 4),
                  Text(
                    'Not Available',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Loan Repayments Due',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: duePayments
                .map((loan) => _buildLoanDueCard(loan))
                .toList(),
          ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Loan ${loan.id.substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(nextPaymentAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          // Action row with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isOverdue
                      ? 'Overdue by ${daysRemaining.abs()} days'
                      : 'Due in $daysRemaining days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.orange,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
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
          mainAxisSize: MainAxisSize.min,
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
              textAlign: TextAlign.center,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: _primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
          // Transaction list with overflow protection
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _transactions
                .take(3)
                .map((txn) => _buildTransactionCard(txn))
                .toList(),
          ),
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
          // Icon container with fixed size
          Container(
            width: 36,
            height: 36,
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
          // Main content area with overflow protection
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  txn.type,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d').format(txn.date)} • ${txn.method}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount and status with overflow protection
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatCurrency(txn.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
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
        .where((loan) => loan.status == 'Active' || loan.status == 'Approved')
        .toList();
    showDialog(
      context: context,
      builder: (context) => _buildEnhancedLoanDetailsDialog(
        loans: activeLoans,
        title: 'Active Loans',
        icon: Icons.check_circle,
        color: Colors.green,
        showPaymentButton: true,
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
    // Calculate detailed breakdown
    final overdueLoans = _loans.where((loan) {
      if (loan.status != 'Active' && loan.status != 'Approved') return false;
      final nextPaymentDate = loan.payments.isEmpty
          ? loan.disbursementDate.add(const Duration(days: 30))
          : loan.payments.last.date.add(const Duration(days: 30));
      return nextPaymentDate.difference(DateTime.now()).inDays < 0;
    }).toList();

    final dueSoonLoans = _loans.where((loan) {
      if (loan.status != 'Active' && loan.status != 'Approved') return false;
      final nextPaymentDate = loan.payments.isEmpty
          ? loan.disbursementDate.add(const Duration(days: 30))
          : loan.payments.last.date.add(const Duration(days: 30));
      final daysUntilPayment = nextPaymentDate
          .difference(DateTime.now())
          .inDays;
      return daysUntilPayment <= 7 && daysUntilPayment >= 0;
    }).toList();

    final totalDue = _calculateTotalDue();

    showDialog(

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Loan Repayments Due',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: duePayments
                .map((loan) => _buildLoanDueCard(loan))
                .toList(),
          ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Loan ${loan.id.substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(nextPaymentAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
          // Action row with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isOverdue
                      ? 'Overdue by ${daysRemaining.abs()} days'
                      : 'Due in $daysRemaining days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.orange,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
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
          mainAxisSize: MainAxisSize.min,
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
              textAlign: TextAlign.center,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with overflow protection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: _primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recent Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
          // Transaction list with overflow protection
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _transactions
                .take(3)
                .map((txn) => _buildTransactionCard(txn))
                .toList(),
          ),
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
          // Icon container with fixed size
          Container(
            width: 36,
            height: 36,
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
          // Main content area with overflow protection
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  txn.type,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM d').format(txn.date)} • ${txn.method}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount and status with overflow protection
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatCurrency(txn.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
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
        .where((loan) => loan.status == 'Active' || loan.status == 'Approved')
        .toList();
    showDialog(
      context: context,
      builder: (context) => _buildEnhancedLoanDetailsDialog(
        loans: activeLoans,
        title: 'Active Loans',
        icon: Icons.check_circle,
        color: Colors.green,
        showPaymentButton: true,
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
    // Calculate detailed breakdown
    final overdueLoans = _loans.where((loan) {
      if (loan.status != 'Active' && loan.status != 'Approved') return false;
      final nextPaymentDate = loan.payments.isEmpty
          ? loan.disbursementDate.add(const Duration(days: 30))
          : loan.payments.last.date.add(const Duration(days: 30));
      return nextPaymentDate.difference(DateTime.now()).inDays < 0;
    }).toList();

    final dueSoonLoans = _loans.where((loan) {
      if (loan.status != 'Active' && loan.status != 'Approved') return false;
      final nextPaymentDate = loan.payments.isEmpty
          ? loan.disbursementDate.add(const Duration(days: 30))
          : loan.payments.last.date.add(const Duration(days: 30));
      final daysUntilPayment = nextPaymentDate
          .difference(DateTime.now())
          .inDays;
      return daysUntilPayment <= 7 && daysUntilPayment >= 0;
    }).toList();

    final totalDue = _calculateTotalDue();

    showDialog(
