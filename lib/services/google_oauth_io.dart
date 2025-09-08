import 'package:flutter_appauth/flutter_appauth.dart';

class GoogleSession {
  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken;
  GoogleSession(this.accessToken, this.expiresAt, this.refreshToken);
}

final _appAuth = FlutterAppAuth();

Future<GoogleSession?> googleSignInPkce({
  required String clientId,
  required Uri redirectUri,
  required List<String> scopes,
  bool silent = false,
}) async {
  try {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUri.toString(),
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: scopes,
        promptValues: silent ? ['none'] : null,
      ),
    );
    if (result == null || result.accessToken == null) return null;
    final expiry = result.accessTokenExpirationDateTime ??
        DateTime.now().add(const Duration(hours: 1));
    return GoogleSession(
      result.accessToken!,
      expiry,
      result.refreshToken ?? '',
    );
  } catch (_) {
    return null;
  }
}

Future<GoogleSession?> googleRefresh({
  required String clientId,
  required Uri redirectUri,
  required List<String> scopes,
  required String refreshToken,
}) async {
  try {
    final token = await _appAuth.token(
      TokenRequest(
        clientId,
        redirectUri.toString(),
        refreshToken: refreshToken,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: scopes,
      ),
    );
    if (token == null || token.accessToken == null) return null;
    final expiry = token.accessTokenExpirationDateTime ??
        DateTime.now().add(const Duration(hours: 1));
    return GoogleSession(
      token.accessToken!,
      expiry,
      token.refreshToken ?? refreshToken,
    );
  } catch (_) {
    return null;
  }
}
