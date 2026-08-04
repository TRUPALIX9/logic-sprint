import '../constants/app_config.dart';

abstract final class PlayerNameValidator {
  static final RegExp _allowedPattern = RegExp(r'^[A-Za-z0-9 _\-]+$');

  static String? validate(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter a display name.';
    }
    if (trimmed.length > AppConfig.maxPlayerNameLength) {
      return 'Name must be ${AppConfig.maxPlayerNameLength} characters or fewer.';
    }
    if (!_allowedPattern.hasMatch(trimmed)) {
      return 'Use only letters, numbers, spaces, underscore, or hyphen.';
    }
    return null;
  }

  static String normalize(String raw) => raw.trim();
}
