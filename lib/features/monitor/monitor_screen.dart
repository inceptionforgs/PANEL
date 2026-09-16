import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../core/format.dart";
import "../../models/catalog_diff.dart";
import "../../models/db_scan.dart";
import "../../models/r2_object.dart";
import "../../models/scan_report.dart";
import "../../secrets.dart";
import "../../services/catalog_sync.dart";
import "../../services/db_scan.dart";
import "../../services/r2_service.dart";
import "../../services/supabase_admin.dart";

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  bool busy = false;
  String? error;
  Map<String, int> db = {};
  ScanReport? report;
  DbScanReport? dbScan;
  CatalogDiff? diff;
  List<String> dupes = [];
  Map<String, int> cats = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      List<Map<String, dynamic>> rows = [];
      if (Secrets.supabaseReady || Secrets.dbReady) {
        try {
          db = await SupabaseAdmin.instance.monitorCounts();
        } catch (_) {}
        try {
          rows = await SupabaseAdmin.instance.songs();
        } catch (_) {}
        dbScan = await DbScan().scan();
      }
      if (Secrets.r2Ready) {
        final r2 = R2Service();
        final names = await r2.listBuckets();
        final objs = <R2Object>[];
        for (final b in names) {
          objs.addAll(await r2.listAll(bucket: b));
        }
        report = ScanReport.from(objs);
        final scanned = CatalogSync.songsFromR2(objs);
        cats = CatalogSync.byCategory(scanned);
        dupes = CatalogSync.duplicateTitles(scanned);
        if (rows.isNotEmpty || Secrets.supabaseReady) {
          diff = CatalogSync.diff(scanned: scanned, dbRows: rows);
        }
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final missing = diff?.missingInDb.length ?? 0;
    final already = diff?.alreadyInDb.length ?? 0;
    return AdminScaffold(
      title: "Monitor",
      embedded: widget.embedded,
      actions: [
        IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh)),
      ],
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null)
                  Text(error!, style: const TextStyle(color: AdminTheme.danger)),
                const Text("Admin snapshot", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _w(StatCard(label: "R2 MP3", value: "${r?.mp3 ?? 0}")),
                  _w(StatCard(label: "Player / DB", value: "${db["songs"] ?? 0}")),
                  _w(StatCard(
                    label: "Catalog me nahi",
                    value: "$missing",
                    hint: already > 0 ? "$already pehle se DB me" : null,
                  )),
                  _w(StatCard(label: "Duplicates", value: "${dupes.length}")),
                  _w(StatCard(label: "Pending KYC", value: "${db["pending"] ?? 0}")),
                  _w(StatCard(label: "R2 size", value: Format.bytes(r?.bytes ?? 0))),
                ]),
                const SizedBox(height: 22),
                const Text("Cloudflare R2", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _w(StatCard(label: "Buckets", value: "${r?.buckets.length ?? 0}")),
                  _w(StatCard(label: "Files", value: "${r?.objects ?? 0}")),
                  _w(StatCard(label: "Folders", value: "${r?.folderCount ?? 0}")),
                  _w(StatCard(label: "Baaki files", value: "${r?.other ?? 0}")),
                ]),
                if (r != null && r.buckets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final b in r.buckets)
                    _line(
                      b.bucket,
                      "${b.objects} objects · ${b.mp3} MP3 · ${b.folders} folders · ${Format.bytes(b.bytes)}",
                    ),
                ],
                if (r != null && r.folders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Folders", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final f in r.folders)
                    _line(
                      "${f.bucket} / ${f.folder}",
                      "${f.mp3} gaane · ${f.objects} files · ${Format.bytes(f.bytes)}",
                    ),
                ],
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Categories (R2)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final e in cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                    _line(e.key, "${e.value} MP3"),
                ],
                if (dupes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Duplicates", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AdminTheme.warn)),
                  const SizedBox(height: 8),
                  for (final d in dupes) _line(d, "R2 pe same title 2+ files"),
                ],
                const SizedBox(height: 22),
                const Text("Supabase scan", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (dbScan?.error != null)
                  Text(dbScan!.error!, style: const TextStyle(color: AdminTheme.warn, fontSize: 13))
                else if (dbScan != null) ...[
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _w(StatCard(label: "Tables", value: "${dbScan!.tableCount}")),
                    _w(StatCard(label: "Songs", value: "${dbScan!.songs}")),
                    _w(StatCard(label: "Singers", value: "${dbScan!.singers}")),
                    _w(StatCard(label: "Via", value: dbScan!.source)),
                  ]),
                  const SizedBox(height: 10),
                  for (final t in dbScan!.tables)
                    _line(t.name, "${t.rows} rows"),
                  if (dbScan!.songCategories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text("Songs by category", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    for (final e in dbScan!.songCategories.entries)
                      _line(e.key, "${e.value} songs"),
                  ],
                ] else
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _w(StatCard(label: "Songs", value: "${db["songs"] ?? 0}")),
                    _w(StatCard(label: "Singers", value: "${db["singers"] ?? 0}")),
                    _w(StatCard(label: "Pending KYC", value: "${db["pending"] ?? 0}")),
                    _w(StatCard(label: "Applications", value: "${db["applications"] ?? 0}")),
                    _w(StatCard(label: "Likes", value: "${db["likes"] ?? 0}")),
                    _w(StatCard(label: "Favorites", value: "${db["favorites"] ?? 0}")),
                  ]),
              ],
            ),
    );
  }

  Widget _w(Widget child) => SizedBox(width: 160, child: child);

  Widget _line(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AdminTheme.silver, fontSize: 13)),
          Text(sub, style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
        ],
      ),
    );
  }
}
