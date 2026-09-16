import "package:flutter/material.dart";

import "config/theme.dart";
import "features/shell/panel_shell.dart";

class MewatiAdminApp extends StatelessWidget {
  const MewatiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Mewati Panel",
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark(),
      home: const PanelShell(),
    );
  }
}
