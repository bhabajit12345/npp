import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  static bool _initializationInProgress = false;

  // Singleton pattern
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // 🔐 HARDCODED Supabase credentials for local testing
  // 🚨 Replace these with your real values
  static const String supabaseUrl = 'https://rsskivonmfqrzxbmxrkl.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzc2tpdm9ubWZxcnp4Ym14cmtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NTUxMTgsImV4cCI6MjA2NzIzMTExOH0.uYjeiqI7eNGZqnip4p-20AL6NT9YCos15gWY-lP82As';

  // Static initialization method
  static Future<void> initialize() async {
    if (_instance._isInitialized || _initializationInProgress) return;
    _initializationInProgress = true;

    try {
      debugPrint('🧪 Using Supabase URL: $supabaseUrl');
      debugPrint('🧪 Using Supabase Key: ${supabaseAnonKey.substring(0, 6)}...');

      // Validate URL format
      if (!_isValidUrl(supabaseUrl)) {
        throw SupabaseException('Invalid SUPABASE_URL format: $supabaseUrl');
      }

      // Initialize Supabase with retry mechanism
      await _initializeWithRetry();

      _instance._client = Supabase.instance.client;
      _instance._isInitialized = true;

      debugPrint('✅ Supabase initialized successfully');
      debugPrint('🔗 Connected to: ${_maskUrl(supabaseUrl)}');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }

  static Future<void> _initializeWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          debug: kDebugMode,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true,
          ),
        );
        return;
      } catch (e) {
        debugPrint('❌ Supabase initialization attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          throw SupabaseException('Failed to initialize Supabase: $e');
        }
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
  }

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _maskUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return 'invalid-url';
    }
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw SupabaseException(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client;
  }

  Future<SupabaseClient> get clientAsync async {
    if (!_isInitialized) {
      await initialize();
    }
    return _client;
  }

  SupabaseClient? get safeClient => _isInitialized ? _client : null;

  bool get isInitialized => _isInitialized;

  bool get isAuthenticated {
    try {
      return _isInitialized && _client.auth.currentUser != null;
    } catch (e) {
      debugPrint('❌ Auth check failed: $e');
      return false;
    }
  }

  String? get currentUserId {
    try {
      return _isInitialized ? _client.auth.currentUser?.id : null;
    } catch (e) {
      debugPrint('❌ Get user ID failed: $e');
      return null;
    }
  }

  User? get currentUser {
    try {
      return _isInitialized ? _client.auth.currentUser : null;
    } catch (e) {
      debugPrint('❌ Get current user failed: $e');
      return null;
    }
  }
Future<void> signOut() async {
    try {
      if (!_isInitialized) {
        debugPrint('⚠️ Cannot sign out: Supabase not initialized');
        return;
      }
      await _client.auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      throw SupabaseException('Sign out failed: $e');
    }
  }

  Stream<AuthState> get authStateChanges {
    if (!_isInitialized) {
      throw SupabaseException(
        'Cannot access auth state: Supabase not initialized',
      );
    }
    return _client.auth.onAuthStateChange.handleError((error) {
      debugPrint('❌ Auth state change error: $error');
    });
  }

  static Future<void> dispose() async {
    try {
      if (_instance._isInitialized) {
        await _instance._client.dispose();
        _instance._isInitialized = false;
        debugPrint('🧹 Supabase service disposed');
      }
    } catch (e) {
      debugPrint('❌ Dispose failed: $e');
    }
  }

  Future<bool> checkConnection() async {
    try {
      if (!_isInitialized) return false;
      await _client.from('user_profiles').select('id').limit(1).maybeSingle();
      return true;
    } catch (e) {
      debugPrint('❌ Connection check failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    final status = <String, dynamic>{
      'initialized': _isInitialized,
      'authenticated': isAuthenticated,
      'user_id': currentUserId,
      'connection_ok': false,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isInitialized) {
      status['connection_ok'] = await checkConnection();
    }

    return status;
  }
}

class SupabaseException implements Exception {
  final String message;
  const SupabaseException(this.message);

  @override
  String toString() => 'SupabaseException: $message';
}
