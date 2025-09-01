import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'storage.dart';
import '../utils/file_download.dart';

/// A simple, file-based sync service using a single JSON file in a remote store.
/// MVP backend: WebDAV via basic auth. Others (Drive/OneDrive/local file) can plug later.
class SyncFileService extends ChangeNotifier {
  final AppStorage storage;
  SyncFileService(this.storage);

  SyncEndpoint? _endpoint;
  SyncFileState _state = SyncFileState.disconnected;
  int _revision = 0;
  String? _etag; // last known version from server when available
  Duration interval = const Duration(seconds: 45);
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastSyncAt; // last successful sync time
  String? _lastError; // last error message (for UI)

  SyncFileState get state => _state;
  SyncEndpoint? get endpoint => _endpoint;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  String? get endpointHost {
    final ep = _endpoint;
    if (ep == null) return null;
    if (ep.backend == SyncBackend.googleDrive) return 'Google Drive';
    final url = ep.url;
    if (url.isEmpty) return null;
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    // Try restore last endpoint
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('sync.endpoint');
    if (json != null) {
      try {
        final m = jsonDecode(json) as Map<String, dynamic>;
        final ep = SyncEndpoint.fromJson(m);
        _endpoint = ep;
        _state = SyncFileState.idle;
        notifyListeners();
        _scheduleTick();
      } catch (_) {}
    }
  }

