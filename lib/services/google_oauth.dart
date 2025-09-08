// Cross-platform wrapper for Google OAuth; web has the implementation.
export 'google_oauth_stub.dart'
    if (dart.library.html) 'google_oauth_web.dart'
    if (dart.library.io) 'google_oauth_io.dart';
