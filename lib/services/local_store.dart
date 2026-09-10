import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalStore {
  static final Uuid _uuid = Uuid();
  static Map<String, List<Map<String, dynamic>>> _data = {};
  static File? _file;

  static Future<void> init(List<String> modules) async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}dixit_motors_management_app.json');
    if (await _file!.exists()) {
      try {
        final decoded = jsonDecode(await _file!.readAsString());
        if (decoded is Map) {
          _data = decoded.map((k, v) => MapEntry(k.toString(), v is List
              ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : <Map<String, dynamic>>[]));
        }
      } catch (_) {
        _data = {};
      }
    }
    for (final m in modules) {
      _data.putIfAbsent(m, () => <Map<String, dynamic>>[]);
    }
    await _flush();
  }

  static List<Map<String, dynamic>> get(String module) => List<Map<String, dynamic>>.from(_data[module] ?? const []);

  static Future<void> save(String module, List<Map<String, dynamic>> records) async {
    _data[module] = records.map((r) => Map<String, dynamic>.from(r)).toList();
    await _flush();
  }

  static Future<void> upsert(String module, Map<String, dynamic> record) async {
    final list = _data.putIfAbsent(module, () => <Map<String, dynamic>>[]);
    final now = DateTime.now().toUtc().toIso8601String();
    final item = Map<String, dynamic>.from(record);
    item['_id'] = (item['_id']?.toString().isNotEmpty == true) ? item['_id'] : _uuid.v4();
    item['_updatedAt'] = now;
    final index = list.indexWhere((e) => e['_id'] == item['_id']);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.insert(0, item);
    }
    await _flush();
  }

  static Future<void> remove(String module, String id) async {
    final list = _data.putIfAbsent(module, () => <Map<String, dynamic>>[]);
    final i = list.indexWhere((e) => e['_id'] == id);
    if (i >= 0) {
      list[i]['_deleted'] = true;
      list[i]['_updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _flush();
    }
  }

  static Map<String, List<Map<String, dynamic>>> snapshot() => {
    for (final e in _data.entries) e.key: e.value.map(Map<String, dynamic>.from).toList()
  };

  static Future<void> replaceAll(Map<String, List<Map<String, dynamic>>> value) async {
    _data = value.map((k, v) => MapEntry(k, v.map((e) => Map<String, dynamic>.from(e)).toList()));
    await _flush();
  }

  static Future<String> exportJson() async => jsonEncode({'version': 1, 'exportedAt': DateTime.now().toUtc().toIso8601String(), 'records': snapshot()});

  static Future<void> _flush() async {
    if (_file == null) return;
    await _file!.writeAsString(jsonEncode(_data), flush: true);
  }
}
