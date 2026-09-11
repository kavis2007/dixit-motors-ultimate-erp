import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'services/local_store.dart';
import 'services/sync_service.dart';

const brandRed = Color(0xFFE31B23);
const bg = Color(0xFF070708);
const panel = Color(0xFF111216);
const silver = Color(0xFFD8D8DC);

class ModuleDef {
  final String key;
  final String title;
  final IconData icon;
  final String colorHex;
  final String description;

  const ModuleDef({
    required this.key,
    required this.title,
    required this.icon,
    required this.colorHex,
    required this.description,
  });

  Color get accent =>
      Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000);
}

const moduleDefs = <ModuleDef>[
  ModuleDef(
    key: 'device_management',
    title: 'Device Management',
    icon: Icons.devices_other_rounded,
    colorHex: '#EF4444',
    description:
        'Manage connected devices, block/unblock access and monitor last seen.',
  ),
  ModuleDef(
    key: 'customers',
    title: 'Customers',
    icon: Icons.person_pin_rounded,
    colorHex: '#E31B23',
    description: 'Customer master and connected vehicle history.',
  ),
  ModuleDef(
    key: 'vehicles',
    title: 'Vehicles',
    icon: Icons.directions_car_filled_rounded,
    colorHex: '#BFC4CC',
    description: 'Vehicle 360 - KM, photos and service history.',
  ),
  ModuleDef(
    key: 'bookings',
    title: 'Bookings',
    icon: Icons.event_available_rounded,
    colorHex: '#FF5A5F',
    description: 'Appointments and workshop planning.',
  ),
  ModuleDef(
    key: 'jobs',
    title: 'Job Cards',
    icon: Icons.car_repair_rounded,
    colorHex: '#FF3038',
    description: 'Workshop workflow and work records.',
  ),
  ModuleDef(
    key: 'inspections',
    title: 'Inspections',
    icon: Icons.fact_check_rounded,
    colorHex: '#F59E0B',
    description: 'Digital inspection checklist and findings.',
  ),
  ModuleDef(
    key: 'team',
    title: 'Workshop Team',
    icon: Icons.engineering_rounded,
    colorHex: '#A855F7',
    description: 'Staff, skills and allocation.',
  ),
  ModuleDef(
    key: 'attendance',
    title: 'Staff Attendance',
    icon: Icons.how_to_reg_rounded,
    colorHex: '#EC4899',
    description: 'Daily attendance, late marks and leave.',
  ),
  ModuleDef(
    key: 'services',
    title: 'Services',
    icon: Icons.build_circle_rounded,
    colorHex: '#22C55E',
    description: 'Service master and rates.',
  ),
  ModuleDef(
    key: 'inventory',
    title: 'Inventory',
    icon: Icons.inventory_2_rounded,
    colorHex: '#06B6D4',
    description: 'Parts stock and minimum-level alerts.',
  ),
  ModuleDef(
    key: 'purchases',
    title: 'Purchases',
    icon: Icons.shopping_cart_checkout_rounded,
    colorHex: '#14B8A6',
    description: 'Supplier purchases and stock intake.',
  ),
  ModuleDef(
    key: 'suppliers',
    title: 'Suppliers',
    icon: Icons.local_shipping_rounded,
    colorHex: '#8B5CF6',
    description: 'Supplier directory and purchase history.',
  ),
  ModuleDef(
    key: 'estimates',
    title: 'Estimates',
    icon: Icons.request_quote_rounded,
    colorHex: '#F97316',
    description: 'Quotations and approvals.',
  ),
  ModuleDef(
    key: 'invoices',
    title: 'Invoices',
    icon: Icons.receipt_long_rounded,
    colorHex: '#EF4444',
    description: 'Professional PDF invoices.',
  ),
  ModuleDef(
    key: 'payments',
    title: 'Payments',
    icon: Icons.account_balance_wallet_rounded,
    colorHex: '#10B981',
    description: 'Collections, partials and balances.',
  ),
  ModuleDef(
    key: 'expenses',
    title: 'Expenses',
    icon: Icons.money_off_csred_rounded,
    colorHex: '#F43F5E',
    description: 'Workshop expense tracking.',
  ),
  ModuleDef(
    key: 'reports',
    title: 'Reports',
    icon: Icons.assessment_rounded,
    colorHex: '#60A5FA',
    description: 'Daily, monthly and annual reports.',
  ),
  ModuleDef(
    key: 'analytics',
    title: 'Analytics',
    icon: Icons.insights_rounded,
    colorHex: '#38BDF8',
    description: 'Live business intelligence.',
  ),
  ModuleDef(
    key: 'reminders',
    title: 'Service Reminders',
    icon: Icons.notifications_active_rounded,
    colorHex: '#EAB308',
    description: 'Upcoming vehicle service reminders.',
  ),
];

