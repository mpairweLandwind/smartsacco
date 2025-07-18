import 'package:flutter/foundation.dart';
import 'package:smartsacco/services/enhanced_voice_service.dart';
import 'package:smartsacco/services/analytics_service.dart';
import 'package:smartsacco/services/error_handling_service.dart';
import 'dart:async';

class VoiceNavigationService {
  static final VoiceNavigationService _instance =
      VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

  final EnhancedVoiceService _voiceService = EnhancedVoiceService();
  final AnalyticsService _analytics = AnalyticsService();
  final ErrorHandlingService _errorHandler = ErrorHandlingService();

  // Navigation state
  String _currentScreen = '';
  String _previousScreen = '';
  final List<String> _navigationHistory = [];
  bool _isNavigating = false;
  Timer? _navigationTimeout;

  // Voice navigation patterns optimized for different users
  final Map<String, Map<String, String>> _navigationCommands = {
    'basic': {
      'home': 'go to home',
      'back': 'go back',
      'menu': 'show menu',
      'help': 'get help',
      'stop': 'stop navigation',
      'repeat': 'repeat options',
    },
    'advanced': {
      'home': 'navigate to home',
      'back': 'return to previous',
      'menu': 'display menu',
      'help': 'request assistance',
      'stop': 'terminate navigation',
      'repeat': 'repeat current options',
    },
    'expert': {
      'home': 'navigate to home screen',
      'back': 'return to previous screen',
      'menu': 'display main menu',
      'help': 'request contextual help',
      'stop': 'terminate current navigation',
      'repeat': 'repeat available options',
    },
    'elderly': {
      'home': 'home',
      'back': 'back',
      'menu': 'menu',
      'help': 'help',
      'stop': 'stop',
      'repeat': 'repeat',
    },
    'visually_impaired': {
      'home': 'go to home',
      'back': 'go back',
      'menu': 'show menu',
      'help': 'get help',
      'stop': 'stop',
      'repeat': 'repeat options',
      'read_screen': 'read screen content',
    },
    'motor_impaired': {
      'home': 'home',
      'back': 'back',
      'menu': 'menu',
      'help': 'help',
      'stop': 'stop',
      'repeat': 'repeat',
    },
  };

  // Screen-specific voice commands
  final Map<String, Map<String, dynamic>> _screenCommands = {
    'dashboard': {
      'commands': {
        'check_balance': 'check balance',
        'make_deposit': 'make deposit',
        'view_loans': 'view loans',
        'view_transactions': 'view transactions',
        'apply_loan': 'apply for loan',
        'settings': 'go to settings',
        'logout': 'logout',
      },
      'help_text':
          'Available commands: check balance, make deposit, view loans, view transactions, apply for loan, settings, logout',
    },
    'deposit': {
      'commands': {
        'amount_100': 'one hundred',
        'amount_500': 'five hundred',
        'amount_1000': 'one thousand',
        'amount_5000': 'five thousand',
        'confirm': 'confirm deposit',
        'cancel': 'cancel deposit',
        'back': 'go back',
      },
      'help_text':
          'Available amounts: one hundred, five hundred, one thousand, five thousand. Say confirm to proceed or cancel to go back.',
    },
    'loans': {
      'commands': {
        'apply': 'apply for loan',
        'view_active': 'view active loans',
        'pay_loan': 'pay loan',
        'back': 'go back',
      },
      'help_text':
          'Available commands: apply for loan, view active loans, pay loan, go back',
    },
    'settings': {
      'commands': {
        'voice_settings': 'voice settings',
        'security': 'security settings',
        'notifications': 'notification settings',
        'data': 'data management',
        'back': 'go back',
      },
      'help_text':
          'Available settings: voice settings, security settings, notification settings, data management, go back',
    },
  };

  // Initialize voice navigation
  Future<void> initialize() async {
    try {
      await _voiceService.initialize();
      await _analytics.trackFeatureUsage(
        featureName: 'voice_navigation_initialization',
      );
    } catch (e) {
      await _errorHandler.handleVoiceError('navigation_initialization', e);
    }
  }

  // Navigate to a screen with voice feedback
  Future<void> navigateTo(
    String screen, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_isNavigating) return;

