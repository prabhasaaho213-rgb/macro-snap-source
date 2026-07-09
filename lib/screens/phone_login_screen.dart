import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;
  bool _verifying = false;
  int _resendTimer = 0;

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
      _showSnack('Enter a valid phone number');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _signIn(credential);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _loading = false);
            _showSnack('OTP failed: ${e.message}');
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
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Error: $e');
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6 || _verificationId == null) return;
    setState(() => _verifying = true);
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    await _signIn(credential);
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
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
      if (mounted) {
        setState(() => _verifying = false);
        _showSnack('Verification failed: ${e.toString()}');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onOtpChange(int index, String val) {
    if (val.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.phone_android_rounded, color: MacroSnapTheme.emerald, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                _otpSent ? 'Enter OTP' : 'Enter your mobile number',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent ? '6-digit code sent to ${_phoneController.text.trim()}' : 'Your number will be used for subscription',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 32),
              if (!_otpSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                ),
              if (_otpSent) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) => SizedBox(
                    width: 52, height: 64,
                    child: TextField(
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                      onChanged: (v) => _onOtpChange(i, v),
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                if (_resendTimer > 0)
                  Center(
                    child: Text('Resend in ${_resendTimer}s',
                      style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                else
                  Center(
                    child: TextButton(
                      onPressed: _sendOtp,
                      child: const Text('Resend OTP', style: TextStyle(color: MacroSnapTheme.emerald)),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: FilledButton(
                  onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: MacroSnapTheme.emerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _loading || _verifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_otpSent ? 'Verify OTP' : 'Send OTP',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}