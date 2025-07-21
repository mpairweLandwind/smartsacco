import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';

class EnhancedVoiceService {
  static final EnhancedVoiceService _instance =
      EnhancedVoiceService._internal();
  factory EnhancedVoiceService() => _instance;
  EnhancedVoiceService._internal();

  final Logger _logger = Logger('EnhancedVoiceService');

  // TTS and Speech Recognition instances
  FlutterTts flutterTts = FlutterTts();
  stt.SpeechToText speech = stt.SpeechToText();

  // Voice configuration
  VoiceConfig _currentConfig = VoiceConfig.defaultConfig();
  List<VoiceConfig> _availableConfigs = [];

  // Speech recognition settings
  bool _isListening = false;
  bool _isSpeaking = false;
  String _spokenText = "";
  int _retryCount = 0;
  final int _maxRetries = 3;

  // Callbacks
  Function(String)? _onSpeechResult;
  Function(String)? _onSpeechError;
  Function(bool)? _onListeningStateChanged;
  Function(bool)? _onSpeakingStateChanged;

  // Initialize the service with enhanced voice support
  Future<void> initialize({
    Function(String)? onSpeechResult,
    Function(String)? onSpeechError,
    Function(bool)? onListeningStateChanged,
    Function(bool)? onSpeakingStateChanged,
  }) async {
    _onSpeechResult = onSpeechResult;
    _onSpeechError = onSpeechError;
    _onListeningStateChanged = onListeningStateChanged;
    _onSpeakingStateChanged = onSpeakingStateChanged;

    await _requestPermissions();
    await _initializeTTS();
    await _loadAvailableVoices();
    await _initializeSpeechRecognition();
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _logger.warning('Microphone permission not granted');
      throw Exception('Microphone permission is required for voice features');
    }
  }

  // Initialize TTS with enhanced features
  Future<void> _initializeTTS() async {
    try {
      // Get available voices
      var voices = await flutterTts.getVoices;
      _logger.info('Available voices: $voices');

      // Set default configuration
      await _applyVoiceConfig(_currentConfig);

      // Set up completion handler
      flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _onSpeakingStateChanged?.call(false);
      });

      _logger.info('TTS initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize TTS: $e');
      throw Exception('Failed to initialize text-to-speech');
    }
  }

  // Load available voice configurations
  Future<void> _loadAvailableVoices() async {
    _availableConfigs = [
      VoiceConfig.defaultConfig(),
      VoiceConfig(
        name: 'British English',
        language: 'en-GB',
        speechRate: 0.5,
        pitch: 1.0,
        volume: 1.0,
        voiceType: 'en-GB-Standard-A',
        accent: 'British',
        description: 'Clear British accent',
      ),
      VoiceConfig(
        name: 'Australian English',
        language: 'en-AU',
        speechRate: 0.5,
        pitch: 1.0,
        volume: 1.0,
        voiceType: 'en-AU-Standard-A',
        accent: 'Australian',
        description: 'Australian accent',
      ),
      VoiceConfig(
        name: 'Indian English',
        language: 'en-IN',
        speechRate: 0.4,
        pitch: 1.1,
        volume: 1.0,
        voiceType: 'en-IN-Standard-A',
        accent: 'Indian',
        description: 'Indian English accent',
      ),
      VoiceConfig(
        name: 'Slow and Clear',
        language: 'en-US',
        speechRate: 0.3,
        pitch: 1.0,
        volume: 1.0,
        voiceType: 'en-US-Standard-A',
        accent: 'American',
        description: 'Slow and clear pronunciation',
      ),
      VoiceConfig(
        name: 'High Pitch',
        language: 'en-US',
        speechRate: 0.5,
        pitch: 1.3,
        volume: 1.0,
        voiceType: 'en-US-Standard-A',
        accent: 'American',
        description: 'Higher pitch for better clarity',
      ),
      VoiceConfig(
        name: 'Low Pitch',
        language: 'en-US',
        speechRate: 0.5,
        pitch: 0.8,
        volume: 1.0,
        voiceType: 'en-US-Standard-A',
        accent: 'American',
        description: 'Lower pitch for deeper voice',
      ),
    ];
  }

  // Initialize speech recognition with enhanced settings
  Future<void> _initializeSpeechRecognition() async {
    try {
      bool available = await speech.initialize(
        onStatus: (status) {
          _logger.info('Speech status: $status');
          _isListening = status == 'listening';
          _onListeningStateChanged?.call(_isListening);

          if (status == 'done' || status == 'notListening') {
            _handleListeningComplete();
          }
        },
        onError: (error) {
          _logger.warning('Speech error: $error');
          _isListening = false;
          _onListeningStateChanged?.call(false);
          _onSpeechError?.call(error.errorMsg);
        },
      );

      if (!available) {
        throw Exception('Speech recognition not available');
      }

      _logger.info('Speech recognition initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize speech recognition: $e');
      throw Exception('Failed to initialize speech recognition');
    }
  }

  // Apply voice configuration
  Future<void> _applyVoiceConfig(VoiceConfig config) async {
    try {
      await flutterTts.setLanguage(config.language);
      await flutterTts.setSpeechRate(config.speechRate);
      await flutterTts.setPitch(config.pitch);
      await flutterTts.setVolume(config.volume);

      // Try to set specific voice if available
      if (config.voiceType.isNotEmpty) {
        try {
          await flutterTts.setVoice({
            "name": config.voiceType,
            "locale": config.language,
          });
        } catch (e) {
          _logger.warning('Could not set specific voice: $e');
        }
      }

      _currentConfig = config;
      _logger.info('Applied voice config: ${config.name}');
    } catch (e) {
      _logger.severe('Failed to apply voice config: $e');
    }
  }

  // Get available voice configurations
  List<VoiceConfig> getAvailableConfigs() {
    return List.from(_availableConfigs);
  }

  // Get current voice configuration
  VoiceConfig getCurrentConfig() {
    return _currentConfig;
  }

  // Change voice configuration
  Future<void> changeVoiceConfig(VoiceConfig config) async {
    await _applyVoiceConfig(config);
  }

  // Enhanced speech recognition with multiple accent support
  Future<void> startListening({
    List<String> triggerWords = const ['one', '1', 'won'],
    Duration listenFor = const Duration(seconds: 10), // Reduced from 15 to 10
    Duration pauseFor = const Duration(seconds: 3),   // Reduced from 5 to 3
  }) async {
    if (_isListening) {
      await stopListening();
    }

    try {
      _retryCount = 0;
      _spokenText = "";
      _isListening = true;
      _onListeningStateChanged?.call(true);

      await speech.listen(
        onResult: (result) {
          _spokenText = result.recognizedWords.toLowerCase();
          _logger.info('Recognized: $_spokenText');

          // Check for trigger words with enhanced matching
          bool hasTriggerWord = triggerWords.any(
            (word) =>
                _spokenText.contains(word) ||
                _getAccentVariations(
                  word,
                ).any((variation) => _spokenText.contains(variation)),
          );

          if (hasTriggerWord) {
            _onSpeechResult?.call(_spokenText);
          }
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation, // Changed from confirmation to dictation for better recognition
        // Enhanced recognition settings for different accents
        onSoundLevelChange: (level) {
          // Optional: Handle sound level changes
        },
      );
    } catch (e) {
      _logger.severe('Failed to start listening: $e');
      _isListening = false;
      _onListeningStateChanged?.call(false);
      _onSpeechError?.call('Failed to start speech recognition');
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    try {
      await speech.stop();
      _isListening = false;
      _onListeningStateChanged?.call(false);
    } catch (e) {
      _logger.warning('Error stopping speech recognition: $e');
    }
  }

  // Enhanced speech synthesis with current voice config
  Future<void> speak(String text) async {
    try {
      _isSpeaking = true;
      _onSpeakingStateChanged?.call(true);

      await flutterTts.speak(text);
    } catch (e) {
      _logger.severe('Failed to speak: $e');
      _isSpeaking = false;
      _onSpeakingStateChanged?.call(false);
    }
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    try {
      await flutterTts.stop();
      _isSpeaking = false;
      _onSpeakingStateChanged?.call(false);
    } catch (e) {
      _logger.warning('Error stopping TTS: $e');
    }
  }

  // Get accent variations for better word recognition
  List<String> _getAccentVariations(String word) {
    Map<String, List<String>> accentVariations = {
      'one': ['wan', 'wun', 'won', '1', 'first', 'start'],
      'two': ['too', 'to', '2', 'second'],
      'three': ['tree', 'free', '3', 'third'],
      'four': ['for', 'fore', '4', 'fourth'],
      'five': ['fife', '5', 'fifth'],
      'six': ['sicks', '6', 'sixth'],
      'seven': ['7', 'seventh'],
      'eight': ['ate', '8', 'eighth'],
      'nine': ['9', 'ninth'],
      'ten': ['10', 'tenth'],
      'yes': ['yeah', 'yep', 'yup', 'sure', 'okay', 'ok'],
      'no': ['nope', 'nah', 'negative'],
      'register': ['registration', 'sign up', 'join', 'create account'],
      'login': ['sign in', 'log in', 'enter', 'access'],
      'balance': ['bal', 'money', 'amount', 'funds'],
      'deposit': ['dep', 'add money', 'put money', 'save'],
      'withdraw': ['withdrawal', 'take money', 'get money', 'cash out'],
      'loans': ['loan', 'borrow', 'credit'],
      'transactions': ['trans', 'history', 'activity', 'records'],
      'settings': ['set', 'config', 'preferences', 'options'],
      'help': ['assist', 'support', 'guide'],
      'logout': ['log out', 'sign out', 'exit', 'quit'],
    };

    return accentVariations[word.toLowerCase()] ?? [word];
  }

  // Handle listening completion with retry logic
  void _handleListeningComplete() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _logger.info('Retry attempt $_retryCount of $_maxRetries');
    }
  }

  // Get current listening state
  bool get isListening => _isListening;

  // Get current speaking state
  bool get isSpeaking => _isSpeaking;

  // Get spoken text
  String get spokenText => _spokenText;

  // Get retry count
  int get retryCount => _retryCount;

  // Get max retries
  int get maxRetries => _maxRetries;

  // Dispose resources
  void dispose() {
    stopListening();
    stopSpeaking();
  }
}

