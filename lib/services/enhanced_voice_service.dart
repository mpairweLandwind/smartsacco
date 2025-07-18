import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartsacco/services/analytics_service.dart';
import 'package:smartsacco/services/error_handling_service.dart';
import 'dart:async';

class EnhancedVoiceService {
  static final EnhancedVoiceService _instance =
      EnhancedVoiceService._internal();
  factory EnhancedVoiceService() => _instance;
  EnhancedVoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  final AnalyticsService _analytics = AnalyticsService();
  final ErrorHandlingService _errorHandler = ErrorHandlingService();

  // Performance optimization variables
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  Timer? _speechTimeout;
  Timer? _listeningTimeout;
  final Map<String, String> _voiceCache = {};
  final Map<String, List<String>> _commandCache = {};

  // Voice settings for different user types
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _selectedLanguage = 'en-US';
  bool _voiceEnabled = true;
  bool _autoListen = true;
  bool _continuousListening = false;

  // Accessibility profiles
  static const String _profileBasic = 'basic';
  static const String _profileAdvanced = 'advanced';
  static const String _profileExpert = 'expert';
  static const String _profileElderly = 'elderly';
  static const String _profileVisuallyImpaired = 'visually_impaired';
  static const String _profileMotorImpaired = 'motor_impaired';

  String _currentProfile = _profileBasic;

