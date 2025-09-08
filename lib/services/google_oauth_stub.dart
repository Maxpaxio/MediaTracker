class GoogleSession {
  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken; // not used on stub
  GoogleSession(this.accessToken, this.expiresAt, this.refreshToken);
}

Future<GoogleSession?> googleSignInPkce({
  required String clientId,
  required Uri redirectUri,
  required List<String> scopes,
  bool silent = false,
}) async =>
    null;

Future<GoogleSession?> googleRefresh({
  required String clientId,
  required Uri redirectUri,
  required List<String> scopes,
  required String refreshToken,
}) async =>
    null;
