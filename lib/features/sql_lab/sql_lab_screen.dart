import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/sql_result.dart";
import "../../secrets.dart";
import "../../services/sql_runner.dart";

class SqlLabScreen extends StatefulWidget {
  const SqlLabScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<SqlLabScreen> createState() => _SqlLabScreenState();
}

class _SqlLabScreenState extends State<SqlLabScreen> {
  final sql = TextEditingController();
  SqlResult? result;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    sql.dispose();
    super.dispose();
  }

  Future<void> run() async {
    final text = sql.text.trim();
    if (text.isEmpty) return;
    final danger = SqlRunner.looksDangerous(text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(danger ? "Dangerous SQL" : "SQL run?"),
        content: Text(
          danger
              ? "Isme DELETE/DROP/TRUNCATE hai. Pakka run karna hai?"
              : "Yeh SQL database pe chalega.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      result = await SqlRunner().run(text);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "SQL Lab",
      embedded: widget.embedded,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!Secrets.dbReady)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "dbPassword secrets.dart me PASTE karo.",
                  style: TextStyle(color: AdminTheme.warn),
                ),
              ),
            Expanded(
              flex: 2,
              child: TextField(
                controller: sql,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: "monospace", fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "SQL yahan paste karo…",
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryBtn(
              label: "Run",
              onTap: Secrets.dbReady ? run : null,
              busy: busy,
              color: AdminTheme.ok,
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.line),
                ),
                child: error != null
                    ? SingleChildScrollView(
                        child: Text(error!, style: const TextStyle(color: AdminTheme.danger)),
                      )
                    : result == null
                        ? const Text("Result yahan aayega", style: TextStyle(color: AdminTheme.mute))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: result!.columns.isEmpty
                                  ? Text(result!.message ?? "OK (${result!.affected})")
                                  : DataTable(
                                      columns: [
                                        for (final c in result!.columns)
                                          DataColumn(label: Text(c)),
                                      ],
                                      rows: [
                                        for (final row in result!.rows.take(200))
                                          DataRow(cells: [
                                            for (final v in row)
                                              DataCell(Text(v, style: const TextStyle(fontSize: 11))),
                                          ]),
                                      ],
                                    ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
