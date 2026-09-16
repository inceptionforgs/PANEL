import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../catalog/catalog_screen.dart";
import "../overview/overview_screen.dart";
import "../people/people_screen.dart";
import "../sql_lab/sql_lab_screen.dart";
import "../storage/storage_screen.dart";

class PanelShell extends StatefulWidget {
  const PanelShell({super.key});
  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell> {
  int index = 0;
  final seen = <int>{0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: [
            const OverviewScreen(),
            seen.contains(1) ? const StorageScreen() : const SizedBox.shrink(),
            seen.contains(2) ? const CatalogScreen() : const SizedBox.shrink(),
            seen.contains(3) ? const PeopleScreen() : const SizedBox.shrink(),
            seen.contains(4) ? const SqlLabScreen(embedded: true) : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          index = i;
          seen.add(i);
        }),
        indicatorColor: AdminTheme.line,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: "Home"),
          NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: "Storage"),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: "Catalog"),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: "People"),
          NavigationDestination(icon: Icon(Icons.terminal), selectedIcon: Icon(Icons.terminal), label: "Lab"),
        ],
      ),
    );
  }
}
