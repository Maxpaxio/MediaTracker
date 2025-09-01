import 'dart:convert';

Future<void> downloadJsonFile(String fileName, Map<String, dynamic> json) async {
  // No-op outside web; future backends (mobile/desktop) can implement share/save dialogs.
}

Future<Map<String, dynamic>?> pickJsonFile() async {
  // Not supported outside web without file picker packages.
  return null;
}
