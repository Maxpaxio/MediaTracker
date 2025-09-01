// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

class GoogleSession {
  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken; // not provided by GIS token client
  GoogleSession(this.accessToken, this.expiresAt, this.refreshToken);
}

Future<GoogleSession?> googleSignInPkce({
  required String clientId,
  required Uri redirectUri,
  required List<String> scopes,
}) async {
  // Load GIS script if needed
  const src = 'https://accounts.google.com/gsi/client';
  if (html.document.querySelector('script[src="$src"]') == null) {
    final s = html.ScriptElement()..src = src..async = true;
    final c = Completer<void>();
    s.onLoad.first.then((_) => c.complete());
    html.document.head!.append(s);
    await c.future;
  }

  final completer = Completer<GoogleSession?>();
  // @dart = 2.19 style interop; call through JS via context is noisy. Instead we use the token endpoint via implicit flow through popup.
  // Fallback: open oauth2/v2/auth with response_type=token (implicit), acceptable for this MVP.
  final authUrl = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth').replace(queryParameters: {
    'client_id': clientId,
    'redirect_uri': redirectUri.toString(),
    'response_type': 'token',
    'scope': scopes.join(' '),
    'include_granted_scopes': 'true',
    'prompt': 'consent',
  });

  final w = html.window.open(authUrl.toString(), 'google_oauth', 'width=500,height=600');
  late html.EventListener sub;
  sub = (event) {
    if (event is html.MessageEvent && event.origin == redirectUri.origin) {
      final hash = event.data?.toString() ?? '';
      if (hash.contains('access_token=')) {
        final frag = Uri.splitQueryString(hash.replaceFirst('#', ''));
        final token = frag['access_token'];
        final expires = int.tryParse(frag['expires_in'] ?? '0') ?? 0;
        if (token != null && token.isNotEmpty) {
          html.window.removeEventListener('message', sub);
          try { w?.close(); } catch (_) {}
          completer.complete(GoogleSession(token, DateTime.now().add(Duration(seconds: expires)), ''));
        }
      }
    }
  };
  html.window.addEventListener('message', sub);
  return completer.future.timeout(const Duration(minutes: 3), onTimeout: () => null);
}