Future<void> _safeBackgroundSync() async {
  try {
    await SyncService.sync();
  } catch (e, stackTrace) {
    debugPrint('Background sync failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Map<String, dynamic> _decodeJsonMap(http.Response response, String operation) {
  var text = utf8.decode(response.bodyBytes, allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) text = text.substring(1);
  text = text.trim();
  if (text.isEmpty) {
    throw Exception(
      '$operation returned an empty response (HTTP ${response.statusCode}).',
    );
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw Exception(
        '$operation returned unexpected JSON (HTTP ${response.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(decoded);
  } on FormatException {
    final preview = text.length > 300 ? '${text.substring(0, 300)}...' : text;

    throw Exception(
      '$operation returned non-JSON data (HTTP ${response.statusCode}). Response: $preview',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init(moduleDefs.map((e) => e.key).toList());
  runApp(const DixitMotorsApp());
}

class DixitMotorsApp extends StatelessWidget {
  const DixitMotorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dixit Motors Management App',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandRed,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;
  Timer? _syncTimer;
  bool syncing = false;
  String syncMessage = '';

  @override
  void initState() {
    super.initState();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _autoSync(),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoSync() async {
    if (syncing) return;

    try {
      debugPrint('AUTO DEBUG: before isConfigured');
      final configured = await SyncService.isConfigured();
      debugPrint('AUTO DEBUG: isConfigured=$configured');

      if (!configured) return;

      debugPrint('AUTO DEBUG: before safeBackgroundSync');
      await _safeBackgroundSync();
      debugPrint('AUTO DEBUG: safeBackgroundSync completed');

      if (mounted) {
        setState(() {
          syncMessage =
              'Cloud sync checked | ${DateFormat('hh:mm a').format(DateTime.now())}';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('AUTO DEBUG: EXCEPTION TYPE=${e.runtimeType}');
      debugPrint('Auto sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _manualSync() async {
    setState(() => syncing = true);
    try {
      final message = await SyncService.sync();
      if (mounted) setState(() => syncMessage = message);
    } catch (e, stackTrace) {
      debugPrint('MANUAL CLOUD SYNC ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      String friendly;
      if (e is FormatException) {
        friendly =
            'Cloud Sync received an invalid server response. '
            'Please retry after the server is ready.';
      } else {
        final raw = e.toString();
        friendly = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
      }

      if (mounted) {
        setState(() => syncMessage = 'Sync error: $friendly');
      }
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/dixit_workshop_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(.24),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF0070708), Color(0xFF070708)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) =>
                  c.maxWidth < 760 ? _mobile(c.maxWidth) : _desktop(c.maxWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktop(double width) {
    return Row(
      children: [
        SizedBox(width: 255, child: _sidebar()),
        Expanded(child: _pageContent(width - 255)),
      ],
    );
  }

  Widget _mobile(double width) {
    return Column(
      children: [
        _mobileHeader(),
        Expanded(child: _pageContent(width)),
        _mobileBottomBar(),
      ],
    );
  }

  Widget _sidebar() {
    return Container(
      color: const Color(0xE60B0C0F),
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/app_icon.png', height: 72),
          const SizedBox(height: 8),
          const Text(
            'DIXIT MOTORS',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const Text(
            'DIXIT MOTORS MANAGEMENT APP',
            style: TextStyle(color: silver, fontSize: 9, letterSpacing: 1.4),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _sideItem(Icons.dashboard_rounded, 'Dashboard', 0),
                ...List.generate(
                  moduleDefs.length,
                  (i) =>
                      _sideItem(moduleDefs[i].icon, moduleDefs[i].title, i + 1),
                ),
                _sideItem(Icons.document_scanner_rounded, 'Plate Scanner', 900),
                _sideItem(Icons.search_rounded, 'Global Search', 903),
                _sideItem(Icons.cloud_sync_rounded, 'Cloud Sync', 901),
                _sideItem(Icons.settings_rounded, 'Settings', 902),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideItem(IconData icon, String title, int value) {
    final active = selected == value;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        selected: active,
        selectedTileColor: const Color(0x22E31B23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 20, color: active ? brandRed : silver),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        onTap: () => setState(() => selected = value),
      ),
    );
  }

  Widget _mobileHeader() {
    return Container(
      padding: const EdgeInsets.all(11),
      color: const Color(0xEA0B0C0F),
      child: Row(
        children: [
          Image.asset('assets/app_icon.png', height: 46, width: 46),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIXIT MOTORS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'DIXIT MOTORS MANAGEMENT APP',
                  style: TextStyle(
                    color: silver,
                    fontSize: 8,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => selected = 900),
            tooltip: 'Plate Scanner',
            icon: const Icon(Icons.document_scanner_outlined, color: brandRed),
          ),
          IconButton(
            onPressed: _showMobileMenu,
            tooltip: 'All options',
            icon: const Icon(Icons.menu_rounded, color: silver),
          ),
        ],
      ),
    );
  }

  void _showMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  'DIXIT MOTORS OPTIONS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _mobileMenuItem(
                sheetContext,
                Icons.dashboard_outlined,
                'Dashboard',
                0,
              ),
              ...moduleDefs.asMap().entries.map(
                (e) => _mobileMenuItem(
                  sheetContext,
                  Icons.chevron_right_rounded,
                  e.value.title,
                  e.key + 1,
                ),
              ),
              _mobileMenuItem(
                sheetContext,
                Icons.document_scanner_outlined,
                'Plate Scanner',
                900,
              ),
              _mobileMenuItem(
                sheetContext,
                Icons.search_rounded,
                'Global Search',
                903,
              ),
              _mobileMenuItem(
                sheetContext,
                Icons.cloud_sync_rounded,
                'Cloud Sync',
                901,
              ),
              _mobileMenuItem(
                sheetContext,
                Icons.settings_outlined,
                'Settings',
                902,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileMenuItem(
    BuildContext sheetContext,
    IconData icon,
    String title,
    int value,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: selected == value ? brandRed : silver),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected == value ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: silver,
      ),
      onTap: () {
        Navigator.pop(sheetContext);
        setState(() => selected = value);
      },
    );
  }

  Widget _mobileBottomBar() {
    return Container(
      height: 65,
      color: const Color(0xF20B0C0F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(0, Icons.dashboard_outlined, 'Home'),
          _bottomItem(3, Icons.directions_car_outlined, 'Vehicles'),
          _bottomItem(5, Icons.build_outlined, 'Jobs'),
          _bottomItem(14, Icons.receipt_long_outlined, 'Billing'),
          _bottomItem(902, Icons.settings_outlined, 'More'),
        ],
      ),
    );
  }

  Widget _bottomItem(int value, IconData icon, String label) {
    final active = selected == value;
    return InkWell(
      onTap: () => setState(() => selected = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: active ? brandRed : silver),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: active ? brandRed : silver),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageContent(double width) {
    if (selected == 0) {
      return _dashboard(width);
    }

    if (selected == 900) {
      return ScannerPage(onBack: () => setState(() => selected = 0));
    }

    if (selected == 903) {
      return GlobalSearchPage(onBack: () => setState(() => selected = 0));
    }

    if (selected == 901) {
      return SyncPage(onBack: () => setState(() => selected = 0));
    }

    if (selected == 902) {
      return SettingsPage(onBack: () => setState(() => selected = 0));
    }

    final index = selected - 1;

    if (index >= 0 && index < moduleDefs.length) {
      final key = moduleDefs[index].key;

      if (key == 'attendance') {
        return AttendancePage(onBack: () => setState(() => selected = 0));
      }
      if (key == 'device_management') {
        return DeviceManagementPage(onBack: () => setState(() => selected = 0));
      }
      return ModulePage(
        definition: moduleDefs[index],
        onBack: () => setState(() => selected = 0),
      );
    }
    return _dashboard(width);
  }

  Widget _dashboard(double width) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(width < 700 ? 14 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 620;
              final title = const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workshop Command Center',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dixit Sharma / Ashok Sharma | Dixit Motors Management App managed by Kavi Sharma',
                    style: TextStyle(color: silver, fontSize: 12),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: syncing ? null : _manualSync,
                      icon: const Icon(Icons.cloud_sync),
                      label: Text(syncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: syncing ? null : _manualSync,
                    icon: const Icon(Icons.cloud_sync),
                    label: Text(syncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ],
              );
            },
          ),
          if (syncMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                syncMessage,
                style: const TextStyle(color: silver, fontSize: 11),
              ),
            ),
          const SizedBox(height: 20),
          _hero(width),
          const SizedBox(height: 18),
          _metrics(width),
          const SizedBox(height: 22),
          _quickActions(),
          const SizedBox(height: 22),
          _workflow(),
          const SizedBox(height: 22),
          _businessSnapshot(width),
        ],
      ),
    );
  }

  Widget _hero(double width) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF191A1F), Color(0xFF0D0E11)],
        ),
        border: Border.all(color: const Color(0x55E31B23)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIXIT MOTORS MANAGEMENT APP',
                  style: TextStyle(
                    color: brandRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One vehicle. One complete digital file.',
                  style: TextStyle(
                    fontSize: width < 600 ? 22 : 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Offline-first workshop management with connected customer, vehicle, job, inventory, billing and payment data.',
                  style: TextStyle(color: silver, height: 1.45),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge('OFFLINE-FIRST'),
                    _badge('LIVE SYNC'),
                    _badge('OCR PLATE'),
                    _badge('7+ DEVICES'),
                  ],
                ),
              ],
            ),
          ),
          if (width > 700) ...[
            const SizedBox(width: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/app_icon.png',
                width: 170,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x221F2937),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x334B5563)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _metrics(double width) {
    final data = [
      (
        'Vehicles',
        _count('vehicles'),
        Icons.directions_car,
        const Color(0xFFBFC4CC),
      ),
      ('Customers', _count('customers'), Icons.people, brandRed),
      ('Open Jobs', _openJobs(), Icons.build, const Color(0xFFFF3038)),
      (
        'Unpaid Invoices',
        _countUnpaid(),
        Icons.payments,
        const Color(0xFFF59E0B),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width < 560 ? 2 : 4,
        childAspectRatio: width < 560 ? 1.45 : 2.05,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, i) =>
          _metric(data[i].$1, data[i].$2.toString(), data[i].$3, data[i].$4),
    );
  }

  int _count(String key) =>
      LocalStore.get(key).where((e) => e['_deleted'] != true).length;
  int _openJobs() => LocalStore.get('jobs')
      .where(
        (e) =>
            e['_deleted'] != true &&
            !['Completed', 'Delivered', 'Cancelled'].contains(e['Job Status']),
      )
      .length;
  int _countUnpaid() => LocalStore.get(
    'invoices',
  ).where((e) => e['_deleted'] != true && e['Payment Status'] != 'Paid').length;

  Widget _metric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          Text(title, style: const TextStyle(color: silver, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _quick('New Customer', 2),
            _quick('New Vehicle', 3),
            _quick('New Job Card', 5),
            _quick('New Invoice', 14),
            _quick('Scan Plate', 900),
          ],
        ),
      ],
    );
  }

  Widget _quick(String title, int page) => OutlinedButton.icon(
    onPressed: () => setState(() => selected = page),
    icon: const Icon(Icons.add_circle_outline, size: 17),
    label: Text(title),
  );

  Widget _workflow() {
    const stages = [
      'Received',
      'Inspection',
      'Estimate',
      'Approved',
      'Work In Progress',
      'Quality Check',
      'Ready',
      'Delivered',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Workshop Workflow',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stages.map((stage) {
                final count = LocalStore.get('jobs')
                    .where(
                      (job) =>
                          job['Job Status'] == stage && job['_deleted'] != true,
                    )
                    .length;
                return Container(
                  width: 135,
                  margin: const EdgeInsets.only(right: 9),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18191D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: brandRed,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessSnapshot(double width) {
    final revenue = LocalStore.get('payments')
        .where((e) => e['_deleted'] != true)
        .fold<double>(
          0,
          (sum, e) =>
              sum + (double.tryParse(e['Amount']?.toString() ?? '') ?? 0),
        );
    final stockLow = LocalStore.get('inventory')
        .where(
          (e) =>
              e['_deleted'] != true &&
              (double.tryParse(e['Quantity']?.toString() ?? '') ?? 0) <=
                  (double.tryParse(e['Minimum Stock']?.toString() ?? '') ?? 0),
        )
        .length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _infoPanel(
            'Collections',
            'Rs. ${revenue.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined,
            brandRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoPanel(
            'Low Stock',
            stockLow.toString(),
            Icons.inventory_2_outlined,
            const Color(0xFFF59E0B),
          ),
        ),
        if (width > 650) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _infoPanel(
              'Team Members',
              _count('team').toString(),
              Icons.groups_outlined,
              const Color(0xFFA855F7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoPanel(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: silver, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModulePage extends StatefulWidget {
  final ModuleDef definition;
  final VoidCallback? onBack;
  const ModulePage({super.key, required this.definition, this.onBack});

  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final records = LocalStore.get(widget.definition.key)
        .where((r) => r['_deleted'] != true)
        .where((r) => jsonEncode(r).toLowerCase().contains(query.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.definition.icon,
                          color: widget.definition.accent,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.definition.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.definition.description,
                      style: const TextStyle(color: silver, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search ${widget.definition.title.toLowerCase()}',
            ),
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            _empty()
          else
            ...records.map((r) => _recordCard(r)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: silver),
          SizedBox(height: 8),
          Text(
            'No records yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Use Add to create the first record.',
            style: TextStyle(color: silver),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final keys = record.keys.where((k) => !k.startsWith('_')).take(7).toList();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final details = Wrap(
      spacing: 16,
      runSpacing: 10,
      children: keys
          .map(
            (k) => SizedBox(
              width: compact ? 135 : 145,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: const TextStyle(color: silver, fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(
                    record[k]?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
    final actions = Wrap(
      spacing: 2,
      children: [
        IconButton(
          onPressed: () => _edit(record),
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
        ),
        if (widget.definition.key == 'invoices') ...[
          IconButton(
            tooltip: 'PDF / Print',
            onPressed: () => _invoicePdf(record),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: () => _invoicePdf(record, share: true),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
        IconButton(
          onPressed: () => _delete(record),
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline, color: brandRed),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: widget.definition.accent.withAlpha(55)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                actions,
              ],
            ),
    );
  }

  Future<void> _add() async {
    final result = widget.definition.key == 'invoices'
        ? await showInvoiceEditor(context)
        : await showRecordDialog(context, widget.definition);
    if (result == null) return;
    await LocalStore.upsert(widget.definition.key, result);
    await _log('Created ${widget.definition.title}');
    if (mounted) setState(() {});
    unawaited(_safeBackgroundSync());
  }

  Future<void> _edit(Map<String, dynamic> record) async {
    final result = widget.definition.key == 'invoices'
        ? await showInvoiceEditor(context, initial: record)
        : await showRecordDialog(context, widget.definition, initial: record);
    if (result == null) return;
    result['_id'] = record['_id'];
    await LocalStore.upsert(widget.definition.key, result);
    await _log('Updated ${widget.definition.title}');
    if (mounted) setState(() {});
    unawaited(_safeBackgroundSync());
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    if (!await confirmDialog(context, 'Delete this record?')) return;
    await LocalStore.remove(widget.definition.key, record['_id'].toString());
    await _log('Deleted ${widget.definition.title}');
    if (mounted) setState(() {});
    unawaited(_safeBackgroundSync());
  }

  Future<void> _log(String action) async {
    // Activity/Audit Log is intentionally removed from the Management App.
    // Keep this helper so existing create/edit/delete flows remain compatible.
  }

  Future<void> _invoicePdf(Map<String, dynamic> r, {bool share = false}) async {
    final logo = await _assetBytes('assets/invoice_logo.png');
    final signature = await _assetBytes(
      'assets/dixit_authorized_signature.png',
    );
    final doc = pw.Document();
    final items = _invoiceItems(r['Items']);
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item['amount'] as double),
    );
    final enteredSubtotal = _money(r['Subtotal']);
    final baseSubtotal = subtotal > 0 ? subtotal : enteredSubtotal;
    final discount = _money(r['Discount']);
    final tax = _money(r['Tax']);
    final grandTotal = _money(r['Grand Total']) > 0
        ? _money(r['Grand Total'])
        : (baseSubtotal - discount + tax);
    final paid = _money(r['Paid']);
    final balance = _money(r['Balance']) > 0
        ? _money(r['Balance'])
        : (grandTotal - paid);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Premium branded header.
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF101114),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(pw.MemoryImage(logo), width: 70, height: 70),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'DIXIT ',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.TextSpan(
                                text: 'MOTORS',
                                style: pw.TextStyle(
                                  color: PdfColor.fromInt(0xFFE31B23),
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'CAR WORKSHOP & SERVICE CENTRE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Service | Repair | Genuine Parts | Diagnostics',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFD0D0D4),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DRIVE SAFE, WE CARE',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFE31B23),
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Near Vardhman Hospital Ke Samne',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                      pw.Text(
                        'Thikaria, Banswara, Rajasthan 327001',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '9549281415  |  9929125644  |  9462101890',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Invoice No.: ${r['Invoice Number'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Date: ${r['Invoice Date'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Job No.: ${r['Job No.'] ?? r['Job Number'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 9),
            pw.Divider(color: PdfColor.fromInt(0xFFE31B23), thickness: 1.3),
            pw.SizedBox(height: 8),

            // Customer + vehicle details.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _invoiceInfoBox('CUSTOMER DETAILS', [
                    _invoiceInfoLine('Name', r['Customer'] ?? ''),
                    _invoiceInfoLine(
                      'Mobile No.',
                      r['Mobile'] ?? r['Phone'] ?? '',
                    ),
                    _invoiceInfoLine('Address', r['Address'] ?? ''),
                  ]),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _invoiceInfoBox('VEHICLE DETAILS', [
                    _invoiceInfoLine(
                      'Car No.',
                      r['Vehicle Number'] ??
                          r['Car Number'] ??
                          r['Vehicle'] ??
                          '',
                    ),
                    _invoiceInfoLine(
                      'Car Name',
                      r['Car Name'] ?? r['Make'] ?? '',
                    ),
                    _invoiceInfoLine('Model', r['Model'] ?? ''),
                    _invoiceInfoLine(
                      'Kilometer',
                      '${r['Kilometer'] ?? r['Current KM'] ?? ''} km',
                    ),
                    _invoiceInfoLine(
                      'Next Service',
                      '${r['Next Service KM'] ?? ''} km',
                    ),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Clean item table no Add Item/Search panel on the printed bill.
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFB9BDC5)),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(
                    color: PdfColor.fromInt(0xFFD8DADF),
                    width: .6,
                  ),
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(36),
                  1: pw.FlexColumnWidth(3.8),
                  2: pw.FixedColumnWidth(58),
                  3: pw.FixedColumnWidth(70),
                  4: pw.FixedColumnWidth(82),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF25282D),
                    ),
                    children:
                        [
                              'S.No.',
                              'ITEM / SERVICE NAME',
                              'QTY',
                              'RATE (Rs.)',
                              'AMOUNT (Rs.)',
                            ]
                            .map(
                              (x) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 5,
                                ),
                                child: pw.Text(
                                  x,
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  ...items.asMap().entries.map(
                    (entry) => pw.TableRow(
                      children:
                          [
                                '${entry.key + 1}',
                                entry.value['name'],
                                _qtyText(entry.value['qty']),
                                _moneyText(entry.value['rate']),
                                _moneyText(entry.value['amount']),
                              ]
                              .map(
                                (x) => pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 5,
                                  ),
                                  child: pw.Text(
                                    x,
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF5F6F7),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SERVICE NOTES',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          '${r['Work Done'] ?? r['Work Description'] ?? 'Service and repair work completed as per job card.'}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            lineSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 4,
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColor.fromInt(0xFFD0D3D8),
                    ),
                    children: [
                      _totalRow('Sub Total', baseSubtotal),
                      _totalRow('Discount', discount),
                      _totalRow('GST / Tax', tax),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFF202327),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              'TOTAL AMOUNT',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                _moneyText(grandTotal),
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD0D3D8)),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'TOTAL IN WORDS: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                    pw.TextSpan(
                      text: '${_amountInWords(grandTotal)} Rupees Only',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAYMENT DETAILS',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Payment Mode: ${r['Payment Mode'] ?? 'Cash / UPI'}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Paid: ${_moneyText(paid)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Balance: ${_moneyText(balance)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Text(
                        'Thank you for choosing Dixit Motors.',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'AUTHORIZED SIGNATORY',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Image(
                      pw.MemoryImage(signature),
                      width: 145,
                      height: 40,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.Text(
                      'Dixit Sharma',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                    pw.Text(
                      'Dixit Motors',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF111317),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Dixit Motors | Service with Trust | DRIVE SAFE, WE CARE',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.Text(
                    '9549281415 | 9929125644 | 9462101890',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    if (share) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${r['Invoice Number'] ?? 'invoice'}.pdf',
      );
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  pw.Widget _invoiceInfoBox(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFBFC3CA)),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1E2125),
            ),
          ),
          pw.SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _invoiceInfoLine(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              ': ${value ?? ''}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _totalRow(String label, double value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              _moneyText(value),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _invoiceItems(dynamic raw) {
    if (raw is List) {
      return raw.map((item) {
        final map = item is Map
            ? Map<String, dynamic>.from(item)
            : <String, dynamic>{'name': item.toString()};
        final qty = _number(map['qty'] ?? map['quantity'] ?? map['Qty'] ?? 1);
        final rate = _number(map['rate'] ?? map['price'] ?? map['Rate'] ?? 0);
        return {
          'name':
              map['name'] ??
              map['item'] ??
              map['Item'] ??
              map['Item / Service Name'] ??
              'Item',
          'qty': qty,
          'rate': rate,
          'amount': qty * rate,
        };
      }).toList();
    }

    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return [];

    // Supported manual format: one item per line, e.g. "Engine Oil | 4 | 650".
    final result = <Map<String, dynamic>>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final parts = line.split('|').map((x) => x.trim()).toList();
      if (parts.length >= 3) {
        final qty = _number(parts[1]);
        final rate = _number(parts[2]);
        result.add({
          'name': parts[0],
          'qty': qty,
          'rate': rate,
          'amount': qty * rate,
        });
      } else if (line.trim().isNotEmpty) {
        result.add({
          'name': line.trim(),
          'qty': 1.0,
          'rate': 0.0,
          'amount': 0.0,
        });
      }
    }
    return result;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  double _money(dynamic value) => _number(value);

  String _moneyText(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  String _qtyText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  String _amountInWords(double value) {
    final rupees = value.round();
    if (rupees == 0) return 'Zero';
    return _numberToWords(rupees);
  }

  String _numberToWords(int number) {
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String underThousand(int n) {
      var out = '';
      if (n >= 100) {
        out += '${ones[n ~/ 100]} Hundred';
        n %= 100;
        if (n > 0) out += ' ';
      }
      if (n >= 20) {
        out += tens[n ~/ 10];
        n %= 10;
        if (n > 0) out += ' ${ones[n]}';
      } else if (n > 0) {
        out += ones[n];
      }
      return out;
    }

    var n = number;
    var out = '';
    if (n >= 10000000) {
      out += '${underThousand(n ~/ 10000000)} Crore';
      n %= 10000000;
      if (n > 0) out += ' ';
    }
    if (n >= 100000) {
      out += '${underThousand(n ~/ 100000)} Lakh';
      n %= 100000;
      if (n > 0) out += ' ';
    }
    if (n >= 1000) {
      out += '${underThousand(n ~/ 1000)} Thousand';
      n %= 1000;
      if (n > 0) out += ' ';
    }
    if (n > 0) out += underThousand(n);
    return out.trim();
  }

  Future<Uint8List> _assetBytes(String asset) async {
    final data = await DefaultAssetBundle.of(context).load(asset);
    return data.buffer.asUint8List();
  }
}

Future<Map<String, dynamic>?> showInvoiceEditor(
  BuildContext context, {
  Map<String, dynamic>? initial,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InvoiceEditor(initial: initial),
  );
}

class InvoiceEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const InvoiceEditor({super.key, this.initial});
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  late final TextEditingController invoiceNo,
      jobNo,
      customer,
      mobile,
      vehicle,
      carName,
      model,
      km,
      nextKm,
      date,
      discount,
      tax,
      paid,
      workDone;
  String paymentMode = 'Cash';
  String paymentStatus = 'Unpaid';
  final List<Map<String, dynamic>> items = [];
  final itemSearch = TextEditingController();

  static const catalog = <Map<String, dynamic>>[
    {'name': 'Engine Oil', 'rate': 650.0, 'unit': 'Ltr'},
    {'name': 'Oil Filter', 'rate': 350.0, 'unit': 'Pcs'},
    {'name': 'Air Filter', 'rate': 450.0, 'unit': 'Pcs'},
    {'name': 'AC Filter', 'rate': 550.0, 'unit': 'Pcs'},
    {'name': 'Brake Pads', 'rate': 1800.0, 'unit': 'Set'},
    {'name': 'Coolant', 'rate': 400.0, 'unit': 'Ltr'},
    {'name': 'Spark Plug', 'rate': 300.0, 'unit': 'Pcs'},
    {'name': 'Battery', 'rate': 5500.0, 'unit': 'Pcs'},
    {'name': 'Brake Cleaning', 'rate': 300.0, 'unit': 'Job'},
    {'name': 'General Service', 'rate': 1200.0, 'unit': 'Job'},
    {'name': 'Labour Charge', 'rate': 1000.0, 'unit': 'Job'},
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initial ?? {};
    String val(String key) => r[key]?.toString() ?? '';
    invoiceNo = TextEditingController(
      text: val('Invoice Number').isEmpty
          ? 'DIX/${DateTime.now().year}/${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
          : val('Invoice Number'),
    );
    jobNo = TextEditingController(text: val('Job No.'));
    customer = TextEditingController(text: val('Customer'));
    mobile = TextEditingController(text: val('Mobile'));
    vehicle = TextEditingController(text: val('Vehicle Number'));
    carName = TextEditingController(text: val('Car Name'));
    model = TextEditingController(text: val('Model'));
    km = TextEditingController(text: val('Kilometer'));
    nextKm = TextEditingController(text: val('Next Service KM'));
    date = TextEditingController(
      text: val('Invoice Date').isEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : val('Invoice Date'),
    );
    discount = TextEditingController(
      text: val('Discount').isEmpty ? '0' : val('Discount'),
    );
    tax = TextEditingController(text: val('Tax').isEmpty ? '0' : val('Tax'));
    paid = TextEditingController(text: val('Paid').isEmpty ? '0' : val('Paid'));
    workDone = TextEditingController(text: val('Work Done'));
    paymentMode = val('Payment Mode').isEmpty ? 'Cash' : val('Payment Mode');
    paymentStatus = val('Payment Status').isEmpty
        ? 'Unpaid'
        : val('Payment Status');
    _loadItems(r['Items']);
    jobNo.addListener(_jobLookup);
  }

  void _loadItems(dynamic raw) {
    if (raw is List) {
      for (final x in raw) {
        if (x is Map) {
          final m = Map<String, dynamic>.from(x);
          items.add({
            'name': m['name'] ?? m['item'] ?? 'Item',
            'qty': _num(m['qty'] ?? m['quantity'] ?? 1),
            'rate': _num(m['rate'] ?? m['price'] ?? 0),
            'unit': m['unit'] ?? 'Pcs',
          });
        }
      }
    }
  }

  double _num(dynamic x) =>
      double.tryParse(x?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
  double get subtotal =>
      items.fold<double>(0, (s, x) => s + (_num(x['qty']) * _num(x['rate'])));
  double get total => subtotal - _num(discount.text) + _num(tax.text);
  double get balance => total - _num(paid.text);

  void _jobLookup() {
    final q = jobNo.text.trim().toLowerCase();
    if (q.isEmpty) return;
    final jobs = LocalStore.get('jobs')
        .where(
          (j) =>
              j['_deleted'] != true &&
              (j['Job Card Number']?.toString().toLowerCase() == q ||
                  j['Job No.']?.toString().toLowerCase() == q),
        )
        .toList();
    if (jobs.isEmpty) return;
    final j = jobs.first;
    final customerName = j['Customer']?.toString() ?? '';
    final vehicleNo = j['Vehicle']?.toString() ?? '';
    customer.text = customerName;
    vehicle.text = vehicleNo;
    km.text = j['Current KM']?.toString() ?? '';
    workDone.text =
        j['Work Description']?.toString() ?? j['Complaint']?.toString() ?? '';
    final vehicles = LocalStore.get('vehicles')
        .where(
          (v) =>
              v['_deleted'] != true &&
              (v['Vehicle Number']?.toString() ?? '').toLowerCase() ==
                  vehicleNo.toLowerCase(),
        )
        .toList();
    if (vehicles.isNotEmpty) {
      final v = vehicles.first;
      carName.text = v['Make']?.toString() ?? v['Car Name']?.toString() ?? '';
      model.text = v['Model']?.toString() ?? '';
      km.text = v['Current KM']?.toString() ?? km.text;
      nextKm.text = v['Next Service KM']?.toString() ?? nextKm.text;
      final c = LocalStore.get('customers')
          .where(
            (x) =>
                x['_deleted'] != true &&
                (x['Name']?.toString() ?? '').toLowerCase() ==
                    customerName.toLowerCase(),
          )
          .toList();
      if (c.isNotEmpty) mobile.text = c.first['Phone']?.toString() ?? '';
    }
    if (mounted) setState(() {});
  }

  void _addCatalog(Map<String, dynamic> item) {
    setState(
      () => items.add({
        'name': item['name'],
        'qty': 1.0,
        'rate': item['rate'],
        'unit': item['unit'],
      }),
    );
  }

  Map<String, dynamic> _saveData() => {
    'Invoice Number': invoiceNo.text.trim(),
    'Job No.': jobNo.text.trim(),
    'Customer': customer.text.trim(),
    'Mobile': mobile.text.trim(),
    'Vehicle Number': vehicle.text.trim(),
    'Car Name': carName.text.trim(),
    'Model': model.text.trim(),
    'Kilometer': km.text.trim(),
    'Next Service KM': nextKm.text.trim(),
    'Invoice Date': date.text.trim(),
    'Items': items
        .map(
          (x) => {
            'name': x['name'],
            'qty': _num(x['qty']),
            'rate': _num(x['rate']),
            'unit': x['unit'],
          },
        )
        .toList(),
    'Subtotal': subtotal,
    'Discount': _num(discount.text),
    'Tax': _num(tax.text),
    'Grand Total': total,
    'Paid': _num(paid.text),
    'Balance': balance,
    'Payment Status': balance <= 0
        ? 'Paid'
        : (_num(paid.text) > 0 ? 'Partial' : paymentStatus),
    'Payment Mode': paymentMode,
    'Work Done': workDone.text.trim(),
  };

  @override
  void dispose() {
    jobNo.removeListener(_jobLookup);

    for (final c in [
      invoiceNo,
      jobNo,
      customer,
      mobile,
      vehicle,
      carName,
      model,
      km,
      nextKm,
      date,
      discount,
      tax,
      paid,
      workDone,
      itemSearch,
    ]) {
      c.dispose();
    }

    super.dispose();
  }

  Widget _input(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = catalog
        .where(
          (x) => x['name'].toString().toLowerCase().contains(
            itemSearch.text.toLowerCase(),
          ),
        )
        .toList();
    final isCompactMobile = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      insetPadding: EdgeInsets.all(isCompactMobile ? 10 : 24),
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: brandRed),
          const SizedBox(width: 8),
          const Expanded(child: Text('Professional Invoice')),
        ],
      ),
      content: SizedBox(
        width: isCompactMobile ? double.infinity : 900,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _input(invoiceNo, 'Invoice No.')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _input(jobNo, 'Job No. - auto-fill customer & car'),
                  ),
                ],
              ),
              const Text(
                'CUSTOMER & VEHICLE DETAILS',
                style: TextStyle(
                  color: brandRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 0,
                children: [
                  for (final pair in <List<dynamic>>[
                    [customer, 'Customer Name'],
                    [mobile, 'Mobile No.'],
                    [vehicle, 'Car Number'],
                    [carName, 'Car Name'],
                    [model, 'Model'],
                    [km, 'Kilometer'],
                    [nextKm, 'Next Service KM'],
                  ])
                    SizedBox(
                      width: isCompactMobile ? double.infinity : 250,
                      child: _input(
                        pair[0] as TextEditingController,
                        pair[1] as String,
                      ),
                    ),
                ],
              ),
              const Divider(height: 18),
              const Text(
                'ADD ITEM / PART',
                style: TextStyle(
                  color: brandRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              TextField(
                controller: itemSearch,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search oil, oil filter, air filter...',
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: filtered
                    .map(
                      (x) => ActionChip(
                        label: Text('${x['name']} | Rs. ${x['rate']}'),
                        onPressed: () => _addCatalog(x),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No items added. Search above and click an item.',
                    style: TextStyle(color: silver),
                  ),
                ),
              ...items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final qtyField = SizedBox(
                  width: isCompactMobile ? 105 : 80,
                  child: TextFormField(
                    initialValue: _num(item['qty']).toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => setState(() => item['qty'] = _num(v)),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                    ),
                  ),
                );
                final rateField = SizedBox(
                  width: isCompactMobile ? 125 : 110,
                  child: TextFormField(
                    initialValue: _num(item['rate']).toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => setState(() => item['rate'] = _num(v)),
                    decoration: const InputDecoration(
                      labelText: 'Rate Rs.',
                      isDense: true,
                    ),
                  ),
                );
                final amount = Text(
                  'Rs. ${(_num(item['qty']) * _num(item['rate'])).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x334B5563)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isCompactMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item['name'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => items.removeAt(i)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: brandRed,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: qtyField),
                                const SizedBox(width: 8),
                                Expanded(child: rateField),
                                const SizedBox(width: 8),
                                Expanded(child: amount),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item['name'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            qtyField,
                            const SizedBox(width: 8),
                            rateField,
                            const SizedBox(width: 12),
                            SizedBox(width: 105, child: amount),
                            IconButton(
                              onPressed: () =>
                                  setState(() => items.removeAt(i)),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: brandRed,
                              ),
                            ),
                          ],
                        ),
                );
              }),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _input(workDone, 'Work Done / Service Notes'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        _input(discount, 'Discount Rs.', number: true),
                        _input(tax, 'GST / Tax Rs.', number: true),
                        _input(paid, 'Paid Rs.', number: true),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: paymentMode,
                      items:
                          const [
                                'Cash',
                                'UPI',
                                'PhonePe',
                                'Google Pay',
                                'Paytm',
                                'Card',
                                'Net Banking',
                              ]
                              .map(
                                (x) =>
                                    DropdownMenuItem(value: x, child: Text(x)),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => paymentMode = v ?? 'Cash'),
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x221F2937),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Subtotal Rs. ${subtotal.toStringAsFixed(2)}'),
                          Text(
                            'Total Rs. ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Balance Rs. ${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: brandRed,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back / Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _saveData()),
          icon: const Icon(Icons.save),
          label: const Text('Save Invoice'),
        ),
      ],
    );
  }
}

class GlobalSearchPage extends StatefulWidget {
  final VoidCallback? onBack;
  const GlobalSearchPage({super.key, this.onBack});
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final results = <Map<String, dynamic>>[];
    if (q.trim().isNotEmpty) {
      for (final m in moduleDefs) {
        for (final r in LocalStore.get(
          m.key,
        ).where((x) => x['_deleted'] != true)) {
          if (jsonEncode(r).toLowerCase().contains(q.toLowerCase())) {
            results.add({'module': m.title, 'icon': m.icon, 'record': r});
          }
        }
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Search',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Search customers, cars, jobs, invoices, payments and staff.',
                      style: TextStyle(color: silver),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, mobile, plate, job no., invoice no....',
            ),
          ),
          const SizedBox(height: 15),
          if (q.isNotEmpty)
            Text(
              '${results.length} result(s)',
              style: const TextStyle(color: silver),
            ),
          ...results
              .take(100)
              .map(
                (x) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(x['icon'] as IconData, size: 24, color: brandRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              x['module'],
                              style: const TextStyle(
                                color: brandRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              jsonEncode(x['record']),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

List<String> fieldsFor(String key) {
  switch (key) {
    case 'customers':
      return ['Name', 'Phone', 'Address', 'Notes'];
    case 'vehicles':
      return [
        'Vehicle Number',
        'Make',
        'Model',
        'Fuel Type',
        'Current KM',
        'Next Service KM',
        'Customer',
      ];
    case 'bookings':
      return [
        'Customer',
        'Vehicle',
        'Booking Date',
        'Booking Time',
        'Service Type',
        'Description',
        'Status',
      ];
    case 'jobs':
      return [
        'Job Card Number',
        'Customer',
        'Vehicle',
        'Date',
        'Current KM',
        'Complaint',
        'Work Description',
        'Job Status',
      ];
    case 'inspections':
      return [
        'Vehicle',
        'Date',
        'Engine',
        'Brakes',
        'Tyres',
        'Battery',
        'AC',
        'Lights',
        'Notes',
      ];
    case 'team':
      return [
        'Worker Name',
        'Mobile',
        'Skill',
        'Role',
        'Joining Date',
        'Status',
      ];
    case 'attendance':
      return [
        'Date',
        'Worker Name',
        'Status',
        'Check In',
        'Check Out',
        'Notes',
      ];
    case 'services':
      return ['Service Name', 'HSN/SAC', 'Rate', 'Description', 'Status'];
    case 'inventory':
      return [
        'Part Name',
        'Part Number',
        'Category',
        'Supplier',
        'Purchase Rate',
        'Selling Rate',
        'Quantity',
        'Minimum Stock',
        'HSN',
      ];
    case 'purchases':
      return [
        'Supplier',
        'Invoice Number',
        'Date',
        'Part',
        'Quantity',
        'Rate',
        'Total',
      ];
    case 'suppliers':
      return ['Supplier Name', 'Mobile', 'Address', 'GSTIN', 'Notes'];
    case 'estimates':
      return [
        'Estimate Number',
        'Customer',
        'Vehicle',
        'Date',
        'Items',
        'Subtotal',
        'Discount',
        'Tax',
        'Grand Total',
        'Status',
      ];
    case 'invoices':
      return [
        'Invoice Number',
        'Job No.',
        'Customer',
        'Mobile',
        'Vehicle Number',
        'Car Name',
        'Model',
        'Kilometer',
        'Next Service KM',
        'Invoice Date',
        'Items',
        'Subtotal',
        'Discount',
        'Tax',
        'Grand Total',
        'Paid',
        'Balance',
        'Payment Status',
        'Payment Mode',
        'Work Done',
      ];
    case 'payments':
      return [
        'Invoice',
        'Customer',
        'Vehicle',
        'Amount',
        'Payment Date',
        'Payment Mode',
        'Reference Number',
        'Notes',
      ];
    case 'expenses':
      return [
        'Expense Date',
        'Category',
        'Description',
        'Amount',
        'Payment Mode',
        'Notes',
      ];
    case 'reminders':
      return [
        'Vehicle',
        'Customer',
        'Next Service Date',
        'Next Service KM',
        'Notes',
        'Status',
      ];
    default:
      return ['Title', 'Description', 'Status', 'Notes'];
  }
}

Future<Map<String, dynamic>?> showRecordDialog(
  BuildContext context,
  ModuleDef definition, {
  Map<String, dynamic>? initial,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => RecordDialog(definition: definition, initial: initial),
  );
}

class RecordDialog extends StatefulWidget {
  final ModuleDef definition;
  final Map<String, dynamic>? initial;

  const RecordDialog({super.key, required this.definition, this.initial});

  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<RecordDialog> {
  late final Map<String, TextEditingController> controllers;
  String status = 'Pending';

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in fieldsFor(widget.definition.key))
        f: TextEditingController(text: widget.initial?[f]?.toString() ?? ''),
    };
    status =
        widget.initial?['Status']?.toString() ??
        widget.initial?['Job Status']?.toString() ??
        'Pending';
    if (widget.initial == null) {
      for (final f in [
        'Date',
        'Invoice Date',
        'Booking Date',
        'Joining Date',
        'Payment Date',
        'Expense Date',
      ]) {
        if (controllers.containsKey(f)) {
          controllers[f]!.text = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.now());
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = fieldsFor(widget.definition.key);
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.definition.icon, color: widget.definition.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.initial == null ? 'Add' : 'Edit'} ${widget.definition.title}',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(children: fields.map(_field).toList()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.initial == null ? 'Save' : 'Update'),
        ),
      ],
    );
  }

  Widget _field(String field) {
    if (field == 'Status' || field == 'Job Status') {
      const options = [
        'Pending',
        'Scheduled',
        'Confirmed',
        'In Progress',
        'Waiting for Parts',
        'Approved',
        'Quality Check',
        'Ready',
        'Completed',
        'Delivered',
        'Cancelled',
        'Paid',
        'Partial',
        'Unpaid',
        'Active',
        'Inactive',
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(status) ? status : 'Pending',
          items: options
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) => setState(() => status = v ?? 'Pending'),
          decoration: InputDecoration(labelText: field),
        ),
      );
    }
    final numeric =
        field.contains('Rate') ||
        field.contains('Amount') ||
        field.contains('KM') ||
        field.contains('Quantity') ||
        field == 'Tax' ||
        field == 'Discount' ||
        field == 'Grand Total' ||
        field == 'Paid' ||
        field == 'Balance';
    final multiline =
        field == 'Notes' ||
        field == 'Description' ||
        field == 'Complaint' ||
        field == 'Work Description' ||
        field == 'Work Done';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controllers[field],
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(labelText: field),
      ),
    );
  }

  void _save() {
    final data = <String, dynamic>{};
    for (final entry in controllers.entries) {
      data[entry.key] = entry.value.text.trim();
    }
    if (controllers.containsKey('Status')) data['Status'] = status;
    if (controllers.containsKey('Job Status')) data['Job Status'] = status;
    Navigator.pop(context, data);
  }
}

class ScannerPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ScannerPage({super.key, this.onBack});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final picker = ImagePicker();
  String detected = '';
  bool scanning = false;

  Future<void> _openLiveScanner() async {
    if (!Platform.isAndroid) {
      setState(
        () => detected =
            'Live camera OCR is available on Android. On Windows use photo scan or enter the plate manually.',
      );
      return;
    }
    final plate = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LivePlateScannerPage()),
    );
    if (!mounted || plate == null || plate.trim().isEmpty) return;
    final normalized = _normalize(plate);
    setState(() => detected = normalized);
    _showVehicle(normalized);
  }

  Future<void> _scan(ImageSource source) async {
    setState(() => scanning = true);
    try {
      final image = await picker.pickImage(source: source, imageQuality: 90);
      if (image == null) return;
      if (!Platform.isAndroid) {
        setState(
          () => detected =
              'Windows: photo selected. Use Global Search or enter the plate manually.',
        );
        return;
      }
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final text = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      await recognizer.close();
      final plate = _normalize(text.text);
      setState(
        () => detected = plate.isEmpty
            ? 'Plate not detected. Try a clearer photo.'
            : plate,
      );
      if (plate.isNotEmpty) _showVehicle(plate);
    } catch (e) {
      setState(() => detected = 'Scanner error: $e');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  String _normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  void _showVehicle(String plate) {
    final vehicles = LocalStore.get('vehicles')
        .where(
          (v) =>
              v['_deleted'] != true &&
              _normalize(v['Vehicle Number']?.toString() ?? '') == plate,
        )
        .toList();
    final jobs = LocalStore.get('jobs')
        .where(
          (j) =>
              j['_deleted'] != true &&
              _normalize(j['Vehicle']?.toString() ?? '') == plate,
        )
        .toList();
    final invoices = LocalStore.get('invoices')
        .where(
          (i) =>
              i['_deleted'] != true &&
              _normalize(i['Vehicle']?.toString() ?? '') == plate,
        )
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                plate,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Complete Vehicle File',
                style: TextStyle(color: silver),
              ),
              const SizedBox(height: 12),
              if (vehicles.isEmpty)
                const Text('Vehicle not found in local records.'),
              ...vehicles.map(
                (v) => ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('${v['Make'] ?? ''} ${v['Model'] ?? ''}'),
                  subtitle: Text(
                    '${v['Customer'] ?? ''} ${v['Current KM'] ?? ''} KM',
                  ),
                ),
              ),
              const Divider(),
              Text(
                'Job History (${jobs.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              ...jobs.map(
                (j) => ListTile(
                  leading: const Icon(Icons.build),
                  title: Text(j['Job Card Number']?.toString() ?? 'Job Card'),
                  subtitle: Text('${j['Date'] ?? ''} ${j['Job Status'] ?? ''}'),
                ),
              ),
              const Divider(),

              Text(
                'Invoice History (${invoices.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),

              ...invoices.map(
                (i) => ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(i['Invoice Number']?.toString() ?? 'Invoice'),
                  subtitle: Text(
                    '${i['Grand Total'] ?? ''} - ${i['Payment Status'] ?? ''}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              Image.asset('assets/app_icon.png', height: 120),
              const SizedBox(height: 18),
              const Text(
                'SMART NUMBER PLATE SCANNER',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan a plate and open the connected vehicle history.',
                textAlign: TextAlign.center,
                style: TextStyle(color: silver),
              ),
              const SizedBox(height: 24),
              if (scanning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: CircularProgressIndicator(color: brandRed),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: scanning ? null : _openLiveScanner,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('LIVE SCAN'),
                  ),
                  FilledButton.icon(
                    onPressed: scanning
                        ? null
                        : () => _scan(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('CAPTURE PHOTO'),
                  ),
                  OutlinedButton.icon(
                    onPressed: scanning
                        ? null
                        : () => _scan(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('CHOOSE PHOTO'),
                  ),
                ],
              ),
              if (detected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    detected,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: silver),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  final VoidCallback? onBack;
  const AttendancePage({super.key, this.onBack});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String worker = '';
  String historySearch = '';

  List<Map<String, dynamic>> get workers => LocalStore.get('team')
      .where(
        (x) =>
            x['_deleted'] != true &&
            (x['Worker Name']?.toString().trim().isNotEmpty ?? false),
      )
      .toList();

  String keyFor(DateTime d, String w) =>
      '${DateFormat('yyyy-MM-dd').format(d)}|$w';

  Map<String, dynamic>? record(DateTime d, String w) {
    final k = keyFor(d, w);
    final list = LocalStore.get(
      'attendance',
    ).where((x) => x['_deleted'] != true && x['Key'] == k).toList();
    return list.isEmpty ? null : list.first;
  }

  Future<void> saveStatus(DateTime d, String w, String status) async {
    final old = record(d, w);
    final data = <String, dynamic>{
      'Key': keyFor(d, w),
      'Date': DateFormat('yyyy-MM-dd').format(d),
      'Worker Name': w,
      'Status': status,
      'Check In': old?['Check In'] ?? '',
      'Check Out': old?['Check Out'] ?? '',
      'Notes': old?['Notes'] ?? '',
    };
    if (old != null) data['_id'] = old['_id'];
    await LocalStore.upsert('attendance', data);
    await _log('Attendance $w ${data['Date']}: $status');
    unawaited(_safeBackgroundSync());
    if (mounted) setState(() {});
  }

  Future<void> editDay(DateTime d, String w) async {
    final old = record(d, w) ?? {};
    final statusCtrl = ValueNotifier<String>(
      old['Status']?.toString() ?? 'Present',
    );
    final inC = TextEditingController(text: old['Check In']?.toString() ?? '');
    final outC = TextEditingController(
      text: old['Check Out']?.toString() ?? '',
    );
    final notesC = TextEditingController(text: old['Notes']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${DateFormat('dd MMM yyyy').format(d)} - $w'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: statusCtrl,
                builder: (_, v, _) => DropdownButtonFormField<String>(
                  initialValue: v,
                  items: const ['Present', 'Absent', 'Half Day', 'Leave']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (x) => statusCtrl.value = x ?? v,
                  decoration: const InputDecoration(
                    labelText: 'Attendance Status',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: inC,
                decoration: const InputDecoration(
                  labelText: 'Check In (e.g. 09:10 AM)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: outC,
                decoration: const InputDecoration(
                  labelText: 'Check Out (e.g. 06:00 PM)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesC,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'Key': keyFor(d, w),
                'Date': DateFormat('yyyy-MM-dd').format(d),
                'Worker Name': w,
                'Status': statusCtrl.value,
                'Check In': inC.text.trim(),
                'Check Out': outC.text.trim(),
                'Notes': notesC.text.trim(),
              };
              if (old['_id'] != null) data['_id'] = old['_id'];
              await LocalStore.upsert('attendance', data);
              await _log('Edited attendance $w ${data['Date']}');
              unawaited(_safeBackgroundSync());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    inC.dispose();
    outC.dispose();
    notesC.dispose();
    statusCtrl.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _log(String action) async {
    // Audit/Activity Log is removed from the Dixit Motors Management App.
  }

  Color statusColor(String s) {
    switch (s) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return brandRed;
      case 'Half Day':
        return Colors.amber;
      case 'Leave':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  int daysInMonth() => DateTime(month.year, month.month + 1, 0).day;
  List<DateTime> get dates => List.generate(
    daysInMonth(),
    (i) => DateTime(month.year, month.month, i + 1),
  );

  @override
  Widget build(BuildContext context) {
    if (worker.isEmpty && workers.isNotEmpty) {
      worker = workers.first['Worker Name'].toString();
    }
    final w = worker;
    final rows = dates;
    final counts = {'Present': 0, 'Absent': 0, 'Half Day': 0, 'Leave': 0};
    for (final d in rows) {
      final r = record(d, w);
      final s = r?['Status']?.toString();
      if (s != null && counts.containsKey(s)) counts[s] = counts[s]! + 1;
    }
    final attended = counts['Present']! + counts['Half Day']! * .5;
    final pct = rows.isEmpty ? 0 : (attended / rows.length * 100);
    final history = LocalStore.get('attendance')
        .where((x) => x['_deleted'] != true)
        .where(
          (x) =>
              historySearch.isEmpty ||
              jsonEncode(x).toLowerCase().contains(historySearch.toLowerCase()),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Attendance',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Date-wise Present / Absent register with monthly history.',
                      style: TextStyle(color: silver),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: w.isEmpty ? null : w,
            items: workers
                .map(
                  (x) => DropdownMenuItem(
                    value: x['Worker Name'].toString(),
                    child: Text(x['Worker Name'].toString()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => worker = v ?? ''),
            decoration: const InputDecoration(labelText: 'Worker'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat('Present', counts['Present']!, Colors.green),
              _stat('Absent', counts['Absent']!, brandRed),
              _stat('Half Day', counts['Half Day']!, Colors.amber),
              _stat('Leave', counts['Leave']!, Colors.blue),
              _stat('Attendance', pct.isNaN ? 0 : pct, brandRed, suffix: '%'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Register',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...rows.map((d) {
                  final r = record(d, w);
                  final s = r?['Status']?.toString() ?? '';
                  final c = statusColor(s);
                  return InkWell(
                    onTap: () => editDay(d, w),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.withAlpha(90)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 55,
                            child: Text(
                              DateFormat('dd').format(d),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat('EEE, dd MMM').format(d),
                              style: const TextStyle(color: silver),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: c.withAlpha(35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.isEmpty ? 'Not Marked' : s,
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit_outlined, size: 17, color: silver),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Attendance History',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => historySearch = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search worker, date, status...',
            ),
          ),
          const SizedBox(height: 8),

          ...history
              .take(100)
              .map(
                (r) => ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 13,
                    color: statusColor(r['Status']?.toString() ?? ''),
                  ),
                  title: Text(
                    '${r['Worker Name'] ?? ''} - ${r['Status'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${r['Date'] ?? ''} - ${r['Check In'] ?? ''} - ${r['Check Out'] ?? ''}',
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stat(String t, num v, Color c, {String suffix = ''}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.withAlpha(65)),
    ),
    child: Text(
      '$t: ${v is double ? v.toStringAsFixed(1) : v}$suffix',
      style: TextStyle(color: c, fontWeight: FontWeight.w900),
    ),
  );
}

class DeviceManagementPage extends StatefulWidget {
  final VoidCallback? onBack;
  const DeviceManagementPage({super.key, this.onBack});
  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  List<Map<String, dynamic>> devices = [];
  bool busy = false;
  String error = '';

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = '';
    });

    try {
      final s = await SyncService.settings();
      final base = s['url'] ?? '';
      final key = s['key'] ?? '';

      if (base.isEmpty || key.isEmpty) {
        throw Exception('Cloud Sync is not configured.');
      }

      final r = await http
          .get(
            Uri.parse('$base/api/devices'),
            headers: {'X-Sync-Key': key, 'Accept-Encoding': 'identity'},
          )
          .timeout(const Duration(seconds: 12));

      if (r.statusCode >= 300) {
        throw Exception('Cloud error ${r.statusCode}: ${r.body}');
      }

      final body = _decodeJsonMap(r, 'Cloud device list');

      devices = (body['devices'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  bool _blocked(Map<String, dynamic> d) =>
      (d['status']?.toString().toLowerCase() ?? '') == 'blocked';

  Future<void> _setBlocked(Map<String, dynamic> d, bool blocked) async {
    try {
      final s = await SyncService.settings();
      final base = s['url'] ?? '';
      final key = s['key'] ?? '';
      final endpoint = blocked ? 'block' : 'unblock';

      final r = await http
          .post(
            Uri.parse('$base/api/devices/$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'X-Sync-Key': key,
              'Accept-Encoding': 'identity',
            },
            body: jsonEncode({'device_id': d['device_id']}),
          )
          .timeout(const Duration(seconds: 12));

      if (r.statusCode >= 300) {
        throw Exception(r.body);
      }

      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(blocked ? 'Device blocked.' : 'Device unblocked.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Device action failed: $e')));
      }
    }
  }

  String _lastSeen(dynamic v) {
    final dt = DateTime.tryParse(v?.toString() ?? '');

    return dt == null
        ? 'Never'
        : DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = devices.length;
    final blocked = devices.where(_blocked).length;
    final active = total - blocked;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Management',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Control registered Dixit Motors devices and access status.',
                      style: TextStyle(color: silver),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width < 600 ? 3 : 3,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: [
              _summary('Total', total.toString(), Icons.devices, silver),
              _summary(
                'Active',
                active.toString(),
                Icons.verified_user,
                Colors.green,
              ),
              _summary('Blocked', blocked.toString(), Icons.block, brandRed),
            ],
          ),
          const SizedBox(height: 18),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(error),
            ),
          const SizedBox(height: 10),
          if (devices.isEmpty && !busy && error.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'No devices registered yet.',
                  style: TextStyle(color: silver),
                ),
              ),
            ),
          ...devices.map((d) => _deviceCard(d)),
        ],
      ),
    );
  }

  Widget _summary(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            Text(title, style: const TextStyle(color: silver, fontSize: 10)),
          ],
        ),
      );

  Widget _deviceCard(Map<String, dynamic> d) {
    final blocked = _blocked(d);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: (blocked ? brandRed : Colors.green).withAlpha(65),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _deviceInfo(d, blocked),
                  const SizedBox(height: 10),
                  _deviceAction(d, blocked),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _deviceInfo(d, blocked)),
                  _deviceAction(d, blocked),
                ],
              ),
      ),
    );
  }

  Widget _deviceInfo(Map<String, dynamic> d, bool blocked) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            blocked ? Icons.block : Icons.phone_android,
            color: blocked ? brandRed : Colors.green,
          ),
          const SizedBox(width: 9),
          Text(
            d['device_name']?.toString() ?? 'Device',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'ID: ${d['device_id'] ?? ''}',
        style: const TextStyle(color: silver, fontSize: 10),
      ),
      Text(
        'Last seen: ${_lastSeen(d['last_seen'])}',
        style: const TextStyle(color: silver, fontSize: 11),
      ),
      Text(
        blocked ? 'ACCESS BLOCKED' : 'ACCESS ACTIVE',
        style: TextStyle(
          color: blocked ? brandRed : Colors.green,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    ],
  );

  Widget _deviceAction(Map<String, dynamic> d, bool blocked) =>
      FilledButton.icon(
        onPressed: () => _setBlocked(d, !blocked),
        icon: Icon(blocked ? Icons.lock_open : Icons.block),
        label: Text(blocked ? 'Unblock' : 'Block'),
        style: FilledButton.styleFrom(
          backgroundColor: blocked ? Colors.green : brandRed,
        ),
      );
}

