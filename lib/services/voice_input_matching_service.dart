import 'dart:math';

class VoiceInputMatchingService {
  static final VoiceInputMatchingService _instance =
      VoiceInputMatchingService._internal();
  factory VoiceInputMatchingService() => _instance;
  VoiceInputMatchingService._internal();

  // Fuzzy matching threshold
  static const double _similarityThreshold = 0.7;

  // Common voice input variations and corrections
  final Map<String, List<String>> _voiceVariations = {
    // Numbers
    'one': ['1', 'won', 'wun', 'on'],
    'two': ['2', 'to', 'too', 'tu'],
    'three': ['3', 'tree', 'thre', 'free'],
    'four': ['4', 'for', 'fore', 'foor'],
    'five': ['5', 'fiv', 'fife'],
    'six': ['6', 'sicks', 'sex'],
    'seven': ['7', 'sevn', 'sevan'],
    'eight': ['8', 'ate', 'ait'],
    'nine': ['9', 'niner', 'nin'],
    'zero': ['0', 'oh', 'o', 'zro'],

    // Navigation commands
    'home': ['home', 'go home', 'main menu', 'dashboard'],
    'back': ['back', 'go back', 'return', 'previous'],
    'menu': ['menu', 'show menu', 'options', 'main menu'],
    'help': ['help', 'get help', 'assistance', 'support'],
    'stop': ['stop', 'cancel', 'exit', 'quit'],
    'repeat': ['repeat', 'say again', 'repeat that', 'again'],

    // Confirmation commands
    'yes': ['yes', 'yeah', 'yep', 'correct', 'right', 'okay', 'ok'],
    'no': ['no', 'nope', 'negative', 'wrong', 'cancel'],
    'confirm': ['confirm', 'proceed', 'continue', 'go ahead'],
    'cancel': ['cancel', 'stop', 'abort', 'no'],

    // Transaction commands
    'deposit': ['deposit', 'save', 'add money', 'put money'],
    'withdraw': ['withdraw', 'take out', 'remove money', 'get money'],
    'balance': ['balance', 'check balance', 'account balance', 'money'],
    'loan': ['loan', 'borrow', 'get loan', 'apply loan'],
    'pay': ['pay', 'payment', 'pay loan', 'repay'],

    // Amount variations
    'hundred': ['100', 'one hundred', 'hundred', 'hun'],
    'thousand': ['1000', 'one thousand', 'thousand', 'k'],
    'five hundred': ['500', 'five hundred', 'five hun'],
    'five thousand': ['5000', 'five thousand', 'five k'],
  };

  // User-specific voice patterns
  final Map<String, Map<String, List<String>>> _userPatterns = {
    'elderly': {
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
      'commands': ['home', 'back', 'menu', 'help', 'stop', 'yes', 'no'],
      'amounts': ['hundred', 'thousand', 'five hundred', 'five thousand'],
    },
    'visually_impaired': {
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
      'commands': [
        'home',
        'back',
        'menu',
        'help',
        'stop',
        'repeat',
        'read screen',
      ],
      'amounts': ['hundred', 'thousand', 'five hundred', 'five thousand'],
    },
    'motor_impaired': {
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
      'commands': ['home', 'back', 'menu', 'help', 'stop', 'yes', 'no'],
      'amounts': ['hundred', 'thousand', 'five hundred', 'five thousand'],
    },
    'expert': {
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
      'commands': [
        'navigate to home',
        'return to previous',
        'display menu',
        'request assistance',
      ],
      'amounts': [
        'one hundred',
        'one thousand',
        'five hundred',
        'five thousand',
      ],
    },
  };

  // Enhanced fuzzy matching with performance optimization
  String? matchVoiceInput(
    String input,
    List<String> expectedCommands, {
    String userProfile = 'basic',
  }) {
    if (input.isEmpty || expectedCommands.isEmpty) return null;

    final normalizedInput = _normalizeInput(input);

    // First, try exact matching
    for (final command in expectedCommands) {
      if (_exactMatch(normalizedInput, command)) {
        return command;
      }
    }

    // Then, try variation matching
    for (final command in expectedCommands) {
      if (_variationMatch(normalizedInput, command)) {
        return command;
      }
    }

    // Finally, try fuzzy matching
    String? bestMatch;
    double bestScore = 0.0;

    for (final command in expectedCommands) {
      final score = _calculateSimilarity(normalizedInput, command);
      if (score > bestScore && score >= _similarityThreshold) {
        bestScore = score;
        bestMatch = command;
      }
    }

    return bestMatch;
  }

  // Normalize input for better matching
  String _normalizeInput(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[^\w\s]'), ''); // Remove special characters
  }

  // Exact matching
  bool _exactMatch(String input, String command) {
    return input == command.toLowerCase();
  }

