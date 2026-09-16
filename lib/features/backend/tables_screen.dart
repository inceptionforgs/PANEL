import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/db_scan.dart";
import "../../secrets.dart";
import "../../services/db_scan.dart";
import "../../services/supabase_admin.dart";

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});
  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  bool busy = false;
  String? error;
  DbScanReport? report;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      report = await DbScan().scan();
      error = report?.error;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Tables",
      embedded: true,
      actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh))],
      body: !Secrets.supabaseReady && !Secrets.dbReady
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text("service_role + DB password secrets.dart me daalo.",
                  style: TextStyle(color: AdminTheme.warn)),
            )
          : busy && report == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (error != null)
                      Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
                    Text(
                      "${report?.tableCount ?? 0} tables  ·  ${report?.source ?? ""}",
                      style: const TextStyle(color: AdminTheme.mute, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    for (final t in report?.tables ?? const <TableStat>[])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.name),
                        subtitle: Text("${t.rows} rows",
                            style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: AdminTheme.mute),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TableRowsScreen(table: t.name, rowsHint: t.rows)),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class TableRowsScreen extends StatefulWidget {
  const TableRowsScreen({super.key, required this.table, required this.rowsHint});
  final String table;
  final int rowsHint;
  @override
  State<TableRowsScreen> createState() => _TableRowsScreenState();
}

class _TableRowsScreenState extends State<TableRowsScreen> {
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      rows = await SupabaseAdmin.instance.tableRows(widget.table);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = "${row["id"] ?? ""}";
    if (id.isEmpty) {
      setState(() => error = "Is row me id nahi — SQL Lab se hatao.");
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Row delete?"),
        content: Text("${widget.table}\nid=$id"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.deleteById(widget.table, id);
      await load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  String _preview(Map<String, dynamic> row) {
    final keys = row.keys.take(4).toList();
    return keys.map((k) => "$k: ${row[k]}").join("  ·  ");
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: widget.table,
      actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh))],
      body: busy && rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("${rows.length} loaded  ·  ${widget.rowsHint} scan count",
                    style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "${row["id"] ?? row.values.firstOrNull ?? ""}",
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      _preview(row),
                      maxLines: 3,
                      style: const TextStyle(color: AdminTheme.mute, fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                      onPressed: busy ? null : () => _delete(row),
                    ),
                  ),
              ],
            ),
    );
  }
}
