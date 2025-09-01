// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:js/js.dart';

class GoogleSession {
  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken; // not provided by GIS token client
  GoogleSession(this.accessToken, this.expiresAt, this.refreshToken);
}

Future<GoogleSession?> googleSignInPkce({
  required String clientId,
  required Uri redirectUri, // unused with GIS token client, kept for API compat
  required List<String> scopes,
}) async {
  // Load Google Identity Services script
  const src = 'https://accounts.google.com/gsi/client';
  if (html.document.querySelector('script[src="$src"]') == null) {
    final s = html.ScriptElement()..src = src..async = true;
    final c = Completer<void>();
    s.onLoad.first.then((_) => c.complete());
    html.document.head!.append(s);
    await c.future;
  }

  // Wait for window.google.accounts.oauth2
  for (int i = 0; i < 100; i++) {
    final google = js_util.getProperty(html.window, 'google');
    if (google != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final google = js_util.getProperty(html.window, 'google');
  if (google == null) return null;
  final accounts = js_util.getProperty(google, 'accounts');
  final oauth2 = js_util.getProperty(accounts, 'oauth2');

  final completer = Completer<GoogleSession?>();

  void handleResponse(dynamic resp) {
    final error = js_util.getProperty(resp, 'error');
    if (error != null) {
      completer.complete(null);
      return;
    }
    final token = js_util.getProperty(resp, 'access_token') as String?;
    final expiresIn = (js_util.getProperty(resp, 'expires_in') as num?)?.toInt() ?? 0;
    if (token != null && token.isNotEmpty) {
      completer.complete(GoogleSession(token, DateTime.now().add(Duration(seconds: expiresIn)), ''));
    } else {
      completer.complete(null);
    }
  }

  final config = js_util.newObject();
  js_util.setProperty(config, 'client_id', clientId);
  js_util.setProperty(config, 'scope', scopes.join(' '));
  js_util.setProperty(config, 'prompt', 'consent');
  js_util.setProperty(config, 'callback', allowInterop(handleResponse));

  final tokenClient = js_util.callMethod(oauth2, 'initTokenClient', [config]);
  js_util.callMethod(tokenClient, 'requestAccessToken', []);

  return completer.future.timeout(const Duration(minutes: 3), onTimeout: () => null);
}