  Future<void> setEndpoint(SyncEndpoint ep) async {
    _endpoint = ep;
    notifyListeners();
  // Kick an immediate sync, then schedule periodic ones via a microtask loop.
  // Keep it lightweight for MVP; callers can also tap "Sync now".
  // We avoid using Timer.periodic to reduce wakeups when app is backgrounded.
  _scheduleTick();
    // Persist
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync.endpoint', jsonEncode(ep.toJson()));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _endpoint = null;
    _etag = null;
    _revision = 0;
    _state = SyncFileState.disconnected;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync.endpoint');
    } catch (_) {}
    notifyListeners();
  }

  /// Ensures the remote file exists; if not, creates it with current local data.
  /// Returns true on success.
  Future<bool> pingAndInit() async {
    if (_endpoint == null) return false;
    try {
      final remote = await _readRemote();
      if (remote == null) {
        // Create with current local content
        await _writeRemote(_toDoc(storage.all));
      }
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  void _scheduleTick() {
    Future<void>.delayed(const Duration(seconds: 1), () async {
      if (_endpoint == null) return; // disconnected
      final now = DateTime.now();
      if (now.difference(_lastRun) >= interval && _state != SyncFileState.syncing) {
        _lastRun = now;
        try { await syncNow(); } catch (_) {}
      }
      // Reschedule while connected
      _scheduleTick();
    });
  }

  /// Pull-merge-push loop entry. Safe to call often.
  Future<void> syncNow() async {
    if (_endpoint == null) return;
    _state = SyncFileState.syncing;
    notifyListeners();
  try {
      final remote = await _readRemote();
      final local = _toDoc(storage.all);

      final merged = _merge(remote, local);
      // If merged equals remote, no write; if differs, write back.
      if (!_deepEquals(merged, remote)) {
        await _writeRemote(merged);
      }
      // Replace local with merged to keep consistent ordering/content.
      storage.replaceAll(_fromDoc(merged));

  _lastSyncAt = DateTime.now();
      _lastError = null;
      _state = SyncFileState.idle;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _state = SyncFileState.error;
      notifyListeners();
    }
  }

  // Export current local state to a downloaded JSON file (web only).
  Future<void> exportCurrent(String fileName) async {
    final doc = _toDoc(storage.all);
    await downloadJsonFile(fileName, doc);
  }

  // Import a JSON doc (web file picker), replace local, and push to remote if connected.
  Future<bool> importFromPicker() async {
    final m = await pickJsonFile();
    if (m == null) return false;
    try {
      // Merge imported (as remote) with current local
      final localDoc = _toDoc(storage.all);
      final mergedDoc = _merge(m, localDoc);
      final mergedItems = _fromDoc(mergedDoc);
      storage.replaceAll(mergedItems);
      if (_endpoint != null) {
        // Push merged doc to remote
        await _writeRemote(mergedDoc);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- JSON schema helpers ---
  Map<String, dynamic> _toDoc(List<Show> shows) {
    return {
      'schemaVersion': 1,
      'revision': _revision,
      'items': shows.map((s) => s.toJson()).toList(),
    };
  }

  List<Show> _fromDoc(Map<String, dynamic> m) {
    final items = (m['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Show.fromJson)
        .toList();
    return items;
  }

  Map<String, dynamic> _merge(
      Map<String, dynamic>? remote, Map<String, dynamic> local) {
    if (remote == null) return local;
    final rItems = (remote['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final lItems = (local['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    final byId = <int, Map<String, dynamic>>{};
    for (final m in rItems) {
      byId[m['id'] as int] = m;
    }
    for (final m in lItems) {
      final id = m['id'] as int;
      if (!byId.containsKey(id)) {
        byId[id] = m;
      } else {
        // Last-write-wins by updated timestamp if present; else prefer local.
        final a = byId[id]!;
        final ru = (a['updatedAt'] as int?) ?? 0;
        final lu = (m['updatedAt'] as int?) ?? (DateTime.now().millisecondsSinceEpoch);
        byId[id] = lu >= ru ? m : a;
      }
    }

    final merged = byId.values.toList();
    return {
      'schemaVersion': 1,
      'revision': ((remote['revision'] as int?) ?? 0) + 1,
      'items': merged,
    };
  }

  bool _deepEquals(Object? a, Object? b) => const DeepCollectionEquality().equals(a, b);
}

enum SyncFileState { disconnected, syncing, idle, error }

// Simple endpoint abstraction; MVP supports WebDAV.
class SyncEndpoint {
  final SyncBackend backend;
  final String url; // full URL to the JSON file
  final String? username;
  final String? password;
  // Google Drive fields
  final String? googleAccessToken;
  final int? googleExpiresAtMs; // epoch ms
  final String? googleFileId; // resolved appDataFolder file id

  const SyncEndpoint.webdav({
    required this.url,
    this.username,
    this.password,
  })  : backend = SyncBackend.webdav,
        googleAccessToken = null,
        googleExpiresAtMs = null,
        googleFileId = null;

  SyncEndpoint.googleDrive({
    required String accessToken,
    required DateTime expiresAt,
    String? fileId,
  })  : backend = SyncBackend.googleDrive,
        url = '',
        username = null,
        password = null,
        googleAccessToken = accessToken,
        googleExpiresAtMs = expiresAt.millisecondsSinceEpoch,
        googleFileId = fileId;

  Map<String, dynamic> toJson() => {
        'backend': backend.name,
        'url': url,
        'username': username,
        'password': password,
  'googleAccessToken': googleAccessToken,
  'googleExpiresAtMs': googleExpiresAtMs,
  'googleFileId': googleFileId,
      };

  factory SyncEndpoint.fromJson(Map<String, dynamic> m) {
    final be = (m['backend'] as String?) ?? 'webdav';
    switch (be) {
      case 'googleDrive':
        return SyncEndpoint.googleDrive(
          accessToken: (m['googleAccessToken'] as String?) ?? '',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
              (m['googleExpiresAtMs'] as num?)?.toInt() ?? 0),
          fileId: m['googleFileId'] as String?,
        );
      case 'webdav':
        return SyncEndpoint.webdav(
          url: (m['url'] as String?) ?? '',
          username: m['username'] as String?,
          password: m['password'] as String?,
        );
      default:
        return SyncEndpoint.webdav(
          url: (m['url'] as String?) ?? '',
          username: m['username'] as String?,
          password: m['password'] as String?,
        );
    }
  }
}

enum SyncBackend { webdav, googleDrive }

// --- WebDAV I/O ---
extension on SyncFileService {
  Future<Map<String, dynamic>?> _readRemote() async {
    final ep = _endpoint!;
    if (ep.backend == SyncBackend.googleDrive) {
      return _gdRead(ep);
    }
    if (ep.backend != SyncBackend.webdav) return null;
    final headers = <String, String>{'accept': 'application/json'};
    if (ep.username != null && ep.password != null) {
      final cred = base64Encode(utf8.encode('${ep.username}:${ep.password}'));
      headers['authorization'] = 'Basic $cred';
    }
    final res = await http.get(Uri.parse(ep.url), headers: headers);
    if (res.statusCode == 404) return null; // treat as empty
    if (res.statusCode >= 400) {
      throw Exception('WebDAV read failed: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
    _etag = res.headers['etag'];
    final body = utf8.decode(res.bodyBytes);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _writeRemote(Map<String, dynamic> doc) async {
    final ep = _endpoint!;
    if (ep.backend == SyncBackend.googleDrive) {
      await _gdWrite(ep, doc);
      return;
    }
    if (ep.backend != SyncBackend.webdav) return;
    final headers = <String, String>{'content-type': 'application/json'};
    if (_etag != null) headers['if-match'] = _etag!;
    if (ep.username != null && ep.password != null) {
      final cred = base64Encode(utf8.encode('${ep.username}:${ep.password}'));
      headers['authorization'] = 'Basic $cred';
    }
    final res = await http.put(Uri.parse(ep.url), headers: headers, body: jsonEncode(doc));
    if (res.statusCode >= 400) {
      throw Exception('WebDAV write failed: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
    _etag = res.headers['etag'] ?? _etag;
  }
}

// --- Google Drive (appDataFolder) I/O ---
extension _GoogleDrive on SyncFileService {
  bool _gdExpired(SyncEndpoint ep) {
    final ms = ep.googleExpiresAtMs ?? 0;
    if (ms == 0) return true;
    return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(ms - 30 * 1000));
  }

  Future<String> _gdEnsureFileId(SyncEndpoint ep) async {
    if ((ep.googleFileId ?? '').isNotEmpty) return ep.googleFileId!;
    if (_gdExpired(ep)) throw Exception('Google token expired');
    final token = ep.googleAccessToken!;
    // List existing in appDataFolder by name
    final listUri = Uri.parse('https://www.googleapis.com/drive/v3/files').replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name = 'tv_tracker_sync.json'",
      'fields': 'files(id,name)',
      'pageSize': '1',
    });
    final lr = await http.get(listUri, headers: {'authorization': 'Bearer $token'});
    if (lr.statusCode == 401) throw Exception('Drive unauthorized (401)');
    if (lr.statusCode >= 400) {
      throw Exception('Drive list failed: ${lr.statusCode} ${utf8.decode(lr.bodyBytes)}');
    }
    final body = jsonDecode(utf8.decode(lr.bodyBytes)) as Map<String, dynamic>;
    final files = (body['files'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    String fileId;
    if (files.isNotEmpty) {
      fileId = (files.first['id'] as String?) ?? '';
    } else {
      // Create metadata in appDataFolder
      final mr = await http.post(
        Uri.parse('https://www.googleapis.com/drive/v3/files').replace(queryParameters: {'fields': 'id'}),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'name': 'tv_tracker_sync.json',
          'parents': ['appDataFolder'],
        }),
      );
      if (mr.statusCode >= 400) {
        throw Exception('Drive create failed: ${mr.statusCode} ${utf8.decode(mr.bodyBytes)}');
      }
      fileId = ((jsonDecode(mr.body) as Map)['id'] as String?) ?? '';
      // Initialize content
      await _gdUpload(fileId, token, _toDoc(storage.all));
    }
    // Save back endpoint with fileId
    final newEp = SyncEndpoint.googleDrive(
      accessToken: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(ep.googleExpiresAtMs ?? 0),
      fileId: fileId,
    );
    await setEndpoint(newEp);
    return fileId;
  }

  Future<Map<String, dynamic>?> _gdRead(SyncEndpoint ep) async {
    if (_gdExpired(ep)) throw Exception('Google token expired');
    final token = ep.googleAccessToken!;
    final fileId = await _gdEnsureFileId(ep);
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId').replace(queryParameters: {'alt': 'media'});
    final r = await http.get(uri, headers: {'authorization': 'Bearer $token'});
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) {
      throw Exception('Drive read failed: ${r.statusCode} ${utf8.decode(r.bodyBytes)}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _gdWrite(SyncEndpoint ep, Map<String, dynamic> doc) async {
    if (_gdExpired(ep)) throw Exception('Google token expired');
    final token = ep.googleAccessToken!;
    final fileId = await _gdEnsureFileId(ep);
    await _gdUpload(fileId, token, doc);
  }

  Future<void> _gdUpload(String fileId, String token, Map<String, dynamic> doc) async {
    final uri = Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$fileId').replace(queryParameters: {
      'uploadType': 'media',
    });
    final r = await http.patch(uri,
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(doc));
    if (r.statusCode >= 400) {
      throw Exception('Drive upload failed: ${r.statusCode} ${utf8.decode(r.bodyBytes)}');
    }
  }
}

// Lightweight DeepCollectionEquality to avoid extra deps; limited to maps/lists/values.
class DeepCollectionEquality {
  const DeepCollectionEquality();
  bool equals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) return _mapEquals(a, b);
    if (a is List && b is List) return _listEquals(a, b);
    return a == b;
  }

  bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      if (!equals(a[k], b[k])) return false;
    }
    return true;
  }

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!equals(a[i], b[i])) return false;
    }
    return true;
  }
}

// Inherited notifier to access the sync service easily.
class SyncScope extends InheritedNotifier<SyncFileService> {
  const SyncScope({super.key, required SyncFileService sync, required super.child})
      : super(notifier: sync);

  static SyncFileService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()!.notifier!;
}
