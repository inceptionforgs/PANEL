import "package:flutter/material.dart";

import "../listeners/listeners_screen.dart";
import "../singers/applications_screen.dart";

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          TabBar(
            tabs: [
              Tab(text: "Live"),
              Tab(text: "KYC"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListenersScreen(embedded: true),
                ApplicationsScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
