// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:file_picker/file_picker.dart';

// class LoanApplicationScreen extends StatefulWidget {
//   final String memberId;
//   final double memberSavings;
//   final Function(Map<String, dynamic>) onSubmit;

//   const LoanApplicationScreen({
//     super.key,
//     required this.memberId,
//     required this.memberSavings,
//     required this.onSubmit,
//   });

//   @override
//   State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
// }

// class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _amountController = TextEditingController();
//   final _purposeController = TextEditingController();

//   String _loanType = 'Personal';
//   int _repaymentPeriod = 6;
//   List<PlatformFile> _documents = [];
//   bool _isSubmitting = false;
//   final double _interestRate = 12.0;

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _purposeController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final maxLoanAmount = widget.memberSavings * 3;
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Loan Application'),
//         backgroundColor: Colors.blue,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'New Loan Application',
//                 style: theme.textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               Card(
//                 color: Colors.blue[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.verified_user, color: Colors.blue[700]),
//                           const SizedBox(width: 10),
//                           Text(
//                             'Loan Eligibility',
//                             style: theme.textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         'Based on your savings of ${_formatCurrency(widget.memberSavings)}, '
//                         'you qualify for a maximum loan of ${_formatCurrency(maxLoanAmount)}',
//                         style: theme.textTheme.bodyMedium,
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         'Interest Rate: $_interestRate% per annum',
//                         style: theme.textTheme.bodyMedium?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),

//               TextFormField(
//                 controller: _amountController,
//                 decoration: InputDecoration(
//                   labelText: 'Loan Amount (UGX)',
//                   prefixText: 'UGX ',
//                   hintText: 'Enter amount between 50,000 and ${_formatCurrency(maxLoanAmount)}',
//                   suffixIcon: IconButton(
//                     icon: const Icon(Icons.info),
//                     onPressed: () => _showMaxLoanInfo(maxLoanAmount),
//                   ),
//                 ),
//                 keyboardType: TextInputType.number,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) return 'Please enter amount';
//                   final amount = double.tryParse(value) ?? 0;
//                   if (amount < 50000) return 'Minimum loan is UGX 50,000';
//                   if (amount > maxLoanAmount) return 'Amount exceeds your limit';
//                   return null;
//                 },
//                 onChanged: (value) => setState(() {}),
//               ),
//               const SizedBox(height: 20),

//               DropdownButtonFormField<String>(
//                 value: _loanType,
//                 items: const [
//                   DropdownMenuItem(value: 'Personal', child: Text('Personal Loan')),
//                   DropdownMenuItem(value: 'Business', child: Text('Business Loan')),
//                   DropdownMenuItem(value: 'Emergency', child: Text('Emergency Loan')),
//                   DropdownMenuItem(value: 'Education', child: Text('Education Loan')),
//                 ],
//                 onChanged: (value) => setState(() => _loanType = value!),
//                 decoration: const InputDecoration(
//                   labelText: 'Loan Type',
//                 ),
//               ),
//               const SizedBox(height: 20),

//               TextFormField(
//                 controller: _purposeController,
//                 decoration: const InputDecoration(
//                   labelText: 'Purpose of Loan',
//                   hintText: 'Briefly describe what you need the loan for',
//                 ),
//                 maxLines: 2,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) return 'Please enter purpose';
//                   if (value.length < 10) return 'Please provide more details';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 20),

//               DropdownButtonFormField<int>(
//                 value: _repaymentPeriod,
//                 items: [3, 6, 9, 12, 18, 24].map((months) {
//                   return DropdownMenuItem(
//                     value: months,
//                     child: Text('$months months'),
//                   );
//                 }).toList(),
//                 onChanged: (value) => setState(() => _repaymentPeriod = value!),
//                 decoration: const InputDecoration(
//                   labelText: 'Repayment Period',
//                 ),
//               ),
//               const SizedBox(height: 30),

//               _buildRepaymentPreview(),
//               const SizedBox(height: 30),

