import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/sync_file_service.dart';
import '../services/google_oauth.dart';
import '../widgets/brand_logo.dart';
import 'home_page.dart';
import 'films_page.dart';
import 'search_results_page.dart';

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
        const SnackBar(
            content: Text(
                'Failed to connect. Use a WebDAV URL that allows GET/PUT. For iCloud/Drive share links, use Import/Export instead.')),
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
          const SnackBar(
              content: Text(
                  'File downloaded. Upload it to your storage and paste its URL.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _busy = true);
    try {
      // Use appropriate flow per platform. Web ignores redirectUri; iOS/Android must supply one.
      const clientId =
          '50733711904-jc6h65rtcku2k5srd0hr0fngmuvk9p15.apps.googleusercontent.com';
      final redirect = kIsWeb
          ? Uri() // unused on web
          : Uri.parse(
              'com.example.app:/oauthredirect'); // TODO: change to your scheme
      final session = await googleSignInPkce(
        clientId: clientId,
        redirectUri: redirect,
        scopes: const ['https://www.googleapis.com/auth/drive.appdata'],
      );
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in canceled or failed.')),
        );
        return;
      }

      final sync = SyncScope.of(context);
      await sync.setEndpoint(SyncEndpoint.googleDrive(
        accessToken: session.accessToken,
        expiresAt: session.expiresAt,
        clientId: clientId,
        scopes: const ['https://www.googleapis.com/auth/drive.appdata'],
        refreshToken: session.refreshToken,
      ));
      final ok = await sync.pingAndInit();
      if (ok) {
        await sync.syncNow();
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        await sync.disconnect();
        final err = SyncScope.of(context).lastError ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Google Drive: $err')),
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
      content:
          Text(ok ? 'Imported local file.' : 'Import failed or invalid JSON.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final ep = sync.endpoint;
    final connected = ep != null && sync.state != SyncFileState.disconnected;
    final isDrive = ep?.backend == SyncBackend.googleDrive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Storage'),
        leadingWidth: 96,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    BrandLogo(height: 72),
                    SizedBox(height: 12),
                    Text(
                      'MediaTracker',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, SearchResultsPage.route);
                },
              ),
              ListTile(
                leading: const Icon(Icons.live_tv),
                title: const Text('TV'),
                onTap: () => Navigator.pushReplacementNamed(context, HomePage.route),
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Films'),
                onTap: () => Navigator.pushReplacementNamed(context, FilmsPage.route),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud storage'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection summary (moved from Home)
          if (connected) ...[
            Builder(builder: (context) {
              final color = switch (sync.state) {
                SyncFileState.disconnected => Colors.white54,
                SyncFileState.idle => Colors.lightGreenAccent,
                SyncFileState.syncing => Colors.amberAccent,
                SyncFileState.error => Colors.redAccent,
              };
              final host = sync.endpointHost ?? (isDrive ? 'Google Drive' : '');
              final last = sync.lastSyncAt;
              String lastStr = '';
              if (last != null) {
                final t = TimeOfDay.fromDateTime(last);
                final hh = t.hourOfPeriod.toString().padLeft(2, '0');
                final mm = t.minute.toString().padLeft(2, '0');
                final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
                lastStr = 'Last sync: $hh:$mm $ampm';
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                isDrive
                                    ? 'Connected to Google Drive'
                                    : 'Connected to WebDAV',
                                style: Theme.of(context).textTheme.labelLarge),
                            if (host.isNotEmpty)
                              Text(host,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            if (lastStr.isNotEmpty)
                              Text(lastStr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          Text('Connect to a storage for live sync across devices.',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Option 1: Google Drive (free, web only)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!connected || isDrive)
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!connected) {
                        await _connectGoogle();
                      } else {
                        // Sync then disconnect
                        setState(() => _busy = true);
                        await sync.syncNow();
                        await sync.disconnect();
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: Icon(connected ? Icons.link_off : Icons.cloud),
              label: Text(connected
                  ? 'Sync & Disconnect Google Drive'
                  : 'Connect Google Drive'),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text('Option 2: WebDAV URL',
              style: Theme.of(context).textTheme.titleSmall),
          const Text(
              'Enter the full URL to your tv_tracker_sync.json on a storage that supports WebDAV (GET/PUT).'),
          const SizedBox(height: 8),
          const Text(
              'No file yet? Create one from your current local library, upload it to your storage, then paste its WebDAV URL. Note: iCloud/Google Drive share links are typically read-only and won\'t work for live sync. Use Import/Export with those.'),
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
          if (!connected || !isDrive)
            ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (!connected) {
                        await _connect();
                      } else {
                        // Sync then disconnect for WebDAV
                        setState(() => _busy = true);
                        await sync.syncNow();
                        await sync.disconnect();
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(connected ? Icons.link_off : Icons.cloud_sync),
              label: Text(connected ? 'Sync & Disconnect' : 'Connect & Sync'),
            ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('Don\'t have a file yet?',
              style: Theme.of(context).textTheme.titleMedium),
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
