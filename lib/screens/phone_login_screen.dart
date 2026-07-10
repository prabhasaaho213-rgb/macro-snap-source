import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import 'home_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String? returnRoute;
  const PhoneLoginScreen({super.key, this.returnRoute});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController(text: '+91 ');
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _googleSignIn = GoogleSignIn(
    serverClientId: '562037381-u1ht24q03sacnkkhfohqf1jvlvjubdl3.apps.googleusercontent.com',
  );
  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;
  bool _verifying = false;
  bool _googleLoading = false;
  int _resendTimer = 0;
  String _error = '';

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _signIn(credential);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() { _loading = false; _error = e.message ?? 'OTP failed'; });
          }
        },
        codeSent: (vid, token) {
          if (mounted) {
            setState(() {
              _verificationId = vid;
              _otpSent = true;
              _loading = false;
            });
            _startResendTimer();
          }
        },
        codeAutoRetrievalTimeout: (vid) {
          _verificationId = vid;
        },
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6 || _verificationId == null) return;
    setState(() { _verifying = true; _error = ''; });
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    await _signIn(credential);
  }

  Future<void> _signIn(AuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? _phoneController.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', phone);
      try {
        await http.post(
          Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone}),
        );
      } catch (_) {}
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, phone);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) setState(() { _verifying = false; _error = 'Verification failed: ${e.toString()}'; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = ''; });
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() { _googleLoading = false; _error = 'Sign in cancelled'; });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user after sign in');

      final email = user.email ?? googleUser.email;
      final name = user.displayName ?? googleUser.displayName ?? 'User';
      final photoUrl = user.photoURL ?? googleUser.photoUrl;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone', email);
      await prefs.setString('email', email);
      await prefs.setString('name', name);
      if (photoUrl != null) await prefs.setString('photo_url', photoUrl);

      try {
        await http.post(
          Uri.parse('https://macro-snap-backend-production.up.railway.app/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': email, 'email': email, 'name': name}),
        );
      } catch (_) {}

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context, email);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) setState(() { _googleLoading = false; _error = 'Google sign in failed: ${e.toString()}'; });
    }
  }

  Future<void> _continueAsGuest() async {
    final guestId = 'guest_${Random().nextInt(999999)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', guestId);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, guestId);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  void _onOtpChange(int index, String val) {
    if (val.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight]),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text('MacroSnap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text(
                    _otpSent ? 'Enter the 6-digit code sent to your phone' : 'Sign in to continue',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 24),
                  if (_error.isNotEmpty)
                    Container(
                      width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_error, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                    ),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _googleLoading ? null : _signInWithGoogle,
                      icon: _googleLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg', width: 20, height: 20, errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 24)),
                      label: Text(_googleLoading ? 'Signing in...' : 'Sign in with Google',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _continueAsGuest,
                    child: Text('Continue as Guest',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_otpSent)
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      style: TextStyle(fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MacroSnapTheme.emerald, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  if (_otpSent) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (i) => SizedBox(
                        width: 48, height: 56,
                        child: TextField(
                          controller: _otpControllers[i],
                          focusNode: _otpFocusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MacroSnapTheme.emerald, width: 1.5)),
                          ),
                          onChanged: (v) => _onOtpChange(i, v),
                        ),
                      )),
                    ),
                    const SizedBox(height: 18),
                    if (_resendTimer > 0)
                      Text('Resend in ${_resendTimer}s', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 12))
                    else
                      InkWell(
                        onTap: _sendOtp,
                        child: Text('Resend OTP', style: TextStyle(color: MacroSnapTheme.emerald, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight]),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _loading || _verifying ? null : (_otpSent ? _verifyOtp : _sendOtp),
                          child: Center(
                            child: _loading || _verifying
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_otpSent ? 'Verify OTP' : 'Send OTP',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
