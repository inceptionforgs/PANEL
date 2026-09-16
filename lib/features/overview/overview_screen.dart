import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../core/format.dart";
import "../../models/listen_session.dart";
import "../../models/owner_usage.dart";
import "../../models/r2_object.dart";
import "../../models/scan_report.dart";
import "../../secrets.dart";
import "../../services/catalog_sync.dart";
import "../../services/cloudflare_owner.dart";
import "../../services/r2_service.dart";
import "../../services/sql_runner.dart";
import "../../services/supabase_admin.dart";
import "../sync/sync_screen.dart";
import "../upload/upload_screen.dart";

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool busy = false;
  String? error;
  Map<String, int> db = {};
  ScanReport? report;
  int live = 0;
  int missing = 0;
  int dupes = 0;
  int pending = 0;
  OwnerUsage? usage;
  int? dbBytes;

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
      final futures = <Future<void>>[
        _db(),
        _r2(),
        _live(),
        _billing(),
        _dbSize(),
      ];
      await Future.wait(futures);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _db() async {
    if (!Secrets.supabaseReady) return;
    db = await SupabaseAdmin.instance.monitorCounts();
    pending = db["pending"] ?? 0;
  }

  Future<void> _live() async {
    if (!Secrets.supabaseReady) return;
    try {
      final rows = await SupabaseAdmin.instance.listenSessions();
      live = rows.where((ListenSession s) => s.live).length;
    } catch (_) {
      live = 0;
    }
  }

  Future<void> _r2() async {
    if (!Secrets.r2Ready) return;
    final r2 = R2Service();
    final names = await r2.listBuckets();
    final objs = <R2Object>[];
    for (final b in names) {
      objs.addAll(await r2.listAll(bucket: b));
    }
    report = ScanReport.from(objs);
    if (Secrets.supabaseReady) {
      final rows = await SupabaseAdmin.instance.songs();
      final scanned = CatalogSync.songsFromR2(objs);
      final diff = CatalogSync.diff(scanned: scanned, dbRows: rows);
      missing = diff.missingInDb.length;
      dupes = CatalogSync.duplicateTitles(scanned).length;
    }
  }

  Future<void> _billing() async {
    if (!Secrets.cfReady) {
      usage = const OwnerUsage(error: "Cloudflare API token PASTE karo (Billing Read + Analytics Read).");
      return;
    }
    usage = await CloudflareOwner().load();
  }

  Future<void> _dbSize() async {
    if (!Secrets.dbReady) return;
    try {
      final r = await SqlRunner().run("select pg_database_size(current_database()) as bytes;");
      if (r.rows.isNotEmpty && r.rows.first.isNotEmpty) {
        dbBytes = int.tryParse(r.rows.first.first);
      }
    } catch (_) {}
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final u = usage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text("Overview",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: busy ? null : refresh,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text("Private panel · sirf tera phone",
            style: TextStyle(color: AdminTheme.mute, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _dot("R2", Secrets.r2Ready),
          _dot("Supabase", Secrets.supabaseReady),
          _dot("SQL", Secrets.dbReady),
          _dot("Billing", Secrets.cfReady && u?.error == null),
        ]),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _w(StatCard(label: "Live now", value: "$live")),
          _w(StatCard(label: "Pending KYC", value: "$pending")),
          _w(StatCard(label: "R2 MP3", value: "${r?.mp3 ?? 0}")),
          _w(StatCard(label: "Player / DB", value: "${db["songs"] ?? 0}")),
          _w(StatCard(label: "Catalog me nahi", value: "$missing")),
          _w(StatCard(label: "R2 size", value: Format.bytes(r?.bytes ?? 0))),
        ]),
        const SizedBox(height: 22),
        const Text("Cloudflare bill",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        _billingCard(u),
        const SizedBox(height: 22),
        const Text("Supabase",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        _line("Database size", dbBytes == null ? "SQL password nahi" : Format.bytes(dbBytes!)),
        _line("Free quota", "500 MB (Free plan freeze)"),
        if (dbBytes != null) _bar(dbBytes! / (500 * 1024 * 1024)),
        const SizedBox(height: 16),
        const Text("Alerts",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        ..._alerts(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: PrimaryBtn(
                label: "Scan",
                onTap: () => _open(const SyncScreen()),
              ),
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
    );
  }

  Widget _billingCard(OwnerUsage? u) {
    if (u == null) {
      return const Text("Load ho raha…", style: TextStyle(color: AdminTheme.mute));
    }
    if (u.error != null) {
      return Text(u.error!, style: const TextStyle(color: AdminTheme.warn, fontSize: 13));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${u.currency} ${u.costUsd.toStringAsFixed(2)}  this period",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AdminTheme.silver),
        ),
        const SizedBox(height: 12),
        _quota("Storage", Format.bytes(u.r2Bytes), "10 GB", u.storagePct),
        _quota("Class A (write/list)", "${u.classA}", "1,000,000", u.classAPct),
        _quota("Class B (play/read)", "${u.classB}", "10,000,000", u.classBPct),
        if (u.lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final l in u.lines.take(8))
            _line(l.name, "${l.quantity.toStringAsFixed(0)} ${l.unit}  ·  ${u.currency} ${l.cost.toStringAsFixed(2)}"),
        ],
      ],
    );
  }

  Widget _quota(String label, String used, String cap, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label  ·  $used / $cap",
              style: const TextStyle(color: AdminTheme.silver, fontSize: 13)),
          const SizedBox(height: 4),
          _bar(pct),
        ],
      ),
    );
  }

  Widget _bar(double pct) {
    final v = pct.isNaN || pct.isInfinite ? 0.0 : pct.clamp(0.0, 1.0);
    final color = v > 0.85 ? AdminTheme.danger : (v > 0.6 ? AdminTheme.warn : AdminTheme.ok);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 8,
        color: color,
        backgroundColor: AdminTheme.line,
      ),
    );
  }

  List<Widget> _alerts() {
    final out = <Widget>[];
    if (pending > 0) out.add(_alert(AdminTheme.warn, "$pending KYC pending"));
    if (missing > 0) out.add(_alert(AdminTheme.warn, "$missing MP3 player catalog me nahi"));
    if (dupes > 0) out.add(_alert(AdminTheme.warn, "$dupes duplicate titles"));
    if (!Secrets.cfReady) out.add(_alert(AdminTheme.warn, "Billing token nahi — cost nahi dikhega"));
    if (dbBytes != null && dbBytes! > 400 * 1024 * 1024) {
      out.add(_alert(AdminTheme.danger, "DB 500 MB free cap ke paas"));
    }
    if (out.isEmpty) out.add(_alert(AdminTheme.ok, "Koi alert nahi"));
    return out;
  }

  Widget _alert(Color c, String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text("• $t", style: TextStyle(color: c, fontSize: 13)),
    );
  }

  Widget _dot(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: ok ? AdminTheme.ok : AdminTheme.warn),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.silver)),
        ],
      ),
    );
  }

  Widget _w(Widget child) => SizedBox(width: 160, child: child);

  Widget _line(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