class LivePlateScannerPage extends StatefulWidget {
  const LivePlateScannerPage({super.key});
  @override
  State<LivePlateScannerPage> createState() => _LivePlateScannerPageState();
}

class _LivePlateScannerPageState extends State<LivePlateScannerPage> {
  CameraController? controller;
  TextRecognizer? recognizer;
  bool processing = false;
  bool torch = false;
  String status = 'Point camera at the vehicle number plate.';
  DateTime lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final rear = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      controller = CameraController(
        rear,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      await controller!.initialize();
      await controller!.startImageStream(_processFrame);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => status = 'Camera error: $e');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (processing ||
        DateTime.now().difference(lastRun).inMilliseconds < 750 ||
        controller == null ||
        !controller!.value.isInitialized) {
      return;
    }

    processing = true;
    lastRun = DateTime.now();

    try {
      final plane = image.planes.first;

      final rotation =
          InputImageRotationValue.fromRawValue(
            controller!.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;

      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );

      final text = await recognizer!.processImage(input);
      final plate = _extractPlate(text.text);

      if (plate != null && mounted) {
        await controller!.stopImageStream();
        await controller!.dispose();
        await recognizer!.close();

        if (mounted) {
          Navigator.pop(context, plate);
        }
      } else if (mounted) {
        setState(
          () => status = text.text.isEmpty
              ? 'Scanning...'
              : 'Detected text: ${text.text.replaceAll('\n', ' ')}',
        );
      }
    } catch (_) {
      // Keep stream alive; camera frames can be device-specific.
    } finally {
      processing = false;
    }
  }

  String? _extractPlate(String text) {
    final cleaned = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\n]'), '\n');

    final candidates = cleaned
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 8 && e.length <= 12);

    for (final c in candidates) {
      if (RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{3,4}$').hasMatch(c) ||
          RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$').hasMatch(c)) {
        return c;
      }
    }

    return null;
  }

  Future<void> _toggleTorch() async {
    if (controller == null) return;
    torch = !torch;
    await controller!.setFlashMode(torch ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.dispose();
    recognizer?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized == true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Number Plate OCR'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: ready ? _toggleTorch : null,
            icon: Icon(torch ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: ready
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller!),
                Center(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * .82,
                    height: 125,
                    decoration: BoxDecoration(
                      border: Border.all(color: brandRed, width: 4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: brandRed)),
    );
  }
}