// Voice configuration class
class VoiceConfig {
  final String name;
  final String language;
  final double speechRate;
  final double pitch;
  final double volume;
  final String voiceType;
  final String accent;
  final String description;

  VoiceConfig({
    required this.name,
    required this.language,
    required this.speechRate,
    required this.pitch,
    required this.volume,
    required this.voiceType,
    required this.accent,
    required this.description,
  });

  // Default configuration
  factory VoiceConfig.defaultConfig() {
    return VoiceConfig(
      name: 'Standard American',
      language: 'en-US',
      speechRate: 0.5,
      pitch: 1.0,
      volume: 1.0,
      voiceType: 'en-US-Standard-A',
      accent: 'American',
      description: 'Clear American accent',
    );
  }

  // Create from map
  factory VoiceConfig.fromMap(Map<String, dynamic> map) {
    return VoiceConfig(
      name: map['name'] ?? '',
      language: map['language'] ?? 'en-US',
      speechRate: (map['speechRate'] ?? 0.5).toDouble(),
      pitch: (map['pitch'] ?? 1.0).toDouble(),
      volume: (map['volume'] ?? 1.0).toDouble(),
      voiceType: map['voiceType'] ?? '',
      accent: map['accent'] ?? '',
      description: map['description'] ?? '',
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'language': language,
      'speechRate': speechRate,
      'pitch': pitch,
      'volume': volume,
      'voiceType': voiceType,
      'accent': accent,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'VoiceConfig(name: $name, language: $language, accent: $accent)';
  }
}
