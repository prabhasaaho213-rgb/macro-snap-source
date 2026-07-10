import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upi_intent/upi_intent.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import 'phone_login_screen.dart';
import '../services/notification_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  String? _phone;
  bool _subscribed = false;
  bool _paying = false;
  String? _subscribedDate;
  final String _serverUrl = 'https://macro-snap-backend-production.up.railway.app';
  AnimationController? _animController;
  Animation<double>? _checkAnim;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    final subscribed = prefs.getBool('subscribed') ?? false;
    final date = prefs.getString('subscribed_at');
    if (mounted) {
      setState(() {
        _subscribed = subscribed;
        _phone = phone;
        _subscribedDate = date;
      });
    }
  }

  Future<void> _activateSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('subscribed_at', now);
    await prefs.setBool('subscribed', true);
    if (_phone != null) {
      try {
        await http.post(
          Uri.parse('$_serverUrl/subscribe'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': _phone}),
        );
      } catch (_) {}
    }
    final notif = NotificationService();
    await notif.showSubscribed();
    await notif.scheduleAllForSubscriber(now);
    if (mounted) {
      setState(() {
        _subscribed = true;
        _subscribedDate = now;
      });
    }
  }

  void _showConfirmation() {
    _animController?.dispose();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnim = CurvedAnimation(parent: _animController!, curve: Curves.elasticOut);
    _animController!.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AnimatedBuilder(
          animation: _checkAnim!,
          builder: (_, _) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: _checkAnim!.value,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: MacroSnapTheme.emerald, size: 56),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Welcome to Pro!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('You now have full access to all features',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MacroSnapTheme.emerald,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Start Using MacroSnap',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _payWithUpi() async {
    setState(() => _paying = true);
    try {
      final response = await UpiIntent.pay(
        context: context,
        payment: UpiPayment(
          payeeVpa: '7569086885@yespop',
          payeeName: 'MacroSnap',
          amount: 49.00,
          transactionNote: 'MacroSnap Pro Subscription',
          transactionRefId: 'MS${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      if (response == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 48),
                margin: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 40, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 48, height: 48,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: MacroSnapTheme.emerald),
                  ),
                  const SizedBox(height: 20),
                  const Text('Verifying payment...',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Please wait',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                ]),
              ),
            ),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.isSuccess) {
        await _activateSubscription();
        if (mounted) _showConfirmation();
      } else {
        final msg = response.status == UpiTransactionStatus.failure
            ? 'Payment failed. Check UPI PIN and try again.'
            : 'Payment ${response.status.name}. Try again or pay manually below.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _payWithUpi,
            ),
          ));
        }
      }
    } on UpiException catch (e) {
      final msg = e.message.contains('no UPI apps')
          ? 'No UPI apps found. Install GPay/PhonePe or pay manually via QR.'
          : e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _startLogin() async {
    final phone = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
    if (phone != null) setState(() => _phone = phone);
  }

  String _daysRemaining() {
    if (_subscribedDate == null) return '';
    final start = DateTime.parse(_subscribedDate!);
    final expiry = start.add(const Duration(days: 30));
    final remaining = expiry.difference(DateTime.now()).inDays;
    if (remaining <= 0) return 'Expired';
    if (remaining == 1) return '1 day remaining';
    return '$remaining days remaining';
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
                  boxShadow: [
                    BoxShadow(
                        color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                        blurRadius: 20, offset: const Offset(0, 6))
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                _subscribed ? 'You\'re a Pro!' : 'Unlock Full Access',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subscribed
                    ? 'Enjoy all features. $_daysRemaining'
                    : 'Everything you need to hit your goals',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 32),
              _buildFeatureRow(Icons.photo_camera_rounded, 'AI Photo Analysis',
                  'Snap & get instant macros from any meal', isDark),
              _buildFeatureRow(Icons.restaurant_rounded, 'Complete Food Database',
                  '130+ Indian dishes with accurate nutrition', isDark),
              _buildFeatureRow(Icons.bar_chart_rounded, 'Daily Macro Tracking',
                  'Protein, carbs, fats & calorie goals', isDark),
              _buildFeatureRow(Icons.history_rounded, 'Meal History',
                  'Review everything you ate', isDark),
              _buildFeatureRow(Icons.cloud_rounded, 'Cloud Backup',
                  'Your data stays safe across devices', isDark),
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
                          Text('₹',
                              style: TextStyle(fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: MacroSnapTheme.emerald)),
                          const SizedBox(width: 2),
                          Text('49',
                              style: TextStyle(fontSize: 56,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white
                                      : const Color(0xFF1E293B),
                                  letterSpacing: -2, height: 1)),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('/ month',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38
                                        : const Color(0xFF94A3B8))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subscribed && _subscribedDate != null
                            ? 'Subscribed ${_subscribedDate!.substring(0, 10)}'
                            : 'One-time payment • Unlimited access',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MacroSnapTheme.emerald.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phone != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        color: MacroSnapTheme.emerald, size: 16),
                    const SizedBox(width: 6),
                    Text('Logged in as $_phone',
                        style: TextStyle(fontSize: 13,
                            color: isDark ? Colors.white60
                                : const Color(0xFF64748B))),
                  ],
                ),
              const SizedBox(height: 24),
              if (!_subscribed) ...[
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton(
                    onPressed: _phone == null ? _startLogin : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _phone == null
                          ? MacroSnapTheme.emerald
                          : const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      _phone == null ? 'Login to Subscribe'
                          : 'Logged in as $_phone',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_phone != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: FilledButton.icon(
                      onPressed: _paying ? null : _payWithUpi,
                      icon: _paying
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payments_rounded, size: 22),
                      label: Text(
                          _paying ? 'Opening UPI...'
                              : 'Pay ₹49 with any UPI App',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: MacroSnapTheme.emerald,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Opens GPay / PhonePe / Paytm / BHIM',
                    style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white30
                            : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(
                          color: isDark ? Colors.white10
                              : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR scan & pay with any app',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white30
                                    : const Color(0xFF94A3B8))),
                      ),
                      Expanded(child: Divider(
                          color: isDark ? Colors.white10
                              : const Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isDark ? Colors.white10
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(children: [
                      QrImageView(
                        data: 'upi://pay?pa=7569086885@yespop'
                            '&pn=MacroSnap&am=49&cu=INR'
                            '&tn=MacroSnap+Pro+Subscription',
                        version: QrVersions.auto,
                        size: 180,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Scan with any UPI app to pay ₹49',
                          style: TextStyle(fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(
                          color: isDark ? Colors.white10
                              : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR pay manually & activate',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white30
                                    : const Color(0xFF94A3B8))),
                      ),
                      Expanded(child: Divider(
                          color: isDark ? Colors.white10
                              : const Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          const ClipboardData(text: '7569086885@yespop'));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('UPI ID copied!'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : MacroSnapTheme.emerald)
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: MacroSnapTheme.emerald.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded,
                              color: MacroSnapTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Text('7569086885@yespop',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white
                                    : const Color(0xFF1E293B),
                                letterSpacing: 0.5,
                              )),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_rounded,
                              color: MacroSnapTheme.emerald, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Tap to copy • Send exactly ₹49 via any UPI app',
                      style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.white30
                              : const Color(0xFF94A3B8))),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton(
                      onPressed: _activateSubscription,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MacroSnapTheme.emerald,
                        side: BorderSide(
                            color: MacroSnapTheme.emerald.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("I've Paid - Activate",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Subscribed ✓',
                        style: TextStyle(color: Color(0xFF64748B),
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('subscribed', false);
                    await prefs.remove('subscribed_at');
                    await NotificationService().cancelAll();
                    setState(() {
                      _subscribed = false;
                      _subscribedDate = null;
                    });
                  },
                  child: const Text('Cancel Subscription',
                      style: TextStyle(color: MacroSnapTheme.rose)),
                ),
              ],
              const SizedBox(height: 16),
              Text('Cancel anytime. No questions asked.',
                  style: TextStyle(fontSize: 13,
                      color: isDark ? Colors.white30
                          : const Color(0xFFCBD5E1))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: MacroSnapTheme.emerald, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white
                            : const Color(0xFF1E293B))),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white38
                            : const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: MacroSnapTheme.emerald, size: 22),
        ],
      ),
    );
  }
}
