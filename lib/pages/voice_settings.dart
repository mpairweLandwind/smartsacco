import 'package:flutter/material.dart';
import 'package:smartsacco/services/enhanced_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  _VoiceSettingsPageState createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  final EnhancedVoiceService _voiceService = EnhancedVoiceService();

  VoiceConfig? _selectedConfig;
  List<VoiceConfig> _availableConfigs = [];
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadVoiceConfigurations();
  }

  Future<void> _loadVoiceConfigurations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize the voice service if not already done
      await _voiceService.initialize();

      // Get available configurations
      _availableConfigs = _voiceService.getAvailableConfigs();

      // Load saved configuration
      await _loadSavedConfiguration();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load voice configurations: $e');
    }
  }

  Future<void> _loadSavedConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedConfigJson = prefs.getString('selected_voice_config');

      if (savedConfigJson != null) {
        final savedConfig = VoiceConfig.fromMap(
          Map<String, dynamic>.from(
            Map.fromEntries(
              savedConfigJson.split(',').map((entry) {
                final parts = entry.split(':');
                return MapEntry(parts[0], parts[1]);
              }),
            ),
          ),
        );

        // Find the matching config from available configs
        final matchingConfig = _availableConfigs.firstWhere(
          (config) => config.name == savedConfig.name,
          orElse: () => _availableConfigs.first,
        );

        setState(() {
          _selectedConfig = matchingConfig;
        });

        // Apply the configuration
        await _voiceService.changeVoiceConfig(matchingConfig);
      } else {
        // Use default configuration
        setState(() {
          _selectedConfig = _availableConfigs.first;
        });
      }
    } catch (e) {
      // Use default configuration if loading fails
      setState(() {
        _selectedConfig = _availableConfigs.first;
      });
    }
  }

  Future<void> _saveConfiguration(VoiceConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configString = config
          .toMap()
          .entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');
      await prefs.setString('selected_voice_config', configString);
    } catch (e) {
      _showError('Failed to save configuration: $e');
    }
  }

  Future<void> _changeVoiceConfiguration(VoiceConfig config) async {
    try {
      await _voiceService.changeVoiceConfig(config);
      await _saveConfiguration(config);

      setState(() {
        _selectedConfig = config;
      });

      _showSuccess('Voice configuration updated successfully');
    } catch (e) {
      _showError('Failed to change voice configuration: $e');
    }
  }

  Future<void> _testVoiceConfiguration(VoiceConfig config) async {
    setState(() {
      _isTesting = true;
    });

    try {
      // Temporarily apply the configuration for testing
      await _voiceService.changeVoiceConfig(config);

      // Test with a sample message
      await _voiceService.speak(
        "This is a test of the ${config.name} voice configuration. "
        "It supports ${config.accent} accent with ${config.description.toLowerCase()}.",
      );

      // Wait for speech to complete
      await Future.delayed(Duration(seconds: 5));

      // Restore the original configuration
      if (_selectedConfig != null) {
        await _voiceService.changeVoiceConfig(_selectedConfig!);
      }

      _showSuccess('Voice test completed');
    } catch (e) {
      _showError('Voice test failed: $e');
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading voice configurations...',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.white],
                ),
              ),
              child: Column(
                children: [
                  // Header section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.settings_voice,
                          size: 60,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Enhanced Voice Configuration',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Choose your preferred accent and voice settings for better speech recognition',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Current configuration
                  if (_selectedConfig != null)
                    Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Configuration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildConfigInfo(_selectedConfig!),
                        ],
                      ),
                    ),

                  // Available configurations
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _availableConfigs.length,
                      itemBuilder: (context, index) {
                        final config = _availableConfigs[index];
                        final isSelected = _selectedConfig?.name == config.name;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.record_voice_over,
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                              ),
                            ),
                            title: Text(
                              config.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.blue.shade800
                                    : Colors.grey.shade800,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  config.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                _buildConfigInfo(config, compact: true),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSelected)
                                  IconButton(
                                    icon: Icon(
                                      Icons.play_arrow,
                                      color: Colors.green.shade600,
                                    ),
                                    onPressed: _isTesting
                                        ? null
                                        : () => _testVoiceConfiguration(config),
                                    tooltip: 'Test voice',
                                  ),
                                if (!isSelected)
                                  ElevatedButton(
                                    onPressed: () =>
                                        _changeVoiceConfiguration(config),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text('Select'),
                                  ),
                                if (isSelected)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
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
            ),
    );
  }

  Widget _buildConfigInfo(VoiceConfig config, {bool compact = false}) {
    final textStyle = TextStyle(
      fontSize: compact ? 12 : 14,
      color: Colors.grey.shade600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.language,
              size: compact ? 14 : 16,
              color: Colors.grey.shade500,
            ),
            SizedBox(width: 4),
            Text('${config.accent} accent', style: textStyle),
            SizedBox(width: 16),
            Icon(
              Icons.speed,
              size: compact ? 14 : 16,
              color: Colors.grey.shade500,
            ),
            SizedBox(width: 4),
            Text(
              'Speed: ${(config.speechRate * 100).round()}%',
              style: textStyle,
            ),
          ],
        ),
        if (!compact) SizedBox(height: 4),
        if (!compact)
          Row(
            children: [
              Icon(
                Icons.tune,
                size: compact ? 14 : 16,
                color: Colors.grey.shade500,
              ),
              SizedBox(width: 4),
              Text('Pitch: ${(config.pitch * 100).round()}%', style: textStyle),
              SizedBox(width: 16),
              Icon(
                Icons.volume_up,
                size: compact ? 14 : 16,
                color: Colors.grey.shade500,
              ),
              SizedBox(width: 4),
              Text(
                'Volume: ${(config.volume * 100).round()}%',
                style: textStyle,
              ),
            ],
          ),
      ],
    );
  }
}
