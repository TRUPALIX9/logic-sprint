import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppSupabaseService {
  static bool _initialized = false;

  static bool get isAvailable => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }
    try {
      await Supabase.initialize(
        url: 'https://axucnwnzuhdsiggqyjqf.supabase.co',
        publishableKey: 'sb_publishable_dzJkARQ59BSHuvJIlhnoTg_4NI5kWo0',
      );
      _initialized = true;
      return true;
    } on Object {
      _initialized = false;
      return false;
    }
  }
}
