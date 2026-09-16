import 'package:flutter/material.dart';
import '../config/theme.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floating,
    this.embedded = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floating;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                ...?actions,
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: actions,
      ),
      floatingActionButton: floating,
      body: body,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.hint});
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                color: AdminTheme.silver,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              )),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(color: AdminTheme.mute, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class PrimaryBtn extends StatelessWidget {
  const PrimaryBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.color,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? AdminTheme.accent,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