    try {
      _isNavigating = true;
      _startNavigationTimeout();

      // Update navigation history
      _previousScreen = _currentScreen;
      _currentScreen = screen;
      _navigationHistory.add(screen);

      // Keep history manageable
      if (_navigationHistory.length > 10) {
        _navigationHistory.removeAt(0);
      }

      // Provide voice feedback based on user profile
      await _provideNavigationFeedback(screen, parameters);

      // Track navigation
      await _analytics.trackEvent(
        eventName: 'voice_navigation',
        parameters: {
          'from': _previousScreen,
          'to': screen,
          'profile': _voiceService.getCurrentProfile(),
          ...?parameters,
        },
      );
    } catch (e) {
      await _errorHandler.handleVoiceError('navigation', e);
    } finally {
      _isNavigating = false;
      _cancelNavigationTimeout();
    }
  }

  // Provide contextual voice feedback for navigation
  Future<void> _provideNavigationFeedback(
    String screen,
    Map<String, dynamic>? parameters,
  ) async {
    final profile = _voiceService.getCurrentProfile();
    String feedback = '';

    switch (screen) {
      case 'dashboard':
        feedback = _getDashboardFeedback(profile);
        break;
      case 'deposit':
        feedback = _getDepositFeedback(profile, parameters);
        break;
      case 'loans':
        feedback = _getLoansFeedback(profile);
        break;
      case 'settings':
        feedback = _getSettingsFeedback(profile);
        break;
      default:
        feedback =
            'You are now on the $screen screen. Say help for available options.';
    }

    await _voiceService.speak(feedback, context: 'navigation');
  }

  String _getDashboardFeedback(String profile) {
    switch (profile) {
      case 'elderly':
        return 'Welcome to your dashboard. You can say: check balance, make deposit, view loans, or settings.';
      case 'visually_impaired':
        return 'Dashboard loaded. Available options: check balance, make deposit, view loans, view transactions, apply for loan, settings, logout. Say help to repeat options.';
      case 'motor_impaired':
        return 'Dashboard ready. Commands: check balance, make deposit, view loans, settings, logout.';
      default:
        return 'Dashboard loaded. Available commands: check balance, make deposit, view loans, view transactions, apply for loan, settings, logout.';
    }
  }

  String _getDepositFeedback(String profile, Map<String, dynamic>? parameters) {
    final amount = parameters?['amount']?.toString() ?? '';
    switch (profile) {
      case 'elderly':
        return 'Deposit screen. Available amounts: one hundred, five hundred, one thousand, five thousand. Say confirm to proceed.';
      case 'visually_impaired':
        return 'Deposit screen loaded. ${amount.isNotEmpty ? 'Amount: $amount. ' : ''}Available amounts: one hundred, five hundred, one thousand, five thousand. Say confirm to proceed or cancel to go back.';
      default:
        return 'Deposit screen. ${amount.isNotEmpty ? 'Amount: $amount. ' : ''}Available amounts: one hundred, five hundred, one thousand, five thousand. Say confirm to proceed or cancel to go back.';
    }
  }

  String _getLoansFeedback(String profile) {
    switch (profile) {
      case 'elderly':
        return 'Loans screen. You can apply for a loan, view active loans, or pay a loan.';
      case 'visually_impaired':
        return 'Loans screen loaded. Available options: apply for loan, view active loans, pay loan, go back.';
      default:
        return 'Loans screen. Available commands: apply for loan, view active loans, pay loan, go back.';
    }
  }

  String _getSettingsFeedback(String profile) {
    switch (profile) {
      case 'elderly':
        return 'Settings screen. You can adjust voice settings, security, notifications, or manage data.';
      case 'visually_impaired':
        return 'Settings screen loaded. Available settings: voice settings, security settings, notification settings, data management, go back.';
      default:
        return 'Settings screen. Available settings: voice settings, security settings, notification settings, data management, go back.';
    }
  }

  // Process voice commands for current screen
  Future<Map<String, dynamic>> processScreenCommand(String command) async {
    try {
      final screenCommands = _screenCommands[_currentScreen];
      if (screenCommands == null) {
        return {
          'success': false,
          'action': null,
          'message': 'No commands available for current screen',
        };
      }

      final commands = screenCommands['commands'] as Map<String, String>;

      for (final entry in commands.entries) {
        if (command.contains(entry.value.toLowerCase())) {
          return {
            'success': true,
            'action': entry.key,
            'command': entry.value,
            'screen': _currentScreen,
            'message': 'Processing ${entry.value}',
          };
        }
      }

      // Check for general navigation commands
      final navResult = await _processGeneralNavigation(command);
      if (navResult['success']) {
        return navResult;
      }

      return {
        'success': false,
        'action': null,
        'message': 'Command not recognized. Say help for available options.',
      };
    } catch (e) {
      await _errorHandler.handleVoiceError('screen_command_processing', e);
      return {
        'success': false,
        'action': null,
        'message': 'Error processing command',
      };
    }
  }

  // Process general navigation commands
  Future<Map<String, dynamic>> _processGeneralNavigation(String command) async {
    final profile = _voiceService.getCurrentProfile();
    final navCommands =
        _navigationCommands[profile] ?? _navigationCommands['basic']!;

    for (final entry in navCommands.entries) {
      if (command.contains(entry.value.toLowerCase())) {
        return {
          'success': true,
          'action': entry.key,
          'command': entry.value,
          'type': 'navigation',
          'message': 'Processing navigation command: ${entry.value}',
        };
      }
    }

    return {'success': false};
  }

  // Provide help for current screen
  Future<void> provideHelp() async {
    final screenCommands = _screenCommands[_currentScreen];
    if (screenCommands != null) {
      final helpText = screenCommands['help_text'] as String;
      await _voiceService.speak(helpText, context: 'help');
    } else {
      await _voiceService.speak(
        'Help is not available for this screen. Say back to return.',
        context: 'help',
      );
    }
  }

  // Go back to previous screen
  Future<void> goBack() async {
    if (_navigationHistory.length > 1) {
      _navigationHistory.removeLast();
      final previousScreen = _navigationHistory.last;
      await navigateTo(previousScreen);
    } else {
      await _voiceService.speak(
        'No previous screen to go back to.',
        context: 'navigation',
      );
    }
  }

  // Repeat current options
  Future<void> repeatOptions() async {
    await provideHelp();
  }

  // Get current screen
  String getCurrentScreen() {
    return _currentScreen;
  }

  // Get navigation history
  List<String> getNavigationHistory() {
    return List.from(_navigationHistory);
  }

  // Check if currently navigating
  bool get isNavigating => _isNavigating;

  // Performance optimization methods
  void _startNavigationTimeout() {
    _navigationTimeout = Timer(const Duration(seconds: 10), () {
      if (_isNavigating) {
        _isNavigating = false;
        debugPrint('Navigation timeout reached');
      }
    });
  }

  void _cancelNavigationTimeout() {
    _navigationTimeout?.cancel();
  }

  // Get available commands for current screen
  Map<String, String> getCurrentScreenCommands() {
    final screenCommands = _screenCommands[_currentScreen];
    if (screenCommands != null) {
      return Map<String, String>.from(
        screenCommands['commands'] as Map<String, String>,
      );
    }
    return {};
  }

  // Get help text for current screen
  String getCurrentScreenHelp() {
    final screenCommands = _screenCommands[_currentScreen];
    if (screenCommands != null) {
      return screenCommands['help_text'] as String;
    }
    return 'No help available for this screen.';
  }

  // Set user profile for voice navigation
  Future<void> setProfile(String profile) async {
    await _voiceService.setProfile(profile);
    await _analytics.trackFeatureUsage(
      featureName: 'voice_navigation_profile_change',
      parameters: {'profile': profile},
    );
  }

  // Get current profile
  String getCurrentProfile() {
    return _voiceService.getCurrentProfile();
  }

  // Performance monitoring
  Map<String, dynamic> getNavigationStats() {
    return {
      'current_screen': _currentScreen,
      'previous_screen': _previousScreen,
      'navigation_history_length': _navigationHistory.length,
      'is_navigating': _isNavigating,
      'current_profile': getCurrentProfile(),
      'available_commands': getCurrentScreenCommands().length,
    };
  }

  // Cleanup
  void dispose() {
    _cancelNavigationTimeout();
    _navigationHistory.clear();
  }
}
