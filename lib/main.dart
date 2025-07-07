import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../widgets/custom_error_widget.dart';
import './routes/app_routes.dart';
import './theme/app_theme.dart';
import './utils/auth_service.dart';
import './utils/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(
      errorDetails: details,
    );
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
  ]).then((value) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Sizer(builder: (context, orientation, screenType) {
      return MaterialApp(
        title: 'marketplace_pro',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
        // 🚨 END CRITICAL SECTION
        debugShowCheckedModeBanner: false,
        routes: AppRoutes.routes,
        initialRoute: AppRoutes.initial,
        home: AppInitializer(),
      );
    });
  }
}

class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final AuthService _authService = AuthService();
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _useOfflineMode = false;
  bool _navigationInProgress = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 Starting app initialization...');

      // Initialize Supabase with timeout and error handling
      await _initializeSupabaseWithFallback();

      // Set up auth state listener only if Supabase is available
      if (!_useOfflineMode) {
        _setupAuthStateListener();
      }

      setState(() {
        _isInitialized = true;
      });

      // Navigate based on current state
      await _handleInitialNavigation();
    } catch (e) {
      debugPrint('❌ App initialization failed: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isInitialized = true; // Still allow app to run
      });
      _navigateToSplash(); // Navigate to splash as fallback
    }
  }

  Future<void> _initializeSupabaseWithFallback() async {
    try {
      // Check if environment variables are available
      const supabaseUrl = 'https://rsskivonmfqrzxbmxrkl.supabase.co';
      const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzc2tpdm9ubWZxcnp4Ym14cmtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NTUxMTgsImV4cCI6MjA2NzIzMTExOH0.uYjeiqI7eNGZqnip4p-20AL6NT9YCos15gWY-lP82As';

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        debugPrint('⚠️ Supabase credentials not found, enabling offline mode');
        _useOfflineMode = true;
        return;
      }

      // Initialize Supabase with timeout
      await SupabaseService.initialize().timeout(
        Duration(seconds: 10),
      );

      debugPrint('✅ Supabase initialization completed');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      debugPrint('🔄 Falling back to offline mode');
      _useOfflineMode = true;
    }
  }

  void _setupAuthStateListener() {
    try {
      _authService.authStateChanges.listen(
        (data) {
          final event = data.event;
          debugPrint('🔄 Auth state changed: $event');

          // Ensure widget is still mounted and initialization is complete
          if (!mounted || !_isInitialized) return;

          // Prevent multiple rapid navigation calls
          if (_navigationInProgress) return;
          _navigationInProgress = true;

          // Add delay to ensure navigation context is ready
          Future.delayed(Duration(milliseconds: 100), () {
            if (!mounted) {
              _navigationInProgress = false;
              return;
            }

            try {
              if (event == 'SIGNED_IN') {
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.homeMarketplaceFeed,
                );
              } else if (event == 'SIGNED_OUT') {
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.loginScreen,
                );
              }
            } catch (e) {
              debugPrint('❌ Navigation error in auth listener: $e');
            } finally {
              _navigationInProgress = false;
            }
          });
        },
        onError: (error) {
          debugPrint('❌ Auth state listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to setup auth listener: $e');
    }
  }

  Future<void> _handleInitialNavigation() async {
    // Small delay to ensure widget is mounted
    await Future.delayed(Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      if (_useOfflineMode) {
        debugPrint('📱 Running in offline mode, navigating to splash');
        _navigateToSplash();
      } else if (_authService.isAuthenticated()) {
        debugPrint('🔐 User authenticated, navigating to home');
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.homeMarketplaceFeed,
        );
      } else {
        debugPrint('🔓 User not authenticated, navigating to splash');
        _navigateToSplash();
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      _navigateToSplash();
    }
  }

  void _navigateToSplash() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.splashScreen);
    }
  }

  void _retryInitialization() {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
      _useOfflineMode = false;
    });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.lightTheme.primaryColor,
              ),
              SizedBox(height: 24),
              Text(
                'Initializing Marketplace Pro...',
                style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Setting up your marketplace experience',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                SizedBox(height: 24),
                Text(
                  'Initialization Error',
                  style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'We encountered an issue while setting up the app. You can continue in offline mode or try again.',
                  textAlign: TextAlign.center,
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _retryInitialization,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightTheme.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _navigateToSplash,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color: AppTheme.lightTheme.primaryColor),
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            color: AppTheme.lightTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_useOfflineMode) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: Colors.orange[600],
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Running in offline mode. Some features may be limited.',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Return a minimal loading screen while navigation completes
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: AppTheme.lightTheme.primaryColor,
        ),
      ),
    );
  }
}
