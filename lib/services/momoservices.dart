import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:smartsacco/config/mtn_api_config.dart';

class MomoService {
  // Generate transaction ID
  static String generateTransactionId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Request to Pay (Collection) - For deposits
  Future<Map<String, dynamic>> requestPayment({
    required String phoneNumber,
    required double amount,
    required String externalId,
    required String payerMessage,
  }) async {
    try {
      debugPrint('Initiating MTN MoMo payment request...');
      debugPrint('Config: ${MTNApiConfig.configSummary}');

      final url = Uri.parse('${MTNApiConfig.collectionUrl}/v1_0/requesttopay');
      final referenceId = Uuid().v4();
      final headers = await _getHeaders(externalId, referenceId);

      final requestBody = {
        'amount': amount.toString(),
        'currency': MTNApiConfig.currency,
        'externalId': externalId,
        'payer': {'partyIdType': 'MSISDN', 'partyId': phoneNumber},
        'payerMessage': payerMessage,
        'payeeNote': 'SACCO Deposit',
      };

      debugPrint('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('MTN API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 202) {
        // Payment request accepted, check status
        final status = await _checkRequestToPayStatus(externalId);
        return {
          'success': true,
          'status': 'PENDING',
          'referenceId': referenceId,
          'externalId': externalId,
          'message': 'Payment request sent successfully',
          'statusDetails': status,
        };
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'status': 'FAILED',
          'message': errorBody['message'] ?? 'Payment request failed',
          'error': errorBody,
        };
      }
    } catch (e) {
      debugPrint('Error in requestPayment: $e');
      return {
        'success': false,
        'status': 'ERROR',
        'message': 'Network error: $e',
      };
    }
  }

  // Transfer (Disbursement) - For withdrawals
  Future<Map<String, dynamic>> transferMoney({
    required String phoneNumber,
    required double amount,
    required String externalId,
    required String payeeMessage,
  }) async {
    try {
      debugPrint('Initiating MTN MoMo transfer...');
      debugPrint('Config: ${MTNApiConfig.configSummary}');

      final url = Uri.parse('${MTNApiConfig.disbursementUrl}/v1_0/transfer');
      final referenceId = Uuid().v4();
      final headers = await _getHeaders(externalId, referenceId);

      final requestBody = {
        'amount': amount.toString(),
        'currency': MTNApiConfig.currency,
        'externalId': externalId,
        'payee': {'partyIdType': 'MSISDN', 'partyId': phoneNumber},
        'payerMessage': 'SACCO Withdrawal',
        'payeeNote': payeeMessage,
      };

      debugPrint('Transfer request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint(
        'MTN Transfer Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 202) {
        // Transfer request accepted, check status
        final status = await _checkTransferStatus(externalId);
        return {
          'success': true,
          'status': 'PENDING',
          'referenceId': referenceId,
          'externalId': externalId,
          'message': 'Transfer initiated successfully',
          'statusDetails': status,
        };
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'success': false,
          'status': 'FAILED',
          'message': errorBody['message'] ?? 'Transfer failed',
          'error': errorBody,
        };
      }
    } catch (e) {
      debugPrint('Error in transferMoney: $e');
      return {
        'success': false,
        'status': 'ERROR',
        'message': 'Network error: $e',
      };
    }
  }

  // Check Request to Pay Status (Collection)
  Future<Map<String, dynamic>> _checkRequestToPayStatus(
    String externalId,
  ) async {
    try {
      final url = Uri.parse(
        '${MTNApiConfig.collectionUrl}/v1_0/requesttopay/$externalId',
      );
      final headers = await _getBasicHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'financialTransactionId': data['financialTransactionId'],
          'reason': data['reason'],
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to check payment status',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error checking request to pay status: $e');
      return {'success': false, 'message': 'Error checking status: $e'};
    }
  }

  // Check Transfer Status (Disbursement)
  Future<Map<String, dynamic>> _checkTransferStatus(String externalId) async {
    try {
      final url = Uri.parse(
        '${MTNApiConfig.disbursementUrl}/v1_0/transfer/$externalId',
      );
      final headers = await _getBasicHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'financialTransactionId': data['financialTransactionId'],
          'reason': data['reason'],
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to check transfer status',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error checking transfer status: $e');
      return {'success': false, 'message': 'Error checking status: $e'};
    }
  }

  // Get account balance
  Future<Map<String, dynamic>> getAccountBalance() async {
    try {
      final url = Uri.parse('${MTNApiConfig.collectionUrl}/v1_0/account/balance');
      final headers = await _getBasicHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'balance': data['availableBalance'],
          'currency': data['currency'],
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get account balance',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error getting account balance: $e');
      return {'success': false, 'message': 'Error getting balance: $e'};
    }
  }

  // Get account holder info
  Future<Map<String, dynamic>> getAccountHolderInfo(String phoneNumber) async {
    try {
      final url = Uri.parse(
        '${MTNApiConfig.collectionUrl}/v1_0/accountholder/msisdn/$phoneNumber/basicuserinfo',
      );
      final headers = await _getBasicHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'name': data['given_name'],
          'surname': data['surname'],
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get account holder info',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('Error getting account holder info: $e');
      return {'success': false, 'message': 'Error getting info: $e'};
    }
  }

  // Get headers for API requests
  Future<Map<String, String>> _getHeaders(String externalId, String referenceId) async {
    // First get access token
    final token = await _getAccessToken();
    
    return {
      'X-Reference-Id': referenceId,
      'X-Target-Environment': MTNApiConfig.targetEnvironment,
      'Ocp-Apim-Subscription-Key': MTNApiConfig.subscriptionKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'X-External-Id': externalId,
    };
  }

  // Get basic headers (without access token)
  Future<Map<String, String>> _getBasicHeaders() async {
    return {
      'X-Target-Environment': MTNApiConfig.targetEnvironment,
      'Ocp-Apim-Subscription-Key': MTNApiConfig.subscriptionKey,
      'Content-Type': 'application/json',
    };
  }

  // Get access token
  Future<String> _getAccessToken() async {
    try {
      final url = Uri.parse('${MTNApiConfig.baseUrl}/collection/token/');
      final headers = {
        'X-Reference-Id': Uuid().v4(),
        'X-Target-Environment': MTNApiConfig.targetEnvironment,
        'Ocp-Apim-Subscription-Key': MTNApiConfig.subscriptionKey,
        'Authorization': 'Basic ${_generateBasicAuth()}',
      };

      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        throw Exception('Failed to get access token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting access token: $e');
      rethrow;
    }
  }

  // Generate Basic Auth header
  String _generateBasicAuth() {
    final credentials = '${MTNApiConfig.apiUser}:${MTNApiConfig.apiKey}';
    final bytes = utf8.encode(credentials);
    return base64.encode(bytes);
  }

  // Validate phone number
  bool isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // MTN Uganda numbers start with 2567, 2568, 2569, 2560
    if (cleanNumber.startsWith('256')) {
      return cleanNumber.length == 12 && 
             ['2567', '2568', '2569', '2560'].contains(cleanNumber.substring(0, 4));
    }
    
    // Local format starting with 0
    if (cleanNumber.startsWith('0')) {
      return cleanNumber.length == 10 && 
             ['07', '08', '09', '00'].contains(cleanNumber.substring(0, 2));
    }
    
    return false;
  }

  // Format phone number for MTN API
  String formatPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it starts with 0, replace with 256
    if (cleanNumber.startsWith('0')) {
      return '256${cleanNumber.substring(1)}';
    }
    
    // If it's already in international format, return as is
    if (cleanNumber.startsWith('256')) {
      return cleanNumber;
    }
    
    // If it's a 9-digit number, add 256 prefix
    if (cleanNumber.length == 9) {
      return '256$cleanNumber';
    }
    
    return cleanNumber;
  }

  // Check transaction status with retry
  Future<Map<String, dynamic>> checkTransactionStatus(
    String externalId, {
    int maxRetries = 10,
    Duration delay = const Duration(seconds: 5),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final status = await _checkRequestToPayStatus(externalId);
        
        if (status['success']) {
          final transactionStatus = status['status'];
          
          // If transaction is completed or failed, return immediately
          if (['SUCCESSFUL', 'FAILED', 'REJECTED', 'CANCELLED'].contains(transactionStatus)) {
            return status;
          }
        }
        
        // Wait before next check
        if (i < maxRetries - 1) {
          await Future.delayed(delay);
        }
      } catch (e) {
        debugPrint('Error checking transaction status (attempt ${i + 1}): $e');
        if (i == maxRetries - 1) {
          return {'success': false, 'message': 'Failed to check status after $maxRetries attempts'};
        }
      }
    }
    
    return {'success': false, 'message': 'Transaction status check timed out'};
  }
}
