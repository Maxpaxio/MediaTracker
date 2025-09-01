import 'package:flutter/material.dart';
import '../services/sync_file_service.dart';

class SyncConnectPage extends StatefulWidget {
  static const route = '/sync-connect';
  const SyncConnectPage({super.key});

  @override
  State<SyncConnectPage> createState() => _SyncConnectPageState();
}

class _SyncConnectPageState extends State<SyncConnectPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final sync = SyncScope.of(context);
    setState(() => _busy = true);
  await sync.setEndpoint(SyncEndpoint.webdav(
      url: _url.text.trim(),
      username: _user.text.isEmpty ? null : _user.text.trim(),
      password: _pass.text.isEmpty ? null : _pass.text,
    ));
    final ok = await sync.pingAndInit();
    if (ok) {
      await sync.syncNow();
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      await sync.disconnect(); // revert to disconnected if connect fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect. Use a WebDAV URL that allows GET/PUT. For iCloud/Drive share links, use Import/Export instead.')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _createNewFile() async {
    // Export current local state as a new file for the user to save (web download).
    final sync = SyncScope.of(context);
    setState(() => _busy = true);
    try {
      await sync.exportCurrent('tv_tracker_sync.json');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File downloaded. Upload it to your storage and paste its URL.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExistingFile() async {
    final sync = SyncScope.of(context);
    setState(() => _busy = true);
    final ok = await sync.importFromPicker();
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Imported local file.' : 'Import failed or invalid JSON.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(title: const Text('Connect Storage (WebDAV)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Enter the full URL to your tv_tracker_sync.json on a storage that supports WebDAV (GET/PUT).'),
      const SizedBox(height: 8),
          const Text('No file yet? Create one from your current local library, upload it to your storage, then paste its WebDAV URL. Note: iCloud/Google Drive share links are typically read-only and won\'t work for live sync. Use Import/Export with those.'),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
        labelText: 'File URL (https://server/path/tv_tracker_sync.json)',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Username (optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (optional)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync),
            label: const Text('Connect & Sync'),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('Don\'t have a file yet?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _createNewFile,
              icon: const Icon(Icons.download),
              label: const Text('Create & Download File'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _importExistingFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import Local File'),
            ),
          ]),
        ],
      ),
    );
  }
}
