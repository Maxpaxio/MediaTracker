// Cross-platform wrapper with conditional imports for web-only download.
import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