//               Text(
//                 'Supporting Documents',
//                 style: theme.textTheme.titleMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 'Upload any supporting documents (ID, payslips, business docs)',
//                 style: theme.textTheme.bodySmall,
//               ),
//               const SizedBox(height: 10),
//               OutlinedButton(
//                 onPressed: _pickDocuments,
//                 child: const Text('Select Files'),
//               ),
//               if (_documents.isNotEmpty) ...[
//                 const SizedBox(height: 10),
//                 Wrap(
//                   spacing: 8,
//                   children: _documents.map((file) => Chip(
//                     label: Text(file.name),
//                     deleteIcon: const Icon(Icons.close, size: 18),
//                     onDeleted: () => setState(() => _documents.remove(file)),
//                   )).toList(),
//                 ),
//               ],
//               const SizedBox(height: 30),

//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   onPressed: _isSubmitting ? null : _submitApplication,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   child: _isSubmitting
//                       ? const CircularProgressIndicator()
//                       : Text(
//                           'SUBMIT APPLICATION',
//                           style: theme.textTheme.labelLarge?.copyWith(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRepaymentPreview() {
//     final amount = double.tryParse(_amountController.text) ?? 0;
//     final interest = (amount * _interestRate / 100) * (_repaymentPeriod / 12);
//     final totalRepayment = amount + interest;
//     final monthlyPayment = _repaymentPeriod > 0
//         ? totalRepayment / _repaymentPeriod
//         : 0;

//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'REPAYMENT ESTIMATE',
//               style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.grey[600],
//                   ),
//             ),
//             const SizedBox(height: 15),
//             _buildRepaymentRow('Loan Amount:', _formatCurrency(amount)),
//             _buildRepaymentRow('Interest Rate:', '$_interestRate% p.a.'),
//             _buildRepaymentRow('Interest Amount:', _formatCurrency(interest)),
//             const Divider(height: 20),
//             _buildRepaymentRow('Total Repayable:', _formatCurrency(totalRepayment)),
//             const SizedBox(height: 10),
//             _buildRepaymentRow(
//               'Monthly Installment:',
//               _formatCurrency(monthlyPayment.toDouble()),
//               bold: true,
//               color: Colors.green[700],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRepaymentRow(String label, String value, {bool bold = false, Color? color}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   fontWeight: bold ? FontWeight.bold : FontWeight.normal,
//                 ),
//           ),
//           Text(
//             value,
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   fontWeight: bold ? FontWeight.bold : FontWeight.normal,
//                   color: color,
//                 ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _pickDocuments() async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         allowMultiple: true,
//         type: FileType.custom,
//         allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
//       );

//       if (result != null && mounted) {
//         setState(() => _documents = result.files);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error selecting files: $e')),
//         );
//       }
//     }
//   }

//   void _showMaxLoanInfo(double maxAmount) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Loan Limit Information'),
//         content: Text(
//           'Your maximum loan amount is calculated as 3 times your current savings balance.\n\n'
//           'Current Savings: ${_formatCurrency(widget.memberSavings)}\n'
//           'Maximum Loan: ${_formatCurrency(maxAmount)}',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _submitApplication() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isSubmitting = true);

//     try {
//       final application = {
//         'memberId': widget.memberId,
//         'amount': double.parse(_amountController.text),
//         'type': _loanType,
//         'purpose': _purposeController.text,
//         'repaymentPeriod': _repaymentPeriod,
//         'documents': _documents.map((f) => f.name).toList(),
//         'applicationDate': DateTime.now().toIso8601String(),
//       };

//       widget.onSubmit(application);

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Application submitted successfully!')),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isSubmitting = false);
//       }
//     }
//   }

//   String _formatCurrency(double amount) {
//     return NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(amount);
//   }
// }

// loanapplication.dart (updated)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

class LoanApplicationScreen extends StatefulWidget {
  final String memberId;
  final double memberSavings;
  final Function(Map<String, dynamic>) onSubmit;