  // Variation matching using predefined patterns
  bool _variationMatch(String input, String command) {
    final variations = _voiceVariations[command.toLowerCase()];
    if (variations != null) {
      for (final variation in variations) {
        if (input.contains(variation) || variation.contains(input)) {
          return true;
        }
      }
    }
    return false;
  }

  // Calculate similarity using Levenshtein distance
  double _calculateSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);
    return maxLength > 0 ? (maxLength - distance) / maxLength : 1.0;
  }

  // Levenshtein distance calculation
  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  // Match numbers specifically
  String? matchNumber(String input) {
    final normalizedInput = _normalizeInput(input);

    // Try exact number matching first
    for (final entry in _voiceVariations.entries) {
      if (entry.value.contains(normalizedInput)) {
        return entry.key;
      }
    }

    // Try fuzzy matching for numbers
    final numberCommands = [
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
    ];
    return matchVoiceInput(normalizedInput, numberCommands);
  }

  // Match confirmation commands
  String? matchConfirmation(String input) {
    final normalizedInput = _normalizeInput(input);
    final confirmationCommands = ['yes', 'no', 'confirm', 'cancel'];
    return matchVoiceInput(normalizedInput, confirmationCommands);
  }

  // Match navigation commands
  String? matchNavigation(String input) {
    final normalizedInput = _normalizeInput(input);
    final navigationCommands = [
      'home',
      'back',
      'menu',
      'help',
      'stop',
      'repeat',
    ];
    return matchVoiceInput(normalizedInput, navigationCommands);
  }

  // Match transaction commands
  String? matchTransaction(String input) {
    final normalizedInput = _normalizeInput(input);
    final transactionCommands = [
      'deposit',
      'withdraw',
      'balance',
      'loan',
      'pay',
    ];
    return matchVoiceInput(normalizedInput, transactionCommands);
  }

  // Match amounts
  String? matchAmount(String input) {
    final normalizedInput = _normalizeInput(input);
    final amountCommands = [
      'hundred',
      'thousand',
      'five hundred',
      'five thousand',
    ];
    return matchVoiceInput(normalizedInput, amountCommands);
  }

  // Get suggestions for failed matches
  List<String> getSuggestions(
    String input,
    List<String> expectedCommands, {
    String userProfile = 'basic',
  }) {
    final normalizedInput = _normalizeInput(input);
    final suggestions = <String>[];
    final scores = <String, double>{};

    // Calculate similarity scores
    for (final command in expectedCommands) {
      final score = _calculateSimilarity(normalizedInput, command);
      if (score > 0.3) {
        // Lower threshold for suggestions
        scores[command] = score;
      }
    }

    // Sort by score and return top suggestions
    final sortedCommands = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    for (int i = 0; i < min(3, sortedCommands.length); i++) {
      suggestions.add(sortedCommands[i]);
    }

    return suggestions;
  }

  // Validate PIN input
  bool validatePinInput(String input) {
    final normalizedInput = _normalizeInput(input);
    final digits = normalizedInput.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 4 && RegExp(r'^[0-9]{4}$').hasMatch(digits);
  }

  // Extract digits from voice input
  String extractDigits(String input) {
    final normalizedInput = _normalizeInput(input);
    final digits = normalizedInput.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }

  // Extract amount from voice input
  double? extractAmount(String input) {
    final normalizedInput = _normalizeInput(input);

    // Try to match common amount patterns
    if (normalizedInput.contains('hundred')) {
      return 100.0;
    } else if (normalizedInput.contains('thousand')) {
      return 1000.0;
    } else if (normalizedInput.contains('five hundred')) {
      return 500.0;
    } else if (normalizedInput.contains('five thousand')) {
      return 5000.0;
    }

    // Try to extract numeric values
    final numbers = RegExp(r'\d+').allMatches(normalizedInput);
    if (numbers.isNotEmpty) {
      final number = int.tryParse(numbers.first.group(0)!);
      if (number != null) {
        return number.toDouble();
      }
    }

    return null;
  }

  // Get user-specific command patterns
  Map<String, List<String>> getUserPatterns(String userProfile) {
    return _userPatterns[userProfile] ?? _userPatterns['elderly']!;
  }

  // Add custom voice variation
  void addVoiceVariation(String command, List<String> variations) {
    _voiceVariations[command.toLowerCase()] = variations;
  }

  // Performance monitoring
  Map<String, dynamic> getMatchingStats() {
    return {
      'variations_count': _voiceVariations.length,
      'user_patterns_count': _userPatterns.length,
      'similarity_threshold': _similarityThreshold,
    };
  }

  // Clear custom variations
  void clearCustomVariations() {
    _voiceVariations.clear();
  }
}
