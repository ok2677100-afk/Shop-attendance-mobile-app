// ============================================================
//  SHOP ATTENDANCE SYSTEM — main.dart
//  Flutter | Material 3 | Biometric | WiFi Geo-fence | QR
// ============================================================

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Entry Point ───────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ShopAttendanceApp());
}

// ── App Root ──────────────────────────────────────────────────
class ShopAttendanceApp extends StatelessWidget {
  const ShopAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A33D),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const AttendanceHomePage(),
    );
  }
}

// ── Colours ───────────────────────────────────────────────────
const kBg         = Color(0xFF0D1117);
const kPanel      = Color(0xFF161B26);
const kPanel2     = Color(0xFF1C2230);
const kAmber      = Color(0xFFE8A33D);
const kGreen      = Color(0xFF3DDC8A);
const kRed        = Color(0xFFE8543D);
const kPaper      = Color(0xFFF4F1EA);
const kSubtext    = Color(0xFF8B949E);
const kBorder     = Color(0xFF30363D);

// ── Receipt Data Model ────────────────────────────────────────
class ReceiptData {
  final String name;
  final String status;
  final String ssid;
  final String localIp;
  final String date;
  final String time;
  final String qrPayload;

  ReceiptData({
    required this.name,
    required this.status,
    required this.ssid,
    required this.localIp,
    required this.date,
    required this.time,
    required this.qrPayload,
  });
}

