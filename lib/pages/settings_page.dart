import 'package:flutter/material.dart';
import '../services/settings_controller.dart';
import '../services/region.dart';

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
      appBar: AppBar(title: const Text('Settings')),
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
    );
  }
}
