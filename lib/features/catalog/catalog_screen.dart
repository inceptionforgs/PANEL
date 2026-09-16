import "package:flutter/material.dart";

import "../backend/auth_users_screen.dart";
import "../backend/sb_files_screen.dart";
import "../backend/tables_screen.dart";
import "../monitor/monitor_screen.dart";

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Scan"),
              Tab(text: "Tables"),
              Tab(text: "Files"),
              Tab(text: "Auth"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                MonitorScreen(embedded: true),
                TablesScreen(),
                SbFilesScreen(),
                AuthUsersScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
