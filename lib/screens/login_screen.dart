import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import '../main.dart'; // To access AppColors

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);
  try {
    // We already initialized in main(), so just use the instance
    final googleSignIn = GoogleSignIn.instance;

    // Start the sign-in flow directly
    final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
    
    if (googleUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Request Access Token
    final clientAuth = await googleUser.authorizationClient.authorizeScopes([
      'email', 
      'profile',
      'openid',
    ]);

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: clientAuth.accessToken,
      idToken: googleUser.authentication.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  } catch (e) {
    _showError('Authentication error: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo Wrapper
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Welcome Typography
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to sync your 75 Hard progress',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // ──────────────────────────────────────────────────────────
                    // GOOGLE SIGN-IN INTERACTION LAYER (CROSS-PLATFORM SAFE)
                    // ──────────────────────────────────────────────────────────
                    if (kIsWeb)
                      // 🌐 WEB ROUTE: Render the mandatory Google GIS JavaScript Button
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: web.renderButton(
                            configuration: web.GSIButtonConfiguration(
                              type: web.GSIButtonType.standard,
                              theme: web.GSIButtonTheme.filledBlue,
                              size: web.GSIButtonSize.large,
                              text: web.GSIButtonText.continueWith,
                              shape: web.GSIButtonShape.rectangular,
                            ),
                          ),
                        ),
                      )
                    else
                      // 📱 NATIVE ROUTE: Custom ElevatedButton for Mobile Devices
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.login, size: 20),
                          label: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}