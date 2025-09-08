// Cross-platform wrapper with conditional imports for web-only download.

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
