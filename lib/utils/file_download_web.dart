// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadJsonFile(
    String fileName, Map<String, dynamic> json) async {
  final data = utf8.encode(jsonEncode(json));
  final blob = html.Blob([data], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<Map<String, dynamic>?> pickJsonFile() async {
  final input = html.FileUploadInputElement();
  input.accept = 'application/json,.json';
  input.click();
  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;
  final file = input.files!.first;
  final reader = html.FileReader();
  reader.readAsText(file, 'utf-8');
  await reader.onLoad.first;
  final txt = reader.result?.toString() ?? '';
  if (txt.isEmpty) return null;
  try {
    final m = jsonDecode(txt) as Map<String, dynamic>;
    return m;
  } catch (_) {
    return null;
  }
}
