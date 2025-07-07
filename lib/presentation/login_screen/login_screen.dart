import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  String? _emailError;
  String? _passwordError;

  // Focus nodes to manage keyboard behavior
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // No need for controller or focus listeners!
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _isFormValid = _emailError == null &&
          _passwordError == null &&
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return null;

    // Check if it's a phone number
    if (RegExp(r'^\+?[\d\s\-\(\)]+').hasMatch(value)) {
      if (value.length < 10) return 'Please enter a valid phone number';
      return null;
    }

    // Check if it's an email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return null;
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_isFormValid) return;

    // Dismiss keyboard before starting login process
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response =
          await _authService.signIn(email: email, password: password);

      if (response.user != null) {
        // Success - trigger haptic feedback
        HapticFeedback.lightImpact();

        setState(() {
          _isLoading = false;
        });

        // Navigate to home marketplace feed
        if (mounted) {
          Navigator.pushReplacementNamed(
              context, AppRoutes.homeMarketplaceFeed);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Authentication failed. Please try again.');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Login failed. Please check your credentials.';
      if (error.toString().contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (error.toString().contains('Email not confirmed')) {
        errorMessage = 'Please check your email and verify your account.';
      }

      _showErrorSnackBar(errorMessage);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.lightTheme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(4.w)));
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    // Dismiss keyboard before social login
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // Implement OAuth login with Supabase
      final supabaseService = SupabaseService();
      final client = supabaseService.client;

      late OAuthProvider oauthProvider;
      if (provider == 'Google') {
        oauthProvider = OAuthProvider.google;
      } else if (provider == 'Apple') {
        oauthProvider = OAuthProvider.apple;
      } else if (provider == 'Facebook') {
        oauthProvider = OAuthProvider.facebook;
      } else {
        throw Exception('Unsupported provider: $provider');
      }

      final response = await client.auth.signInWithOAuth(oauthProvider,
          redirectTo: 'com.marketplace.pro://login-callback');

      setState(() {
        _isLoading = false;
      });

      if (response) {
        HapticFeedback.lightImpact();
        // Navigate to home marketplace feed
        if (mounted) {
          Navigator.pushReplacementNamed(
              context, AppRoutes.homeMarketplaceFeed);
        }
      } else {
        _showErrorSnackBar('Social login cancelled or failed.');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Social login failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
            child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height -
                                MediaQuery.of(context).padding.top -
                                MediaQuery.of(context).padding.bottom),
                        child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 8.h),
                                  buildLogo(),
                                  SizedBox(height: 6.h),
                                  buildLoginForm(),
                                  SizedBox(height: 4.h),
                                  _buildSocialLoginSection(),
                                  SizedBox(height: 4.h),
                                  _buildSignUpLink(),
                                  SizedBox(height: 4.h),
                                ])))))));
  }

  Widget buildLogo() {
    return Center(
        child: CustomImageWidget(imageUrl: 'logo_image_url', height: 10.h));
  }

  Widget buildLoginForm() {
    return Form(
        key: _formKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildEmailField(),
          SizedBox(height: 2.h),
          _buildPasswordField(),
          SizedBox(height: 0.5.h),
          _buildForgotPasswordLink(),
          SizedBox(height: 3.h),
          _buildLoginButton(),
        ]));
  }

  Widget _buildEmailField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: true,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          decoration: InputDecoration(
              labelText: 'Email or Phone',
              hintText: 'Enter your email or phone number',
              prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                      iconName: 'email',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 5.w)),
              errorText: null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: BorderSide(
                      color: AppTheme.lightTheme.colorScheme.outline)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: BorderSide(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      width: 2))),
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (value) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          }),
      if (_emailError != null) ...[
        SizedBox(height: 1.h),
        Padding(
            padding: EdgeInsets.only(left: 3.w),
            child: Text(_emailError!,
                style: AppTheme.lightTheme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.lightTheme.colorScheme.error))),
      ],
    ]);
  }

  Widget _buildPasswordField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                      iconName: 'lock',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 5.w)),
              suffixIcon: IconButton(
                  icon: CustomIconWidget(
                      iconName:
                          _isPasswordVisible ? 'visibility_off' : 'visibility',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 5.w),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  }),
              errorText: null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: BorderSide(
                      color: AppTheme.lightTheme.colorScheme.outline)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: BorderSide(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      width: 2))),
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (value) {
            if (_isFormValid) {
              _handleLogin();
            }
          }),
      if (_passwordError != null) ...[
        SizedBox(height: 1.h),
        Padding(
            padding: EdgeInsets.only(left: 3.w),
            child: Text(_passwordError!,
                style: AppTheme.lightTheme.textTheme.bodySmall
                    ?.copyWith(color: AppTheme.lightTheme.colorScheme.error))),
      ],
    ]);
  }

  Widget _buildForgotPasswordLink() {
    return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Forgot password functionality coming soon!'),
                  behavior: SnackBarBehavior.floating));
            },
            child: Text('Forgot Password?',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.primaryColor,
                    fontWeight: FontWeight.w500))));
  }

  Widget _buildLoginButton() {
    return SizedBox(
        height: 7.h,
        child: ElevatedButton(
            onPressed: _isFormValid && !_isLoading ? _handleLogin : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid
                    ? AppTheme.lightTheme.primaryColor
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant
                        .withAlpha(76),
                foregroundColor: Colors.white,
                elevation: _isFormValid ? 2.0 : 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2.w))),
            child: _isLoading
                ? SizedBox(
                    width: 5.w,
                    height: 5.w,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))
                : Text('Login',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600))));
  }

  Widget _buildSocialLoginSection() {
    return Column(children: [
      Row(children: [
        Expanded(
            child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline, thickness: 1)),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text('Or continue with',
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant))),
        Expanded(
            child: Divider(
                color: AppTheme.lightTheme.colorScheme.outline, thickness: 1)),
      ]),
      SizedBox(height: 3.h),
      Row(children: [
        Expanded(
            child: _buildSocialButton(
                'Google',
                'google',
                Colors.white,
                AppTheme.lightTheme.colorScheme.outline,
                () => _handleSocialLogin('Google'))),
        SizedBox(width: 3.w),
        Expanded(
            child: _buildSocialButton('Apple', 'apple', Colors.black,
                Colors.black, () => _handleSocialLogin('Apple'))),
        SizedBox(width: 3.w),
        Expanded(
            child: _buildSocialButton(
                'Facebook',
                'facebook',
                const Color(0xFF1877F2),
                const Color(0xFF1877F2),
                () => _handleSocialLogin('Facebook'))),
      ]),
    ]);
  }

  Widget _buildSocialButton(String text, String iconName, Color backgroundColor,
      Color borderColor, VoidCallback onPressed) {
    return SizedBox(
        height: 6.h,
        child: OutlinedButton(
            onPressed: _isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
                backgroundColor: backgroundColor,
                side: BorderSide(color: borderColor, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2.w))),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CustomIconWidget(
                  iconName: iconName == 'google'
                      ? 'g_translate'
                      : iconName == 'apple'
                          ? 'apple'
                          : 'facebook',
                  color: text == 'Google'
                      ? Colors.red
                      : text == 'Apple'
                          ? Colors.white
                          : Colors.white,
                  size: 4.w),
              SizedBox(height: 0.5.h),
              Text(text,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: text == 'Google' ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w500)),
            ])));
  }

  Widget _buildSignUpLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('New user? ',
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant)),
      TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pushNamed(context, AppRoutes.registrationScreen);
          },
          style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text('Sign Up',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.primaryColor,
                  fontWeight: FontWeight.w600))),
    ]);
  }
}