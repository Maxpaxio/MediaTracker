import 'package:flutter/material.dart';
import '../services/sync_file_service.dart';

/// AppBar actions: status dot + Sync Now button.
/// Use this in any page's AppBar `actions` to keep sync controls consistent.
class SyncActions extends StatefulWidget {
  const SyncActions({super.key});

  @override
  State<SyncActions> createState() => _SyncActionsState();
}

class _SyncActionsState extends State<SyncActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respond to SyncScope updates.
    final sync = SyncScope.of(context);
    final shouldSpin = sync.state == SyncFileState.syncing;
    if (shouldSpin && !_spinning) {
      _controller.repeat();
      _spinning = true;
    } else if (!shouldSpin && _spinning) {
      _controller.stop();
      _controller.value = 0; // reset to upright
      _spinning = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _dotColor(SyncFileState state) {
    switch (state) {
      case SyncFileState.disconnected:
        return Colors.white54;
      case SyncFileState.idle:
        return Colors.lightGreenAccent;
      case SyncFileState.syncing:
        return Colors.amberAccent;
      case SyncFileState.error:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final isSyncing = sync.state == SyncFileState.syncing;
    final isError = sync.state == SyncFileState.error;
    final isDisconnected = sync.state == SyncFileState.disconnected || sync.endpoint == null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.circle, size: 10, color: _dotColor(sync.state)),
        ),
        if (isError || isDisconnected)
          IconButton(
            tooltip: isError ? (sync.lastError ?? 'Reconnect') : 'Connect',
            onPressed: isSyncing ? null : () => sync.reconnect(),
            icon: const Icon(Icons.refresh),
          )
        else
          IconButton(
            tooltip: isSyncing ? 'Syncing…' : 'Sync now',
            onPressed: isSyncing ? null : () => sync.syncNow(),
            icon: RotationTransition(
              turns: _spinning ? _controller : const AlwaysStoppedAnimation(0),
              child: const Icon(Icons.sync),
            ),
          ),
      ],
    );
  }
}
