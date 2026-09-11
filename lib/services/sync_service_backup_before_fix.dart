import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';

class SyncService {
  static const _urlKey = 'sync_url';
  static const _keyKey = 'sync_key';
  static const _deviceKey = 'device_name';
  static const _sinceKey = 'sync_since';
  static const _deviceIdKey = 'sync_device_id';
  static const _userKey = 'sync_user';

  static Future<void> configure({
    required String url,
    required String key,
    required String device,
    String user = 'Dixit User',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_urlKey, url.trim().replaceAll(RegExp(r'/$'), ''));
    await p.setString(_keyKey, key.trim());
    await p.setString(
      _deviceKey,
      device.trim().isEmpty ? 'Dixit Device' : device.trim(),
    );
    await p.setString(
      _userKey,
      user.trim().isEmpty ? 'Dixit User' : user.trim(),
    );
  }

  static Future<Map<String, String>> settings() async {
    final p = await SharedPreferences.getInstance();
    return {
      'url': p.getString(_urlKey) ?? '',
      'key': p.getString(_keyKey) ?? '',
      'device': p.getString(_deviceKey) ?? 'Dixit Device',
      'user': p.getString(_userKey) ?? 'Dixit User',
    };
  }

  static Future<bool> isConfigured() async {
    final s = await settings();
    return s['url']!.isNotEmpty && s['key']!.isNotEmpty;
  }

  static http.Client _client() {
    final hc = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 40);
    return IOClient(hc);
  }

  static Map<String, String> _headers(String key) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Sync-Key': key,
      };

  static String _text(http.Response response) {
    var text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    return text.trim();
  }

  static Map<String, dynamic> _jsonMap(
    http.Response response,
    String operation,
  ) {
    final text = _text(response);
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
      final preview =
          text.length > 300 ? '${text.substring(0, 300)}…' : text;
      throw Exception(
        '$operation returned non-JSON data (HTTP ${response.statusCode}). '
        'Response: $preview',
      );
    }
  }

  static Future<http.Response> _post(
    http.Client client,
    String url,
    String key,
    Map<String, dynamic> body,
    Duration timeout,
  ) =>
      client
          .post(
            Uri.parse(url),
            headers: _headers(key),
            body: jsonEncode(body),
          )
          .timeout(timeout);

  static Future<String> _registerDevice(
    http.Client client,
    String base,
    String key,
    String deviceName,
    String deviceId,
    String userName,
  ) async {
    final r = await _post(
      client,
      '$base/api/devices/register',
      key,
      {
        'device_id': deviceId,
        'device_name': deviceName,
        'user_name': userName,
      },
      const Duration(seconds: 12),
    );
    if (r.statusCode == 403) throw Exception('DEVICE_BLOCKED');
    if (r.statusCode >= 300) {
      throw Exception(
        'Device registration failed (${r.statusCode}): ${_text(r)}',
      );
    }
    _jsonMap(r, 'Device registration');
    return _text(r);
  }

  static Future<String> sync() async {
    final s = await settings();
    final base = s['url']!.trim().replaceAll(RegExp(r'/$'), '');
    final key = s['key']!.trim();
    if (base.isEmpty || key.isEmpty) {
      return 'Cloud sync is not configured.';
    }

    final client = _client();
    var stage = 'settings';
    try {
      final p = await SharedPreferences.getInstance();
      final deviceName = p.getString(_deviceKey) ?? 'Dixit Device';
      final userName = p.getString(_userKey) ?? 'Dixit User';
      final deviceId = p.getString(_deviceIdKey) ??
          'dixit-${deviceName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
      await p.setString(_deviceIdKey, deviceId);

      stage = 'device registration';
      await _registerDevice(
        client,
        base,
        key,
        deviceName,
        deviceId,
        userName,
      );

      final headers = _headers(key);
      final all = LocalStore.snapshot();
      final records = <Map<String, dynamic>>[];
      for (final e in all.entries) {
        for (final r in e.value) {
          records.add({
            'module': e.key,
            'id': r['_id']?.toString() ?? '',
            'updated_at': r['_updatedAt']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
            'data': r,
            'deleted': r['_deleted'] == true,
          });
        }
      }

      var uploaded = 0;
      if (records.isNotEmpty) {
        stage = 'push';
        final push = await client
            .post(
              Uri.parse('$base/api/sync/push'),
              headers: headers,
              body: jsonEncode({
                'records': records,
                'device_id': deviceId,
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (push.statusCode >= 300) {
          throw Exception(
            'Push failed (${push.statusCode}): ${_text(push)}',
          );
        }
        final pushBody = _jsonMap(push, 'Cloud push');
        uploaded = int.tryParse(
              pushBody['changed']?.toString() ?? '0',
            ) ??
            0;
      }

      final since = p.getString(_sinceKey);
      final query = <String, String>{'device_id': deviceId};
      if (since != null && since.isNotEmpty) query['since'] = since;

      stage = 'pull';
      final uri = Uri.parse('$base/api/sync/pull').replace(
        queryParameters: query,
      );
      final pull = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (pull.statusCode >= 300) {
        throw Exception(
          'Pull failed (${pull.statusCode}): ${_text(pull)}',
        );
      }

      final body = _jsonMap(pull, 'Cloud pull');
      final incoming = (body['records'] as List? ?? const []).cast<Map>();
      final merged = LocalStore.snapshot();

      for (final raw in incoming) {
        final module = raw['module']?.toString() ?? '';
        if (module.isEmpty) continue;
        final data = Map<String, dynamic>.from(
          raw['data'] as Map? ?? const {},
        );
        final id = raw['id']?.toString() ?? data['_id']?.toString() ?? '';
        if (id.isEmpty) continue;

        data['_id'] = id;
        data['_updatedAt'] =
            raw['updated_at']?.toString() ?? data['_updatedAt'];
        if (raw['deleted'] == true) data['_deleted'] = true;

        final list =
            merged.putIfAbsent(module, () => <Map<String, dynamic>>[]);
        final i = list.indexWhere((x) => x['_id'] == id);
        if (i < 0) {
          list.add(data);
        } else {
          final old = list[i]['_updatedAt']?.toString() ?? '';
          final incomingUpdated = data['_updatedAt']?.toString() ?? '';
          if (old.compareTo(incomingUpdated) < 0) {
            list[i] = data;
          }
        }
      }

      await LocalStore.replaceAll(merged);
      await p.setString(
        _sinceKey,
        body['server_time']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      );

      stage = 'heartbeat';
      try {
        await client
            .post(
              Uri.parse('$base/api/devices/heartbeat'),
              headers: headers,
              body: jsonEncode({
                'device_id': deviceId,
                'device_name': deviceName,
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Heartbeat is best-effort and must not fail an otherwise successful sync.
      }

      return 'Uploaded $uploaded records • Downloaded ${incoming.length} records • Cloud Sync: Connected • Device heartbeat updated.';
    } on SocketException catch (e) {
      throw Exception('SYNC NETWORK ERROR at $stage: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('SYNC HTTP ERROR at $stage: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('SYNC FORMAT ERROR at $stage: ${e.message}');
    } catch (e) {
      throw Exception('SYNC ERROR at $stage: $e');
    } finally {
      client.close();
    }
  }
}