// ─────────────────────────────────────────────────────────────
//  HOME PAGE
// ─────────────────────────────────────────────────────────────
class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});
  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage>
    with SingleTickerProviderStateMixin {

  // controllers / state
  final _nameCtrl       = TextEditingController();
  final _ssidCtrl       = TextEditingController();
  final _formKey        = GlobalKey<FormState>();
  final _receiptKey     = GlobalKey();

  bool   _adminExpanded = false;
  bool   _loading       = false;
  String _statusMsg     = '';
  bool   _statusIsError = false;
  String _currentSsid   = 'Detecting…';
  String _currentIp     = 'Detecting…';
  ReceiptData? _receipt;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  final _localAuth  = LocalAuthentication();
  final _networkInfo = NetworkInfo();

  // ── lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadSavedSsid();
    _detectNetwork();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameCtrl.dispose();
    _ssidCtrl.dispose();
    super.dispose();
  }

  // ── Saved SSID ─────────────────────────────────────────────
  Future<void> _loadSavedSsid() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('allowedSsid') ?? '';
    if (saved.isNotEmpty) {
      setState(() => _ssidCtrl.text = saved);
    }
  }

  Future<void> _saveSsid() async {
    final val = _ssidCtrl.text.trim();
    if (val.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('allowedSsid', val);
    _setStatus('✔ Shop WiFi saved: "$val"', isError: false);
  }

  // ── Network Detection ──────────────────────────────────────
  Future<void> _detectNetwork() async {
    // Request location permission (Android requires it for WiFi SSID)
    final locStatus = await Permission.locationWhenInUse.request();
    if (!locStatus.isGranted) {
      setState(() {
        _currentSsid = 'Permission denied';
        _currentIp   = 'Permission denied';
      });
      return;
    }

    try {
      final ssid = await _networkInfo.getWifiName();
      final ip   = await _networkInfo.getWifiIP();
      setState(() {
        _currentSsid = (ssid ?? 'Unknown').replaceAll('"', '');
        _currentIp   = ip ?? 'Unknown';
      });
    } catch (e) {
      setState(() {
        _currentSsid = 'Error reading WiFi';
        _currentIp   = 'Error';
      });
    }
  }

  // ── Status message ─────────────────────────────────────────
  void _setStatus(String msg, {required bool isError}) {
    setState(() {
      _statusMsg    = msg;
      _statusIsError = isError;
    });
  }

  // ── Main Punch Flow ────────────────────────────────────────
  Future<void> _handlePunch(String status) async {
    // 1. Validate name
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();

    setState(() { _loading = true; _receipt = null; _statusMsg = ''; });

    try {
      // 2. Refresh network
      await _detectNetwork();

      // 3. WiFi geo-fence check
      final allowedSsid = _ssidCtrl.text.trim();
      if (allowedSsid.isEmpty) {
        _setStatus(
          '⚠ Admin: Shop WiFi SSID not configured!\n'
          'ایڈمن: شاپ WiFi نام سیٹ نہیں ہوا۔', isError: true);
        return;
      }

      final connected = _currentSsid.replaceAll('"', '').trim();
      if (connected.toLowerCase() != allowedSsid.toLowerCase()) {
        _setStatus(
          '🚫 Attendance Denied!\n'
          'حاضری مسترد! آپ شاپ کے آفیشل WiFi سے منسلک نہیں ہیں۔\n\n'
          'Connected: "$connected"\n'
          'Required:  "$allowedSsid"',
          isError: true,
        );
        return;
      }

      // 4. Biometric authentication
      final canAuth = await _localAuth.canCheckBiometrics ||
                      await _localAuth.isDeviceSupported();
      if (!canAuth) {
        _setStatus(
          '🚫 Biometric hardware not available on this device.\n'
          'اس ڈیوائس پر فنگر پرنٹ اسکینر دستیاب نہیں ہے۔',
          isError: true,
        );
        return;
      }

      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason:
              'Scan your fingerprint to record attendance\n'
              'حاضری درج کرنے کے لیے فنگر پرنٹ اسکین کریں',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            sensitiveTransaction: true,
          ),
        );
      } on PlatformException catch (e) {
        _setStatus(
          '🚫 Biometric Error: ${e.message}\n'
          'فنگر پرنٹ میں خرابی: ${e.message}',
          isError: true,
        );
        return;
      }

      if (!authenticated) {
        _setStatus(
          '🚫 Fingerprint verification failed or cancelled.\n'
          'فنگر پرنٹ تصدیق ناکام یا منسوخ۔',
          isError: true,
        );
        return;
      }

      // 5. Build receipt
      final now  = DateTime.now();
      final date = DateFormat('dd-MM-yyyy').format(now);
      final time = DateFormat('hh:mm:ss a').format(now).toUpperCase();

      final qrPayload =
          'SHOP-ATTENDANCE|'
          'NAME:$name|'
          'STATUS:$status|'
          'WIFI:$_currentSsid|'
          'IP:$_currentIp|'
          'DATE:$date|'
          'TIME:$time|'
          'TS:${now.millisecondsSinceEpoch}';

      setState(() {
        _receipt = ReceiptData(
          name: name,
          status: status,
          ssid: _currentSsid,
          localIp: _currentIp,
          date: date,
          time: time,
          qrPayload: qrPayload,
        );
        _statusMsg = '';
      });

    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Download Receipt ───────────────────────────────────────
  Future<void> _downloadReceipt() async {
    // Request storage permission
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    try {
      final boundary = _receiptKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _setStatus('❌ Could not capture receipt.', isError: true);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: 'attendance_$ts',
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _setStatus('✅ Receipt saved to Gallery!\nرسید گیلری میں محفوظ ہو گئی!',
            isError: false);
      } else {
        _setStatus('❌ Failed to save. Check storage permission.',
            isError: true);
      }
    } catch (e) {
      _setStatus('❌ Error: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildNetworkStrip(),
              const SizedBox(height: 12),
              _buildAdminPanel(),
              const SizedBox(height: 12),
              _buildMainCard(),
              if (_statusMsg.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildStatusBanner(),
              ],
              if (_receipt != null) ...[
                const SizedBox(height: 20),
                RepaintBoundary(
                  key: _receiptKey,
                  child: _ReceiptCard(data: _receipt!),
                ),
                const SizedBox(height: 14),
                _buildDownloadBtn(),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: kAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAmber.withOpacity(0.3)),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: kAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop Attendance',
                  style: TextStyle(
                    color: kPaper, fontSize: 16,
                    fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                Text('شاپ حاضری سسٹم',
                  style: TextStyle(
                    color: kSubtext, fontSize: 12,
                    fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          _LiveClock(),
        ],
      ),
    );
  }

  // ── Network Strip ──────────────────────────────────────────
  Widget _buildNetworkStrip() {
    final isKnown = _currentSsid != 'Detecting…'
        && _currentSsid != 'Unknown'
        && _currentSsid != 'Permission denied'
        && !_currentSsid.startsWith('Error');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: isKnown ? kGreen : kAmber,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (isKnown ? kGreen : kAmber).withOpacity(0.6),
                    blurRadius: 6)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.wifi_rounded, color: kSubtext, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _currentSsid,
              style: TextStyle(
                color: isKnown ? kGreen : kAmber,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currentIp,
            style: const TextStyle(
              color: kSubtext, fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _detectNetwork,
            child: const Icon(Icons.refresh_rounded,
                color: kSubtext, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Admin Panel ────────────────────────────────────────────
  Widget _buildAdminPanel() {
    return Container(
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _adminExpanded = !_adminExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.settings_rounded,
                      color: kSubtext, size: 16),
                  const SizedBox(width: 8),
                  const Text('Admin: Shop WiFi Config',
                    style: TextStyle(color: kSubtext, fontSize: 12,
                        fontFamily: 'monospace')),
                  const Spacer(),
                  Icon(
                    _adminExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kSubtext, size: 18),
                ],
              ),
            ),
          ),
          if (_adminExpanded) ...[
            const Divider(color: kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Allowed Shop WiFi Name (SSID)',
                    style: TextStyle(
                        color: kSubtext, fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ssidCtrl,
                          style: const TextStyle(
                              color: kPaper,
                              fontSize: 13,
                              fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: 'e.g. ShopNetwork_5G',
                            hintStyle: const TextStyle(
                                color: kSubtext, fontSize: 12),
                            filled: true,
                            fillColor: kBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: kAmber, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveSsid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAmber,
                          foregroundColor: kBg,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('SAVE',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: kSubtext, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Current device WiFi: "$_currentSsid"\n'
                          'Tap above to use this value.',
                          style: const TextStyle(
                              color: kSubtext, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _ssidCtrl.text = _currentSsid;
                        },
                        child: const Text('Use Current',
                          style: TextStyle(color: kAmber, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Main Card ──────────────────────────────────────────────
  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employee Attendance',
              style: TextStyle(
                color: kPaper, fontSize: 20,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('ملازم حاضری',
              style: TextStyle(color: kSubtext, fontSize: 13)),
            const SizedBox(height: 20),

            // Name field
            const Text('Employee Name  •  ملازم کا نام',
              style: TextStyle(
                color: kSubtext, fontSize: 11,
                fontFamily: 'monospace', letterSpacing: 0.4)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: kPaper, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type your full name — اپنا پورا نام لکھیں',
                hintStyle: const TextStyle(color: kSubtext, fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline_rounded,
                    color: kSubtext),
                filled: true,
                fillColor: kBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kAmber, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kRed),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'نام درج کریں — Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Punch buttons
            Row(
              children: [
                Expanded(
                  child: _PunchButton(
                    label: 'CHECK IN',
                    sublabel: 'حاضر',
                    color: kGreen,
                    icon: Icons.login_rounded,
                    loading: _loading,
                    onTap: () => _handlePunch('CHECKED IN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PunchButton(
                    label: 'CHECK OUT',
                    sublabel: 'رخصت',
                    color: kRed,
                    icon: Icons.logout_rounded,
                    loading: _loading,
                    onTap: () => _handlePunch('CHECKED OUT'),
                  ),
                ),
              ],
            ),

            // Fingerprint hint
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint_rounded,
                      color: kSubtext, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Biometric verification required  •  فنگر پرنٹ ضروری',
                    style: const TextStyle(
                        color: kSubtext, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Banner ──────────────────────────────────────────
  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_statusIsError ? kRed : kGreen).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_statusIsError ? kRed : kGreen).withOpacity(0.35)),
      ),
      child: Text(
        _statusMsg,
        style: TextStyle(
          color: _statusIsError ? kRed : kGreen,
          fontSize: 13, height: 1.55),
      ),
    );
  }

  // ── Download Button ────────────────────────────────────────
  Widget _buildDownloadBtn() {
    return ElevatedButton.icon(
      onPressed: _downloadReceipt,
      icon: const Icon(Icons.download_rounded),
      label: const Text(
        'Download / Share Receipt  •  رسید محفوظ کریں',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: kAmber,
        foregroundColor: kBg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LIVE CLOCK WIDGET
// ─────────────────────────────────────────────────────────────
class _LiveClock extends StatefulWidget {
  @override
  State<_LiveClock> createState() => _LiveClockState();
}
class _LiveClockState extends State<_LiveClock> {
  late String _time;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _time = DateFormat('hh:mm:ss a').format(DateTime.now()).toUpperCase();
    });
    Future.delayed(const Duration(seconds: 1), _tick);
  }

  @override
  Widget build(BuildContext context) => Text(
    _time,
    style: const TextStyle(
      color: kSubtext,
      fontSize: 11,
      fontFamily: 'monospace'),
  );
}

// ─────────────────────────────────────────────────────────────
//  PUNCH BUTTON
// ─────────────────────────────────────────────────────────────
class _PunchButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _PunchButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      color: color, strokeWidth: 2.5),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 6),
                    Text(label,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(sublabel,
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 11)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RECEIPT CARD WIDGET
// ─────────────────────────────────────────────────────────────
class _ReceiptCard extends StatelessWidget {
  final ReceiptData data;
  const _ReceiptCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isCheckIn = data.status == 'CHECKED IN';
    final statusColor = isCheckIn ? kGreen : kRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.12),
            blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          // ── Header strip ──
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: kBorder.withOpacity(0.6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SHOP ATTENDANCE',
                      style: TextStyle(
                        color: kAmber,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('RECEIPT',
                      style: TextStyle(
                        color: kAmber,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        letterSpacing: 2.5)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    isCheckIn ? '✔ CHECKED IN' : '✔ CHECKED OUT',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Ledger rows ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ledger('EMPLOYEE', data.name),
                _ledger('STATUS', data.status),
                _ledger('WIFI SSID', data.ssid),
                _ledger('LOCAL IP', data.localIp),
                _ledger('DATE', data.date),
                _ledger('TIME', data.time),
              ],
            ),
          ),

          // ── Perforated divider ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: List.generate(
                30,
                (i) => Expanded(
                  child: Container(
                    height: 1,
                    color: i.isEven
                        ? kBorder.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          // ── QR Code ──
          Padding(
            padding: const EdgeInsets.only(
                left: 20, right: 20, bottom: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: QrImageView(
                    data: data.qrPayload,
                    version: QrVersions.auto,
                    size: 150,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0A0D13),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0A0D13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SCAN TO VERIFY AUTHENTICITY',
                  style: TextStyle(
                    color: kSubtext,
                    fontSize: 9,
                    fontFamily: 'monospace',
                    letterSpacing: 2),
                ),
                const SizedBox(height: 2),
                const Text(
                  'تصدیق کے لیے QR کوڈ اسکین کریں',
                  style: TextStyle(color: kSubtext, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledger(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: kBorder, width: 0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: const TextStyle(
              color: kSubtext,
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 0.5)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kPaper,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
