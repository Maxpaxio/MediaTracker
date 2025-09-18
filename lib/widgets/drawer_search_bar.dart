import 'package:flutter/material.dart';

/// A search bar to be used inside the navigation drawer.
///
/// Behavior:
/// - If a [controller] is provided (e.g. on the homepage), it updates it directly.
/// - Otherwise, it navigates to `/` (MediaHomePage) with an `initialQuery` argument, so
///   the homepage starts searching immediately with the typed query.
class DrawerSearchBar extends StatefulWidget {
  const DrawerSearchBar({
    super.key,
    this.controller,
    this.onQuery,
    this.hintText = 'Search movies, TV shows, and people…',
  });

  final TextEditingController? controller;
  final void Function(String)? onQuery;
  final String hintText;

  @override
  State<DrawerSearchBar> createState() => _DrawerSearchBarState();
}

class _DrawerSearchBarState extends State<DrawerSearchBar> {
  late final TextEditingController _local;

  @override
  void initState() {
    super.initState();
    _local = TextEditingController();
  }

  @override
  void dispose() {
    _local.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    // If we have a controller (on homepage), just update it directly
    if (widget.controller != null) {
      widget.controller!.text = query;
      widget.onQuery?.call(query);
      // Try to find a callback in the state tree. The homepage wires onChanged to search.
      // To ensure search starts, dispatch a fake change via NotificationListener if any,
      // otherwise rely on the homepage reading controller text at build and calling onChanged.
      // As a pragmatic approach, pop the drawer and rebuild the page where onChanged is wired.
      Navigator.of(context).pop();
      return;
    }

  // Else, navigate to dedicated search page with the query
    Navigator.of(context).pop();
  Navigator.of(context).pushNamed('/search', arguments: {'initialQuery': query});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: widget.controller ?? _local,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        onChanged: (value) {
          if (widget.controller != null) {
            // On homepage: propagate live changes to trigger search debounce
            widget.onQuery?.call(value);
          }
          // When not on homepage, wait for submit to navigate; avoids first-letter stuck bug
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
