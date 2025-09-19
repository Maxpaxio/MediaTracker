import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../pages/home_page.dart';
import '../pages/films_page.dart';
import '../pages/sync_connect_page.dart';
import 'search_results_page.dart';
import '../services/settings_controller.dart';
import '../services/region.dart';
import '../widgets/tmdb_attribution.dart';

class SettingsPage extends StatefulWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _regionController = TextEditingController();
  String? _autoRegion;

  @override
  void initState() {
    super.initState();
    _autoRegion = tryDetectRegionCode();
  }

  bool _didInitFromScope = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFromScope) return;
    final settings = SettingsScope.of(context);
    _regionController.text = settings.regionOverride ?? '';
    _didInitFromScope = true;
  }

  @override
  void dispose() {
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = SettingsScope.of(context);
    final raw = _regionController.text.trim();
    if (raw.isEmpty) {
      await settings.setRegionOverride(null);
    } else {
      final resolved = resolveRegionInput(raw);
      if (resolved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown region / country name.')),
        );
        return;
      }
      await settings.setRegionOverride(resolved);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final effective = settings.effectiveRegion;
    final detected = _autoRegion;
    final usingAuto = !settings.hasExplicitOverride;

    final regionNotFound = usingAuto && detected == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Abandoned'),
                onTap: () => Navigator.pushNamed(context, '/abandoned'),
              ),
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Statistics'),
                onTap: () => Navigator.pushNamed(context, '/stats'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud storage'),
                onTap: () => Navigator.pushNamed(context, SyncConnectPage.route),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Region',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _regionController,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Override region (code or country name)',
              helperText:
                  'Examples: US, Sweden, United Kingdom, Brasil. Leave empty for auto.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Effective region'),
            subtitle:
                Text(regionNotFound ? 'Region not found' : (effective ?? '—')),
            trailing: usingAuto
                ? const Tooltip(
                    message: 'Auto', child: Icon(Icons.auto_awesome))
                : const Tooltip(message: 'Override', child: Icon(Icons.edit)),
          ),
          if (regionNotFound)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Region not found. Enter a 2-letter code manually above.',
                style: TextStyle(color: Colors.amberAccent),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TmdbAttribution(center: true, textAbove: true, height: 48),
        ),
      ),
    );
  }
}
