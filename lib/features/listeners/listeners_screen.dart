import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../config/listen_sql.dart";
import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/listen_session.dart";
import "../../secrets.dart";
import "../../services/supabase_admin.dart";

class ListenersScreen extends StatefulWidget {
  const ListenersScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<ListenersScreen> createState() => _ListenersScreenState();
}

class _ListenersScreenState extends State<ListenersScreen> {
  bool busy = false;
  String? error;
  bool tableMissing = false;
  List<ListenSession> rows = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!Secrets.supabaseReady) return;
    setState(() {
      busy = true;
      error = null;
      tableMissing = false;
    });
    try {
      rows = await SupabaseAdmin.instance.listenSessions();
    } catch (e) {
      final s = e.toString();
      tableMissing = s.contains("listen_sessions") ||
          s.contains("PGRST205") ||
          s.contains("42P01") ||
          s.contains("does not exist");
      error = s;
    }
    if (mounted) setState(() => busy = false);
  }

  List<ListenSession> get live => rows.where((r) => r.live).toList();

  List<RegionCount> _by(String Function(ListenSession s) key) {
    final total = <String, int>{};
    final liveN = <String, int>{};
    for (final r in rows) {
      final k = key(r).trim().isEmpty ? "Unknown" : key(r).trim();
      total[k] = (total[k] ?? 0) + 1;
      if (r.live) liveN[k] = (liveN[k] ?? 0) + 1;
    }
    final out = [
      for (final e in total.entries)
        RegionCount(label: e.key, total: e.value, live: liveN[e.key] ?? 0),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final regions = _by((s) => s.region.isEmpty ? s.country : "${s.region}, ${s.country}");
    final countries = _by((s) => s.country);
    return AdminScaffold(
      title: "Listeners",
      embedded: widget.embedded,
      actions: [
        IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh)),
      ],
      body: !Secrets.supabaseReady
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Supabase service key secrets.dart me PASTE karo.",
                style: TextStyle(color: AdminTheme.warn),
              ),
            )
          : busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (tableMissing) _setupCard(),
                    if (error != null && !tableMissing)
                      Text(error!, style: const TextStyle(color: AdminTheme.danger)),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _w(StatCard(label: "Live now", value: "${live.length}")),
                      _w(StatCard(label: "Sessions", value: "${rows.length}")),
                      _w(StatCard(label: "Regions", value: "${regions.length}")),
                      _w(StatCard(label: "Countries", value: "${countries.length}")),
                    ]),
                    const SizedBox(height: 22),
                    const Text("Language map — region",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      "Jis state/region me zyada live + sessions, wahan us language ka catalog pehle taiyar karo.",
                      style: TextStyle(color: AdminTheme.mute, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    if (regions.isEmpty)
                      const Text("Abhi koi ping nahi. Player pe gaana chalao.",
                          style: TextStyle(color: AdminTheme.mute))
                    else
                      for (final r in regions)
                        _line(r.label, "sessions ${r.total}  ·  live ${r.live}"),
                    const SizedBox(height: 22),
                    const Text("Live abhi",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (live.isEmpty)
                      const Text("Koi abhi nahi sun raha (2 min window).",
                          style: TextStyle(color: AdminTheme.mute))
                    else
                      for (final s in live)
                        _line(
                          s.place,
                          "${s.ip.isEmpty ? "IP nahi" : s.ip}  ·  ${s.songTitle.isEmpty ? "-" : s.songTitle}",
                        ),
                    const SizedBox(height: 22),
                    const Text("Recent (IP + location)",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    for (final s in rows.take(80))
                      _line(
                        s.place,
                        "${s.ip}  ·  ${s.songTitle}  ·  ${_ago(s.lastSeen)}",
                      ),
                  ],
                ),
    );
  }

  Widget _setupCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.warn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "listen_sessions table nahi hai. SQL Lab me yeh SQL run karo, phir refresh.",
            style: TextStyle(color: AdminTheme.warn),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: listenSessionsSql));
              },
              child: const Text("SQL copy"),
            ),
          ),
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

  String _ago(DateTime t) {
    final s = DateTime.now().toUtc().difference(t.toUtc()).inSeconds;
    if (s < 60) return "${s}s pehle";
    if (s < 3600) return "${s ~/ 60}m pehle";
    if (s < 86400) return "${s ~/ 3600}h pehle";
    return "${s ~/ 86400}d pehle";
  }
}