  const LoanApplicationScreen({
    super.key,
    required this.memberId,
    required this.memberSavings,
    required this.onSubmit,
  });

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  FlutterTts flutterTts = FlutterTts();

  String _loanType = 'Personal';
  int _repaymentPeriod = 6;
  List<PlatformFile> _documents = [];
  bool _isSubmitting = false;
  final double _interestRate = 12.0;
  bool _awaitingVoiceConfirmation = false;

  // --- VOICE LOGIC ENHANCEMENT START ---
  Future<void> _speak(String message) async {
    await flutterTts.speak(message);
  }

  Future<void> _voiceConfirmSubmission() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final interest = (amount * _interestRate / 100) * (_repaymentPeriod / 12);
    final totalRepayment = amount + interest;
    final monthlyPayment = _repaymentPeriod > 0
        ? totalRepayment / _repaymentPeriod
        : 0;
    String message =
        "You are about to submit a loan application for ${_formatCurrency(amount.toDouble())} Uganda Shillings. "
        "Loan type: $_loanType. Purpose: ${_purposeController.text}. Repayment period: $_repaymentPeriod months. "
        "Total repayable: ${_formatCurrency(totalRepayment.toDouble())}. Monthly installment: ${_formatCurrency(monthlyPayment.toDouble())}. "
        "Say 'yes' to confirm and submit, or 'no' to cancel.";
    setState(() => _awaitingVoiceConfirmation = true);
    _speak(message);
    Future.delayed(const Duration(seconds: 2), _listenForVoiceConfirmation);
  }

  void _listenForVoiceConfirmation() async {
    // This is a placeholder for actual STT integration
    // In a real implementation, you would use speech_to_text to listen and process the result
    // For now, just show a dialog for manual confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Confirmation'),
        content: const Text(
          "Say 'yes' to confirm and submit, or 'no' to cancel.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitApplication(voiceConfirmed: true);
            },
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _awaitingVoiceConfirmation = false);
              _speak(
                "Loan application cancelled. You can review and try again.",
              );
            },
            child: const Text('No'),
          ),
        ],
      ),
    );
  }
  // --- VOICE LOGIC ENHANCEMENT END ---

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxLoanAmount = widget.memberSavings * 3;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Application'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Loan Application',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Eligibility Card
              _buildEligibilityCard(maxLoanAmount, theme),
              const SizedBox(height: 30),

              // Loan Amount Field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Loan Amount (UGX)',
                  prefixText: 'UGX ',
                  hintText:
                      'Enter amount between 50,000 and ${_formatCurrency(maxLoanAmount)}',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () => _showMaxLoanInfo(maxLoanAmount),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value) ?? 0;
                  if (amount < 50000) {
                    return 'Minimum loan is UGX 50,000';
                  }
                  if (amount > maxLoanAmount) {
                    return 'Amount exceeds your limit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Loan Type Dropdown
              DropdownButtonFormField<String>(
                value: _loanType,
                items: const [
                  DropdownMenuItem(
                    value: 'Personal',
                    child: Text('Personal Loan'),
                  ),
                  DropdownMenuItem(
                    value: 'Business',
                    child: Text('Business Loan'),
                  ),
                  DropdownMenuItem(
                    value: 'Emergency',
                    child: Text('Emergency Loan'),
                  ),
                  DropdownMenuItem(
                    value: 'Education',
                    child: Text('Education Loan'),
                  ),
                ],
                onChanged: (value) => setState(() => _loanType = value!),
                decoration: const InputDecoration(labelText: 'Loan Type'),
              ),
              const SizedBox(height: 20),

              // Purpose Field
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Loan',
                  hintText: 'Briefly describe what you need the loan for',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purpose';
                  }
                  if (value.length < 10) {
                    return 'Please provide more details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Repayment Period
              DropdownButtonFormField<int>(
                value: _repaymentPeriod,
                items: [3, 6, 9, 12, 18, 24].map((months) {
                  return DropdownMenuItem(
                    value: months,
                    child: Text('$months months'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _repaymentPeriod = value!),
                decoration: const InputDecoration(
                  labelText: 'Repayment Period',
                ),
              ),
              const SizedBox(height: 30),

              // Repayment Preview
              _buildRepaymentPreview(),
              const SizedBox(height: 30),

              // Documents Section
              _buildDocumentsSection(theme),
              const SizedBox(height: 30),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEligibilityCard(double maxLoanAmount, ThemeData theme) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.blue[700]),
                const SizedBox(width: 10),
                Text(
                  'Loan Eligibility',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Based on your savings of ${_formatCurrency(widget.memberSavings)}, '
              'you qualify for a maximum loan of ${_formatCurrency(maxLoanAmount)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Interest Rate: $_interestRate% per annum',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepaymentPreview() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final interest = (amount * _interestRate / 100) * (_repaymentPeriod / 12);
    final totalRepayment = amount + interest;
    final monthlyPayment = _repaymentPeriod > 0
        ? totalRepayment / _repaymentPeriod
        : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REPAYMENT ESTIMATE',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 15),
            _buildRepaymentRow(
              'Loan Amount:',
              _formatCurrency(amount.toDouble()),
            ),
            _buildRepaymentRow('Interest Rate:', '$_interestRate% p.a.'),
            _buildRepaymentRow(
              'Interest Amount:',
              _formatCurrency(interest.toDouble()),
            ),
            const Divider(height: 20),
            _buildRepaymentRow(
              'Total Repayable:',
              _formatCurrency(totalRepayment.toDouble()),
            ),
            const SizedBox(height: 10),
            _buildRepaymentRow(
              'Monthly Installment:',
              _formatCurrency(monthlyPayment.toDouble()),
              bold: true,
              color: Colors.green[700],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supporting Documents',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Upload any supporting documents (ID, payslips, business docs)',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _pickDocuments,
          child: const Text('Select Files'),
        ),
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _documents
                .map(
                  (file) => Chip(
                    label: Text(file.name),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _documents.remove(file)),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting || _awaitingVoiceConfirmation
            ? null
            : () async {
                if (_formKey.currentState!.validate()) {
                  await _voiceConfirmSubmission();
                }
              },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator()
            : Text(
                'SUBMIT APPLICATION',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && mounted) {
        setState(() => _documents = result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting files: $e')));
      }
    }
  }

  void _showMaxLoanInfo(double maxAmount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loan Limit Information'),
        content: Text(
          'Your maximum loan amount is calculated as 3 times your current savings balance.\n\n'
          'Current Savings: ${_formatCurrency(widget.memberSavings)}\n'
          'Maximum Loan: ${_formatCurrency(maxAmount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitApplication({bool voiceConfirmed = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_awaitingVoiceConfirmation && !voiceConfirmed) {
      await _voiceConfirmSubmission();
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final amount = double.parse(_amountController.text);
      final interest = (amount * _interestRate / 100) * (_repaymentPeriod / 12);
      final totalRepayment = amount + interest;
      final monthlyPayment = _repaymentPeriod > 0
          ? totalRepayment / _repaymentPeriod
          : 0;
      final application = {
        'memberId': widget.memberId,
        'amount': amount,
        'type': _loanType,
        'purpose': _purposeController.text,
        'repaymentPeriod': _repaymentPeriod,
        'interestRate': _interestRate,
        'totalRepayment': totalRepayment,
        'monthlyPayment': monthlyPayment,
        'status': 'Pending',
        'applicationDate': DateTime.now(),
        'documents': _documents.map((f) => f.name).toList(),
      };
      widget.onSubmit(application);
      if (mounted) {
        _speak(
          "Loan application submitted successfully! You will be notified once it is reviewed.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _speak(
          "There was an error submitting your application. Please try again.",
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _awaitingVoiceConfirmation = false;
        });
      }
    }
  }

  Widget _buildRepaymentRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
    ).format(amount);
  }
}
