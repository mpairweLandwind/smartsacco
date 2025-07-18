import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:smartsacco/services/biometric_auth_service.dart';  // Removed for voice-first approach
import 'package:smartsacco/services/analytics_service.dart';
import 'package:smartsacco/config/mtn_api_config.dart';
import 'package:smartsacco/services/momoservices.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _flutterTts = FlutterTts();
  // final BiometricAuthService _biometricAuth = BiometricAuthService();  // Removed for voice-first approach
  final AnalyticsService _analytics = AnalyticsService();

  // bool _biometricEnabled = false;  // Removed for voice-first approach
  bool _voiceEnabled = true;
  bool _analyticsEnabled = true;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _speakWelcome();
  }

  Future<void> _initializeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _analyticsEnabled = prefs.getBool('analytics_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _pitch = prefs.getDouble('pitch') ?? 1.0;
      _volume = prefs.getDouble('volume') ?? 1.0;
    });

    // Check biometric status - removed for voice-first approach
    // final biometricStatus = await _biometricAuth.getAuthStatus();
    // setState(() {
    //   _biometricEnabled = biometricStatus['biometricEnabled'] ?? false;
    // });
  }

  Future<void> _speakWelcome() async {
    if (_voiceEnabled) {
      await _flutterTts.speak(
        'Settings page. You can configure voice, security, and analytics settings.',
      );
    }
  }

  void _toggleVoice(bool value) {
    setState(() {
      _voiceEnabled = value;
    });
    _updateVoiceSettings(value);
  }

  // Future<void> _toggleBiometric() async {  // Removed for voice-first approach
  //   if (_biometricEnabled) {
  //     final disabled = await _biometricAuth.disableBiometric();
  //     if (disabled) {
  //       setState(() {
  //         _biometricEnabled = false;
  //       });
  //       if (_voiceEnabled) {
  //         await _flutterTts.speak('Biometric authentication disabled');
  //       }
  //     }
  //   } else {
  //     final enabled = await _biometricAuth.enableBiometric();
  //     if (enabled) {
  //         setState(() {
  //           _biometricEnabled = true;
  //         });
  //         if (_voiceEnabled) {
  //           await _flutterTts.speak('Biometric authentication enabled');
  //         }
  //       }
  //     }

  //     // Track analytics
  //     await _analytics.trackFeatureUsage(
  //       featureName: 'biometric_toggle',
  //       parameters: {'enabled': _biometricEnabled},
  //     );
  //   }

  void _toggleAnalytics(bool value) {
    setState(() {
      _analyticsEnabled = value;
    });
    _updateAnalyticsSettings(value);
  }

  Future<void> _updateVoiceSettings(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_enabled', value);
    if (value) {
      await _flutterTts.speak('Voice authentication enabled');
    } else {
      await _flutterTts.speak('Voice authentication disabled');
    }
  }

  Future<void> _updateAnalyticsSettings(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_enabled', value);
    if (_voiceEnabled) {
      await _flutterTts.speak(
        value ? 'Analytics enabled' : 'Analytics disabled',
      );
    }
    await _analytics.trackFeatureUsage(
      featureName: 'analytics_toggle',
      parameters: {'enabled': value},
    );
  }

  Future<void> _updateNotificationSettings(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (_voiceEnabled) {
      await _flutterTts.speak(
        value ? 'Notifications enabled' : 'Notifications disabled',
      );
    }
    await _analytics.trackFeatureUsage(
      featureName: 'notifications_toggle',
      parameters: {'enabled': value},
    );
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    _updateNotificationSettings(value);
  }

  Future<void> _changeLanguage(String language) async {
    setState(() {
      _selectedLanguage = language;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', language);

    if (_voiceEnabled) {
      await _flutterTts.speak('Language changed to $language');
    }

    // Track analytics
    await _analytics.trackFeatureUsage(
      featureName: 'language_change',
      parameters: {'language': language},
    );
  }

  Future<void> _updateSpeechRate(double rate) async {
    setState(() {
      _speechRate = rate;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speech_rate', rate);

    if (_voiceEnabled) {
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.speak('Speech rate updated');
    }
  }

  Future<void> _updatePitch(double pitch) async {
    setState(() {
      _pitch = pitch;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pitch', pitch);

    if (_voiceEnabled) {
      await _flutterTts.setPitch(pitch);
      await _flutterTts.speak('Pitch updated');
    }
  }

  Future<void> _updateVolume(double volume) async {
    setState(() {
      _volume = volume;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', volume);

    if (_voiceEnabled) {
      await _flutterTts.setVolume(volume);
      await _flutterTts.speak('Volume updated');
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (_voiceEnabled) {
        await _flutterTts.speak('Microphone permission granted');
      }
    } else {
      if (_voiceEnabled) {
        await _flutterTts.speak('Microphone permission denied');
      }
    }
  }

  Future<void> _exportData() async {
    if (_voiceEnabled) {
      await _flutterTts.speak('Exporting data. Please wait.');
    }

    // Here you would implement data export functionality
    // For now, we'll just track the event
    await _analytics.trackFeatureUsage(featureName: 'data_export');

    if (_voiceEnabled) {
      await _flutterTts.speak('Data export completed');
    }
  }

  Future<void> _clearData() async {
    if (_voiceEnabled) {
      await _flutterTts.speak('Are you sure you want to clear all data?');
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
          'This will clear all app data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // await _biometricAuth.clearAuthData();  // Removed for voice-first approach

      if (_voiceEnabled) {
        await _flutterTts.speak('All data cleared');
      }

      // Track analytics
      await _analytics.trackFeatureUsage(featureName: 'data_clear');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    if (_voiceEnabled) {
      await _flutterTts.speak('Logging out');
    }

    await FirebaseAuth.instance.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice Settings Section
            _buildSectionHeader('Voice Settings'),
            _buildSwitchTile(
              title: 'Voice Assistance',
              subtitle: 'Enable voice commands and feedback',
              value: _voiceEnabled,
              onChanged: _toggleVoice,
            ),
            if (_voiceEnabled) ...[
              _buildSliderTile(
                title: 'Speech Rate',
                subtitle: 'Adjust how fast the voice speaks',
                value: _speechRate,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                onChanged: _updateSpeechRate,
              ),
              _buildSliderTile(
                title: 'Pitch',
                subtitle: 'Adjust the voice pitch',
                value: _pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: _updatePitch,
              ),
              _buildSliderTile(
                title: 'Volume',
                subtitle: 'Adjust the voice volume',
                value: _volume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: _updateVolume,
              ),
              _buildDropdownTile(
                title: 'Language',
                subtitle: 'Select your preferred language',
                value: _selectedLanguage,
                items: ['English', 'Luganda', 'Swahili'],
                onChanged: _changeLanguage,
              ),
            ],

            const SizedBox(height: 24),

            // Security Settings Section - Voice-First Approach
            _buildSectionHeader('Voice Security Settings'),
            _buildSwitchTile(
              title: 'Voice Authentication',
              subtitle: 'Use voice commands for secure access',
              value: _voiceEnabled,
              onChanged: (value) {
                setState(() {
                  _voiceEnabled = value;
                });
                _updateVoiceSettings(value);
              },
            ),
            _buildButtonTile(
              title: 'Request Permissions',
              subtitle: 'Grant microphone and other permissions',
              onTap: _requestPermissions,
            ),

            const SizedBox(height: 24),

            // Analytics Settings Section
            _buildSectionHeader('Analytics & Privacy'),
            _buildSwitchTile(
              title: 'Analytics',
              subtitle: 'Help improve the app by sharing usage data',
              value: _analyticsEnabled,
              onChanged: _toggleAnalytics,
            ),
            _buildSwitchTile(
              title: 'Notifications',
              subtitle: 'Receive push notifications',
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader('Data Management'),
            _buildButtonTile(
              title: 'Export Data',
              subtitle: 'Download your data as a file',
              onTap: _exportData,
            ),
            _buildButtonTile(
              title: 'Clear Data',
              subtitle: 'Delete all app data',
              onTap: _clearData,
              isDestructive: true,
            ),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader('Account'),
            _buildButtonTile(
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: _logout,
              isDestructive: true,
            ),

            const SizedBox(height: 24),

            // MTN API Configuration Section
            _buildSectionHeader('MTN API Configuration'),
            _buildMTNApiSection(),

            const SizedBox(height: 24),

            // App Information Section
            _buildSectionHeader('App Information'),
            _buildInfoTile(title: 'Version', subtitle: '1.0.0'),
            _buildInfoTile(title: 'Build Number', subtitle: '1'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: const Icon(Icons.settings),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
            Text('${(value * 100).round()}%'),
          ],
        ),
        leading: const Icon(Icons.volume_up),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: DropdownButton<String>(
          value: value,
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
        leading: const Icon(Icons.language),
      ),
    );
  }

  Widget _buildButtonTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(color: isDestructive ? Colors.red : null),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios),
        leading: Icon(
          isDestructive ? Icons.delete : Icons.settings,
          color: isDestructive ? Colors.red : null,
        ),
      ),
    );
  }

  Widget _buildInfoTile({required String title, required String subtitle}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        leading: const Icon(Icons.info),
      ),
    );
  }

  Widget _buildMTNApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'MTN MoMo API Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Configuration Status
            _buildConfigStatus(),
            const SizedBox(height: 16),

            // Configuration Details
            _buildConfigDetails(),
            const SizedBox(height: 16),

            // Test Connection Button
            ElevatedButton.icon(
              onPressed: _testMTNConnection,
              icon: const Icon(Icons.wifi),
              label: const Text('Test MTN API Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigStatus() {
    final config = MTNApiConfig.configSummary;
    final isValid = config['isValid'] as bool;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid ? 'Configuration Valid' : 'Configuration Invalid',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                Text(
                  isValid
                      ? 'MTN API is properly configured'
                      : 'Please check your API credentials',
                  style: TextStyle(
                    color: isValid ? Colors.green[600] : Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigDetails() {
    final config = MTNApiConfig.configSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuration Details',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildConfigRow('Environment', config['environment']),
        _buildConfigRow('Base URL', config['baseUrl']),
        _buildConfigRow('Currency', config['currency']),
        _buildConfigRow('Callback URL', config['callbackUrl']),
        _buildConfigRow(
          'Subscription Key',
          _maskApiKey(MTNApiConfig.subscriptionKey),
        ),
        _buildConfigRow('API User', _maskApiKey(MTNApiConfig.apiUser)),
        _buildConfigRow('API Key', _maskApiKey(MTNApiConfig.apiKey)),
      ],
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return '*' * key.length;
    return '${key.substring(0, 4)}${'*' * (key.length - 8)}${key.substring(key.length - 4)}';
  }

  Future<void> _testMTNConnection() async {
    setState(() {
      // _isTestingConnection = true; // Removed unused field
    });

    try {
      final momoService = MomoService();

      // Test getting account balance
      final balanceResult = await momoService.getAccountBalance();

      if (!mounted) return;

      if (balanceResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ MTN API connection successful! Balance: ${balanceResult['balance']} ${balanceResult['currency']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ MTN API connection failed: ${balanceResult['message']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error testing MTN API connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        // setState(() { // Removed unused field
        //   _isTestingConnection = false;
        // });
      }
    }
  }
}