class SyncPage extends StatefulWidget {
  final VoidCallback? onBack;
  const SyncPage({super.key, this.onBack});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final url = TextEditingController();
  final key = TextEditingController();
  final device = TextEditingController();
  final user = TextEditingController();
  String message = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SyncService.settings();
    url.text = (s['url'] ?? '').isEmpty
        ? 'https://dixit-motors-erp-api.onrender.com'
        : s['url']!;
    key.text = s['key'] ?? '';
    device.text = s['device'] ?? 'Dixit Device';
    user.text = s['user'] ?? 'Dixit User';
    if (mounted) setState(() {});
  }

  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      await SyncService.configure(
        url: url.text,
        key: key.text,
        device: device.text,
        user: user.text,
      );
      final result = await SyncService.sync();
      if (mounted) setState(() => message = result);
    } catch (e) {
      if (mounted) setState(() => message = 'Sync error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    url.dispose();
    key.dispose();
    device.dispose();
    user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed:
                        widget.onBack ?? () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'Cloud Sync',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const Text(
                'One central source of truth for the laptop + 7 Android mobiles.',
                style: TextStyle(color: silver),
              ),
              const SizedBox(height: 20),

              _input(url, 'API URL', 'https://your-server.example'),
              _input(key, 'Sync Key', 'Private key from backend', secret: true),
              _input(device, 'Device Name', 'Admin Laptop / Mobile 01'),
              _input(user, 'User Name', 'Dixit Admin / Staff'),

              const SizedBox(height: 6),

              Row(
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : _sync,
                    icon: const Icon(Icons.cloud_sync),
                    label: Text(busy ? 'Syncing...' : 'Save & Sync'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: busy ? null : _sync,
                    child: const Text('Sync Now'),
                  ),
                ],
              ),

              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(message, style: const TextStyle(color: silver)),
                ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync model',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Every device writes locally first. When a network is available, changes are pushed to FastAPI/PostgreSQL and newer cloud records are pulled back. Remote locations require internet or a private VPN.',
                      style: TextStyle(color: silver, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label,
    String hint, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      obscureText: secret,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  Future<void> _backup(BuildContext context) async {
    try {
      final json = await LocalStore.exportJson();

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dixit Motors backup',
        fileName:
            'dixit_motors_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path == null) return;

      await File(path).writeAsString(json, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup error: $e')));
      }
    }
  }

  Future<void> _cloudBackup(BuildContext context) async {
    try {
      final s = await SyncService.settings();
      final base = s['url'] ?? '';
      final key = s['key'] ?? '';

      if (base.isEmpty || key.isEmpty) {
        throw Exception('Cloud Sync is not configured.');
      }

      final r = await http
          .get(
            Uri.parse('$base/api/backup/export'),
            headers: {
              'X-Sync-Key': key,
              'Accept': 'application/json',
              'Accept-Encoding': 'identity',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode >= 300) {
        throw Exception('Cloud backup failed (${r.statusCode}): ${r.body}');
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dixit Motors cloud backup',
        fileName:
            'dixit_motors_cloud_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path == null) return;

      await File(path).writeAsString(r.body, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud backup saved successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cloud backup error: $e')));
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    try {
      final decoded = jsonDecode(
        utf8
            .decode(picked.files.single.bytes!, allowMalformed: true)
            .replaceFirst('\ufeff', '')
            .trim(),
      );
      final raw = decoded is Map && decoded['records'] is Map
          ? decoded['records']
          : decoded;
      if (!context.mounted) return;
      if (!await confirmDialog(
        context,
        'Restore backup and replace local workshop data?',
      )) {
        return;
      }
      final restored = <String, List<Map<String, dynamic>>>{};
      for (final m in moduleDefs) {
        final value = raw[m.key];
        restored[m.key] = value is List
            ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
      }
      await LocalStore.replaceAll(restored);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore error: $e')));
      }
    }
  }

  Future<void> _restoreCloud(BuildContext context) async {
    try {
      final confirmed = await confirmDialog(
        context,
        'Download the latest cloud backup and replace local workshop data?',
      );

      if (!confirmed) return;

      final s = await SyncService.settings();
      final base = s['url'] ?? '';
      final key = s['key'] ?? '';

      if (base.isEmpty || key.isEmpty) {
        throw Exception('Cloud Sync is not configured.');
      }

      final r = await http
          .get(
            Uri.parse('$base/api/backup/export'),
            headers: {
              'X-Sync-Key': key,
              'Accept': 'application/json',
              'Accept-Encoding': 'identity',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode >= 300) {
        throw Exception(
          'Cloud restore download failed (${r.statusCode}): ${r.body}',
        );
      }

      final body = _decodeJsonMap(r, 'Cloud backup');

      final restored = <String, List<Map<String, dynamic>>>{
        for (final x in moduleDefs) x.key: <Map<String, dynamic>>[],
      };

      final rawRecords = body['records'];

      if (rawRecords is List) {
        for (final raw in rawRecords) {
          if (raw is! Map) continue;

          final x = Map<String, dynamic>.from(raw);

          final module = x['module']?.toString() ?? '';

          if (module.isEmpty || !restored.containsKey(module)) {
            continue;
          }

          final rawData = x['data'];

          final data = rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : <String, dynamic>{};

          final id = x['id']?.toString() ?? data['_id']?.toString() ?? '';

          if (id.isNotEmpty) {
            data['_id'] = id;
          }

          final updatedAt = x['updated_at'] ?? data['_updatedAt'];

          if (updatedAt != null) {
            data['_updatedAt'] = updatedAt.toString();
          }

          if (x['deleted'] == true) {
            data['_deleted'] = true;
          }

          restored[module]!.add(data);
        }
      }

      await LocalStore.replaceAll(restored);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud data restored successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cloud restore error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const Text(
                'Dixit Motors Management App control center',
                style: TextStyle(color: silver),
              ),

              const SizedBox(height: 20),

              _section('Workshop Identity', [
                const ListTile(
                  leading: Icon(Icons.people_alt_outlined),
                  title: Text('Owners'),
                  subtitle: Text('Dixit Sharma / Ashok Sharma'),
                ),
                const ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Management App Managed By'),
                  subtitle: Text('Kavi Sharma'),
                ),
                const ListTile(
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('Workshop'),
                  subtitle: Text(
                    'Near Vardhman Hospital, Thikaria, '
                    'Banswara, Rajasthan 327001',
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.phone_outlined),
                  title: Text('Contact'),
                  subtitle: Text('9549281415 - 9929125644 - 9462101890'),
                ),
              ]),

              _section('Backup & Safety', [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Create Backup'),
                  subtitle: const Text(
                    'Export all local management records to JSON',
                  ),
                  onTap: () => _backup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore Backup'),
                  subtitle: const Text(
                    'Replace local records from JSON backup',
                  ),
                  onTap: () => _restore(context),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Cloud Backup'),
                  subtitle: const Text(
                    'Export the current central cloud database backup',
                  ),
                  onTap: () => _cloudBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Restore From Cloud'),
                  subtitle: const Text(
                    'Download the central cloud data to this device',
                  ),
                  onTap: () => _restoreCloud(context),
                ),
              ]),

              _section('Branding', [
                Center(
                  child: Image.asset(
                    'assets/app_icon.png',
                    height: 105,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'DRIVE SAFE, WE CARE',
                    style: TextStyle(
                      color: brandRed,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 15),

              const Center(
                child: Text(
                  'Fresh architecture - Windows + Android - Version 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: silver, fontSize: 11),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String text) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
}
