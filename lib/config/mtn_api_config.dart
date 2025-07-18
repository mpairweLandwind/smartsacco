import 'dart:math';
import 'dart:convert';

class MTNApiConfig {
  // MTN API Sandbox Configuration
  static const String subscriptionKey = '45c1c5440807495b80c9db300112c631';
  static const String apiUser = '3c3b115f-6d90-4a1a-9d7a-2c1a0422fdfc';
  static const String apiKey = 'b7295fe722284bfcb65ecd97db695533';
  static const bool isSandbox = true;
  static const String callbackUrl =
      'https://2e76-41-210-141-242.ngrok-free.app/momo-callback';

  // Base URLs
  static const String sandboxBaseUrl = 'https://sandbox.momodeveloper.mtn.com';
  static const String productionBaseUrl = 'https://proxy.momoapi.mtn.com';

  // Collection URLs
  static const String sandboxCollectionUrl =
      'https://sandbox.momodeveloper.mtn.com/collection';
  static const String productionCollectionUrl =
      'https://proxy.momoapi.mtn.com/collection';

  // Disbursement URLs
  static const String sandboxDisbursementUrl =
      'https://sandbox.momodeveloper.mtn.com/disbursement';
  static const String productionDisbursementUrl =
      'https://proxy.momoapi.mtn.com/disbursement';

  // Remittance URLs
  static const String sandboxRemittanceUrl =
      'https://sandbox.momodeveloper.mtn.com/remittance';
  static const String productionRemittanceUrl =
      'https://proxy.momoapi.mtn.com/remittance';

  // Get current base URL based on environment
  static String get baseUrl => isSandbox ? sandboxBaseUrl : productionBaseUrl;

  // Get current collection URL
  static String get collectionUrl =>
      isSandbox ? sandboxCollectionUrl : productionCollectionUrl;

  // Get current disbursement URL
  static String get disbursementUrl =>
      isSandbox ? sandboxDisbursementUrl : productionDisbursementUrl;

  // Get current remittance URL
  static String get remittanceUrl =>
      isSandbox ? sandboxRemittanceUrl : productionRemittanceUrl;

  // Target environment
  static String get targetEnvironment => isSandbox ? 'sandbox' : 'live';

  // Currency (MTN sandbox uses EUR, production uses UGX)
  static String get currency => isSandbox ? 'EUR' : 'UGX';

  // API Headers
  static Map<String, String> get basicHeaders => {
    'X-Reference-Id': _generateReferenceId(),
    'X-Target-Environment': targetEnvironment,
    'Ocp-Apim-Subscription-Key': subscriptionKey,
    'Content-Type': 'application/json',
  };

  static Map<String, String> get authHeaders => {
    'X-Reference-Id': _generateReferenceId(),
    'X-Target-Environment': targetEnvironment,
    'Ocp-Apim-Subscription-Key': subscriptionKey,
    'Authorization': 'Basic ${_generateBasicAuth()}',
    'Content-Type': 'application/json',
  };

  // Generate reference ID
  static String _generateReferenceId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Generate Basic Auth header
  static String _generateBasicAuth() {
    final credentials = '$apiUser:$apiKey';
    final bytes = utf8.encode(credentials);
    return base64.encode(bytes);
  }

  // Validate configuration
  static bool get isValid {
    return subscriptionKey.isNotEmpty &&
        apiUser.isNotEmpty &&
        apiKey.isNotEmpty &&
        callbackUrl.isNotEmpty;
  }

  // Get configuration summary
  static Map<String, dynamic> get configSummary => {
    'environment': isSandbox ? 'Sandbox' : 'Production',
    'baseUrl': baseUrl,
    'collectionUrl': collectionUrl,
    'disbursementUrl': disbursementUrl,
    'remittanceUrl': remittanceUrl,
    'currency': currency,
    'callbackUrl': callbackUrl,
    'isValid': isValid,
  };
}
