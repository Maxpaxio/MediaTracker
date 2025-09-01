import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'storage.dart';

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

  SyncFileState get state => _state;
  SyncEndpoint? get endpoint => _endpoint;

  void setEndpoint(SyncEndpoint ep) {
    _endpoint = ep;
    notifyListeners();
  // Kick an immediate sync, then schedule periodic ones via a microtask loop.
  // Keep it lightweight for MVP; callers can also tap "Sync now".
  // We avoid using Timer.periodic to reduce wakeups when app is backgrounded.
  _scheduleTick();
  }

  Future<void> disconnect() async {
    _endpoint = null;
    _etag = null;
    _revision = 0;
    _state = SyncFileState.disconnected;
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
      return true;
    } catch (_) {
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

      _state = SyncFileState.idle;
      notifyListeners();
    } catch (_) {
      _state = SyncFileState.error;
      notifyListeners();
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
  const SyncEndpoint.webdav({
    required this.url,
    this.username,
    this.password,
  }) : backend = SyncBackend.webdav;
}

enum SyncBackend { webdav }

// --- WebDAV I/O ---
extension on SyncFileService {
  Future<Map<String, dynamic>?> _readRemote() async {
    final ep = _endpoint!;
    if (ep.backend != SyncBackend.webdav) return null;
    final headers = <String, String>{'accept': 'application/json'};
    if (ep.username != null && ep.password != null) {
      final cred = base64Encode(utf8.encode('${ep.username}:${ep.password}'));
      headers['authorization'] = 'Basic $cred';
    }
    final res = await http.get(Uri.parse(ep.url), headers: headers);
    if (res.statusCode == 404) return null; // treat as empty
    if (res.statusCode >= 400) throw Exception('WebDAV read failed');
    _etag = res.headers['etag'];
    final body = utf8.decode(res.bodyBytes);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _writeRemote(Map<String, dynamic> doc) async {
    final ep = _endpoint!;
    if (ep.backend != SyncBackend.webdav) return;
    final headers = <String, String>{'content-type': 'application/json'};
    if (_etag != null) headers['if-match'] = _etag!;
    if (ep.username != null && ep.password != null) {
      final cred = base64Encode(utf8.encode('${ep.username}:${ep.password}'));
      headers['authorization'] = 'Basic $cred';
    }
    final res = await http.put(Uri.parse(ep.url), headers: headers, body: jsonEncode(doc));
    if (res.statusCode >= 400) throw Exception('WebDAV write failed');
    _etag = res.headers['etag'] ?? _etag;
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
