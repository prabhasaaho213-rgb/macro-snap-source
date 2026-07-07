import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import 'phone_login_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final Razorpay _razorpay = Razorpay();
  String? _phone;
  bool _subscribed = false;
  bool _paying = false;
  String _serverUrl = 'https://macro-snap-backend-production.up.railway.app';

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _subscribed = prefs.getBool('subscribed') ?? false);
  }

  Future<void> _activateSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('subscribed', true);
    if (mounted) {
      setState(() => _subscribed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Welcome to MacroSnap Pro!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final verifyRes = await http.post(
        Uri.parse('$_serverUrl/verify-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );
      final data = jsonDecode(verifyRes.body);
      if (data['subscribed'] == true) {
        await _activateSubscription();
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: MacroSnapTheme.rose),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Payment failed'),
          backgroundColor: MacroSnapTheme.rose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${response.walletName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startLogin() async {
    final phone = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
    if (phone != null) setState(() => _phone = phone);
  }

  Future<void> _payViaRazorpay() async {
    setState(() => _paying = true);
    try {
      final keyRes = await http.get(Uri.parse('$_serverUrl/razorpay-key'));
      final keyData = jsonDecode(keyRes.body);

      final orderRes = await http.post(
        Uri.parse('$_serverUrl/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': 1}),
      );
      final order = jsonDecode(orderRes.body);

      _razorpay.open({
        'key': keyData['keyId'],
        'amount': order['amount'],
        'currency': order['currency'],
        'name': 'MacroSnap',
        'description': 'Pro Subscription',
        'order_id': order['id'],
        'prefill': {'contact': _phone ?? '', 'email': ''},
        'theme': {'color': '#059669'},
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: MacroSnapTheme.rose),
        );
      }
    } finally {
      setState(() => _paying = false);
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
        title: const Text('MacroSnap Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                  ),
                  boxShadow: [BoxShadow(color: MacroSnapTheme.emerald.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'Unlock Full Access',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything you need to hit your goals',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 32),
              _buildFeatureRow(Icons.photo_camera_rounded, 'AI Photo Analysis', 'Snap & get instant macros from any meal', isDark),
              _buildFeatureRow(Icons.restaurant_rounded, 'Complete Food Database', '130+ Indian dishes with accurate nutrition', isDark),
              _buildFeatureRow(Icons.bar_chart_rounded, 'Daily Macro Tracking', 'Protein, carbs, fats & calorie goals', isDark),
              _buildFeatureRow(Icons.history_rounded, 'Meal History', 'Review everything you ate', isDark),
              _buildFeatureRow(Icons.cloud_rounded, 'Cloud Backup', 'Your data stays safe across devices', isDark),
              const SizedBox(height: 32),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: MacroSnapTheme.emerald)),
                          const SizedBox(width: 2),
                          Text('1', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B), letterSpacing: -2, height: 1)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('/ month', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('That\'s just ₹0.03 per day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: MacroSnapTheme.emerald.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phone != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: MacroSnapTheme.emerald, size: 16),
                    const SizedBox(width: 6),
                    Text('Logged in as $_phone', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                  ],
                ),
              const SizedBox(height: 24),
              if (!_subscribed) ...[
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton(
                    onPressed: _phone == null ? _startLogin : (_paying ? null : _payViaRazorpay),
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.emerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _paying
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _phone == null ? 'Login to Subscribe' : 'Pay ₹1 via Razorpay',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                if (_phone != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'UPI, Cards, Netbanking & Wallets accepted',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white30 : const Color(0xFF94A3B8))),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Pay via UPI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  _upiButton('Google Pay', 'com.google.android.apps.nbu.paisa.user', isDark),
                  const SizedBox(height: 10),
                  _upiButton('PhonePe', 'com.phonepe.app', isDark),
                  const SizedBox(height: 10),
                  _upiButton('Paytm', 'net.one97.paytm', isDark),
                  const SizedBox(height: 10),
                  _upiButton('BHIM', 'in.org.npci.upiapp', isDark),
                  const SizedBox(height: 16),
                  Text('After payment, tap below to activate', style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton(
                      onPressed: _activateSubscription,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MacroSnapTheme.emerald,
                        side: BorderSide(color: MacroSnapTheme.emerald.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("I've Paid - Activate", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
              if (_subscribed) ...[
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Subscribed ✓', style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('subscribed', false);
                    setState(() => _subscribed = false);
                  },
                  child: const Text('Cancel Subscription', style: TextStyle(color: MacroSnapTheme.rose)),
                ),
              ],
              const SizedBox(height: 16),
              Text('Cancel anytime. No questions asked.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upiButton(String name, String package, bool isDark) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton(
        onPressed: () async {
          final uri = Uri.parse('upi://pay?pa=7569086885@yespop&pn=MacroSnap&am=1&cu=INR&tn=MacroSnap+Pro+Subscription');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            try {
              final playUri = Uri.parse('https://play.google.com/store/apps/details?id=$package');
              if (await canLaunchUrl(playUri)) {
                await launchUrl(playUri, mode: LaunchMode.externalApplication);
              }
            } catch (_) {}
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          side: BorderSide(color: isDark ? Colors.white30 : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_rounded, size: 20, color: MacroSnapTheme.emerald),
            const SizedBox(width: 8),
            Text('$name', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: MacroSnapTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: MacroSnapTheme.emerald, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: MacroSnapTheme.emerald, size: 22),
        ],
      ),
    );
  }
}