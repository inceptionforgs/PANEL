import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../core/format.dart";
import "../../models/r2_object.dart";
import "../../models/scan_report.dart";
import "../../secrets.dart";
import "../../services/r2_service.dart";
import "../sync/sync_screen.dart";
import "../upload/upload_screen.dart";

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final r2 = R2Service();
  final name = TextEditingController();
  bool busy = false;
  String? error;
  ScanReport? report;
  List<String> buckets = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!Secrets.r2Ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      buckets = await r2.listBuckets();
      final objs = <R2Object>[];
      for (final b in buckets) {
        objs.addAll(await r2.listAll(bucket: b));
      }
      report = ScanReport.from(objs);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _create() async {
    final n = name.text.trim().toLowerCase();
    if (n.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await r2.createBucket(n);
      name.clear();
      await refresh();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(String b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bucket delete?"),
        content: Text("$b\nPehle khali honi chahiye."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await r2.deleteBucket(b);
      await refresh();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => refresh());
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text("Storage",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const Text("Cloudflare R2 · buckets, scan, upload, delete",
              style: TextStyle(color: AdminTheme.mute, fontSize: 12)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: 150, child: StatCard(label: "Buckets", value: "${buckets.length}")),
            SizedBox(width: 150, child: StatCard(label: "Objects", value: "${r?.objects ?? 0}")),
            SizedBox(width: 150, child: StatCard(label: "Size", value: Format.bytes(r?.bytes ?? 0))),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: "Nayi bucket",
              suffixIcon: IconButton(onPressed: busy ? null : _create, icon: const Icon(Icons.add_box)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: busy && r == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (r != null)
                        for (final b in r.buckets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.bucket),
                            subtitle: Text(
                              "${b.mp3} MP3 · ${b.folders} folders · ${Format.bytes(b.bytes)}",
                              style: const TextStyle(color: AdminTheme.mute, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                              onPressed: busy ? null : () => _delete(b.bucket),
                            ),
                          ),
                      if (r != null && r.folders.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text("Folders", style: TextStyle(fontWeight: FontWeight.w700)),
                        for (final f in r.folders)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "${f.bucket} / ${f.folder}  ·  ${f.mp3} gaane · ${Format.bytes(f.bytes)}",
                              style: const TextStyle(color: AdminTheme.silver, fontSize: 13),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: PrimaryBtn(label: "Scan + sync", onTap: () => _open(const SyncScreen())),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryBtn(
                  label: "Upload",
                  onTap: () => _open(const UploadScreen()),
                  color: AdminTheme.ok,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