  // Voice command patterns optimized for different users
  final Map<String, Map<String, List<String>>> _voiceCommands = {
    _profileBasic: {
      'navigation': ['home', 'back', 'menu', 'help', 'stop'],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': ['yes', 'no', 'okay', 'cancel'],
    },
    _profileAdvanced: {
      'navigation': [
        'go to home',
        'go back',
        'show menu',
        'get help',
        'stop speaking',
      ],
      'transactions': [
        'make deposit',
        'check balance',
        'view loans',
        'pay loan',
      ],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': ['yes', 'no', 'confirm', 'cancel', 'repeat'],
    },
    _profileExpert: {
      'navigation': [
        'navigate to home',
        'return to previous',
        'display menu',
        'request assistance',
        'terminate speech',
      ],
      'transactions': [
        'initiate deposit',
        'retrieve balance',
        'display loan information',
        'process loan payment',
      ],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': [
        'affirmative',
        'negative',
        'confirm action',
        'cancel operation',
        'repeat instruction',
      ],
    },
    _profileElderly: {
      'navigation': ['home', 'back', 'menu', 'help', 'stop'],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': ['yes', 'no', 'okay', 'cancel', 'repeat'],
    },
    _profileVisuallyImpaired: {
      'navigation': ['home', 'back', 'menu', 'help', 'stop', 'read screen'],
      'transactions': ['deposit', 'balance', 'loans', 'pay'],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': ['yes', 'no', 'okay', 'cancel', 'repeat', 'read again'],
    },
    _profileMotorImpaired: {
      'navigation': ['home', 'back', 'menu', 'help', 'stop'],
      'transactions': ['deposit', 'balance', 'loans', 'pay'],
      'numbers': [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'zero',
      ],
      'confirmations': ['yes', 'no', 'okay', 'cancel', 'repeat'],
    },
  };

  // Performance optimization methods
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeTTS();
      await _initializeSTT();
      await _loadSettings();
      _isInitialized = true;

      await _analytics.trackFeatureUsage(
        featureName: 'voice_service_initialization',
        parameters: {'profile': _currentProfile},
      );
    } catch (e) {
      await _errorHandler.handleVoiceError('service_initialization', e);
    }
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.setLanguage(_selectedLanguage);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setVolume(_volume);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _cancelSpeechTimeout();
        _startSpeechTimeout();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _cancelSpeechTimeout();
        if (_autoListen && !_isListening) {
          _startListening();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _cancelSpeechTimeout();
        _errorHandler.handleVoiceError('tts_speak', msg);
      });
    } catch (e) {
      await _errorHandler.handleVoiceError('tts_initialization', e);
    }
  }

  Future<void> _initializeSTT() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          _isListening = false;
          _cancelListeningTimeout();
          _errorHandler.handleVoiceError('stt_initialize', error);
        },
        onStatus: (status) {
          if (status == 'listening') {
            _isListening = true;
            _startListeningTimeout();
          } else if (status == 'notListening') {
            _isListening = false;
            _cancelListeningTimeout();
          }
        },
      );

      if (!available) {
        await _errorHandler.handleVoiceError(
          'stt_initialization',
          'Speech recognition not available',
        );
      }
    } catch (e) {
      await _errorHandler.handleVoiceError('stt_initialization', e);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _pitch = prefs.getDouble('pitch') ?? 1.0;
      _volume = prefs.getDouble('volume') ?? 1.0;
      _selectedLanguage = prefs.getString('selected_language') ?? 'en-US';
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _autoListen = prefs.getBool('auto_listen') ?? true;
      _continuousListening = prefs.getBool('continuous_listening') ?? false;
      _currentProfile = prefs.getString('voice_profile') ?? _profileBasic;
    } catch (e) {
      await _errorHandler.handleVoiceError('settings_load', e);
    }
  }

  // Enhanced speak method with performance optimization
  Future<void> speak(
    String text, {
    bool interrupt = true,
    String? context,
    Map<String, dynamic>? parameters,
    bool cache = true,
  }) async {
    if (!_voiceEnabled || text.isEmpty) return;

    try {
      // Check cache for frequently used phrases
      if (cache && _voiceCache.containsKey(text)) {
        await _speakCached(text);
        return;
      }

      if (interrupt) {
        await _flutterTts.stop();
        _cancelSpeechTimeout();
      }

      await _flutterTts.speak(text);

      // Cache frequently used phrases
      if (cache && text.length < 100) {
        _voiceCache[text] = text;
        if (_voiceCache.length > 50) {
          _voiceCache.clear(); // Prevent memory overflow
        }
      }

      // Track analytics
      await _analytics.trackVoiceCommand(command: text, isSuccess: true);
    } catch (e) {
      await _errorHandler.handleVoiceError('speak', e, voiceData: parameters);
    }
  }

  Future<void> _speakCached(String text) async {
    // Optimized speaking for cached text
    await _flutterTts.speak(text);
  }

  // Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      _cancelListeningTimeout();
    }
  }

  // Start listening (internal method)
  Future<void> _startListening() async {
    if (_isListening) return;

    try {
      final listenOptions = SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      await _speechToText.listen(
        onResult: (result) {
          _processPartialResult(result);
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenOptions: listenOptions,
      );
    } catch (e) {
      await _errorHandler.handleVoiceError('start_listening', e);
    }
  }

  // Enhanced listening method with performance optimization
  Future<String?> listenForCommand({
    Duration timeout = const Duration(seconds: 10),
    String? prompt,
    bool continuous = false,
  }) async {
    if (!_voiceEnabled) return null;

    try {
      if (prompt != null) {
        await speak(prompt, interrupt: false);
      }

      if (_isListening) {
        await _speechToText.stop();
      }

      final listenOptions = SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      final result = await _speechToText.listen(
        onResult: (result) {
          _processPartialResult(result);
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        listenOptions: listenOptions,
      );

      if (result.finalResult) {
        final command = result.recognizedWords.toLowerCase().trim();

        // Cache command patterns
        _cacheCommand(command);

        // Track analytics
        await _analytics.trackVoiceCommand(command: command, isSuccess: true);

        return command;
      }

      return null;
    } catch (e) {
      await _errorHandler.handleVoiceError('listen_for_command', e);
      return null;
    }
  }

  void _processPartialResult(dynamic result) {
    // Process partial results for better responsiveness
    if (result.recognizedWords.isNotEmpty) {
      final words = result.recognizedWords.toLowerCase();

      // Quick command detection for common patterns
      for (final category in _voiceCommands[_currentProfile]!.keys) {
        for (final command in _voiceCommands[_currentProfile]![category]!) {
          if (words.contains(command)) {
            _handleQuickCommand(command, category);
            break;
          }
        }
      }
    }
  }

  void _handleQuickCommand(String command, String category) {
    // Handle quick commands without waiting for final result
    debugPrint('Quick command detected: $command in category: $category');
  }

  void _cacheCommand(String command) {
    if (!_commandCache.containsKey(_currentProfile)) {
      _commandCache[_currentProfile] = [];
    }

    _commandCache[_currentProfile]!.add(command);

    // Keep only recent commands
    if (_commandCache[_currentProfile]!.length > 20) {
      _commandCache[_currentProfile]!.removeAt(0);
    }
  }

  // Profile management for different user types
  Future<void> setProfile(String profile) async {
    if (_voiceCommands.containsKey(profile)) {
      _currentProfile = profile;

      // Adjust settings based on profile
      await _adjustSettingsForProfile(profile);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('voice_profile', profile);

      await _analytics.trackFeatureUsage(
        featureName: 'voice_profile_change',
        parameters: {'profile': profile},
      );
    }
  }

  Future<void> _adjustSettingsForProfile(String profile) async {
    switch (profile) {
      case _profileElderly:
        _speechRate = 0.4;
        _pitch = 1.2;
        _volume = 1.0;
        break;
      case _profileVisuallyImpaired:
        _speechRate = 0.6;
        _pitch = 1.0;
        _volume = 1.0;
        _autoListen = true;
        break;
      case _profileMotorImpaired:
        _speechRate = 0.5;
        _pitch = 1.0;
        _volume = 1.0;
        _continuousListening = true;
        break;
      case _profileExpert:
        _speechRate = 0.8;
        _pitch = 1.0;
        _volume = 0.8;
        break;
      default:
        _speechRate = 0.5;
        _pitch = 1.0;
        _volume = 1.0;
    }

    await _updateTTS();
  }

  Future<void> _updateTTS() async {
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(_volume);
  }

  // Performance optimization methods
  void _startSpeechTimeout() {
    _speechTimeout = Timer(const Duration(seconds: 30), () {
      if (_isSpeaking) {
        _flutterTts.stop();
        _isSpeaking = false;
      }
    });
  }

  void _cancelSpeechTimeout() {
    _speechTimeout?.cancel();
  }

  void _startListeningTimeout() {
    _listeningTimeout = Timer(const Duration(seconds: 15), () {
      if (_isListening) {
        _speechToText.stop();
        _isListening = false;
      }
    });
  }

  void _cancelListeningTimeout() {
    _listeningTimeout?.cancel();
  }

  // Voice command processing with profile-specific optimization
  Future<Map<String, dynamic>> processVoiceCommand(String command) async {
    try {
      final processedCommand = command.toLowerCase().trim();
      final response = <String, dynamic>{
        'success': false,
        'action': null,
        'parameters': {},
        'message': 'Command not recognized',
        'profile': _currentProfile,
      };

      // Get commands for current profile
      final profileCommands = _voiceCommands[_currentProfile] ?? {};

      // Check each category for matches
      for (final category in profileCommands.keys) {
        for (final pattern in profileCommands[category]!) {
          if (processedCommand.contains(pattern)) {
            response['success'] = true;
            response['action'] = category;
            response['parameters'] = {
              'command': pattern,
              'full_command': processedCommand,
            };
            response['message'] = 'Processing $category command: $pattern';
            break;
          }
        }
        if (response['success']) break;
      }

      // Track command processing
      await _analytics.trackVoiceCommand(
        command: processedCommand,
        isSuccess: response['success'],
      );

      return response;
    } catch (e) {
      await _errorHandler.handleVoiceError('process_command', e);
      return {
        'success': false,
        'action': null,
        'parameters': {},
        'message': 'Error processing command',
        'profile': _currentProfile,
      };
    }
  }

  // Continuous listening for motor-impaired users
  Future<void> startContinuousListening({
    required Function(String) onCommand,
    Duration checkInterval = const Duration(seconds: 2),
  }) async {
    if (!_continuousListening) return;

    Timer.periodic(checkInterval, (timer) async {
      if (!_isListening && !_isSpeaking) {
        final command = await listenForCommand(
          timeout: const Duration(seconds: 5),
        );
        if (command != null) {
          onCommand(command);
        }
      }
    });
  }

  // Get available profiles
  List<String> getAvailableProfiles() {
    return _voiceCommands.keys.toList();
  }

  // Get current profile
  String getCurrentProfile() {
    return _currentProfile;
  }

  // Get commands for current profile
  Map<String, List<String>> getCurrentCommands() {
    return _voiceCommands[_currentProfile] ?? {};
  }

  // Performance monitoring
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cache_size': _voiceCache.length,
      'command_cache_size': _commandCache.length,
      'is_speaking': _isSpeaking,
      'is_listening': _isListening,
      'current_profile': _currentProfile,
      'speech_rate': _speechRate,
      'pitch': _pitch,
      'volume': _volume,
    };
  }

  // Cleanup
  void dispose() {
    _cancelSpeechTimeout();
    _cancelListeningTimeout();
    _speechToText.stop();
    _flutterTts.stop();
    _voiceCache.clear();
    _commandCache.clear();
  }
}
