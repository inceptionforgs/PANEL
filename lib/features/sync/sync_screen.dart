import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../core/approval_gate.dart";
import "../../core/format.dart";
import "../../models/catalog_song.dart";
import "../../models/scan_report.dart";
import "../../secrets.dart";
import "sync_controller.dart";

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final c = SyncController();
  final newBucket = TextEditingController();

  @override
  void initState() {
    super.initState();
    c.addListener(() => setState(() {}));
    c.loadBuckets();
  }

  @override
  void dispose() {
    newBucket.dispose();
    c.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Sync",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !Secrets.r2Ready || !Secrets.supabaseReady
            ? const Text(
                "Pehle secrets.dart me R2 + Supabase service key bharo.",
                style: TextStyle(color: AdminTheme.warn),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(c.error!, style: const TextStyle(color: AdminTheme.danger)),
                    ),
                  Expanded(child: _body()),
                ],
              ),
      ),
    );
  }

  Widget _body() {
    switch (c.step) {
      case SyncStep.buckets:
        return ApprovalGate(
          stepLabel: "Step 1 / 5  —  Buckets",
          details: c.busy && c.buckets.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "${c.buckets.length} buckets mile  ·  ${c.selected.length} selected",
                      style: const TextStyle(color: AdminTheme.silver),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tick = scan. Nayi bucket yahin bana. Delete icon se bucket hata.",
                      style: TextStyle(color: AdminTheme.mute, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newBucket,
                      enabled: !c.busy,
                      decoration: InputDecoration(
                        labelText: "Nayi bucket ka naam",
                        hintText: "premium-songs",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_box),
                          onPressed: c.busy
                              ? null
                              : () async {
                                  await c.createBucket(newBucket.text);
                                  if (c.error == null) newBucket.clear();
                                },
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(onPressed: c.selectAll, child: const Text("Saari")),
                        TextButton(onPressed: c.selectNone, child: const Text("Koi nahi")),
                        const Spacer(),
                        TextButton(
                          onPressed: c.busy ? null : c.loadBuckets,
                          child: const Text("List refresh"),
                        ),
                      ],
                    ),
                    Expanded(
                      child: c.buckets.isEmpty
                          ? const Text(
                              "Koi bucket nahi mili. Admin token se list aayegi.",
                              style: TextStyle(color: AdminTheme.warn),
                            )
                          : ListView.builder(
                              itemCount: c.buckets.length,
                              itemBuilder: (_, i) {
                                final name = c.buckets[i];
                                final on = c.selected.contains(name);
                                return CheckboxListTile(
                                  dense: true,
                                  value: on,
                                  onChanged: (_) => c.toggleBucket(name),
                                  title: Text(name, style: const TextStyle(fontSize: 14)),
                                  subtitle: name == Secrets.r2Bucket
                                      ? const Text(
                                          "Default catalog bucket",
                                          style: TextStyle(
                                            color: AdminTheme.mute,
                                            fontSize: 11,
                                          ),
                                        )
                                      : null,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  secondary: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                                    onPressed: c.busy
                                        ? null
                                        : () async {
                                            final ok = await _confirm(
                                              "Bucket delete?",
                                              "$name\nPehle bucket khali honi chahiye.",
                                            );
                                            if (ok) await c.deleteBucket(name);
                                          },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
          onApprove: c.scan,
          canApprove: c.selected.isNotEmpty && !c.busy,
          approveLabel: "In buckets scan karo",
        );
      case SyncStep.scan:
        final r = c.report;
        return ApprovalGate(
          stepLabel: "Step 2 / 5  —  Scan result",
          onBack: c.back,
          busy: c.busy,
          details: c.busy && r == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          c.log,
                          style: const TextStyle(color: AdminTheme.silver, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                )
              : _scanResult(r, c.log),
          onApprove: c.approveScan,
          canApprove: r != null && !c.busy,
          approveLabel: "Yeh list theek hai",
        );
      case SyncStep.links:
        return ApprovalGate(
          stepLabel: "Step 3 / 5  —  Names + links  (${c.scanned.length})",
          onBack: c.back,
          busy: c.busy,
          details: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "${c.scanned.length} MP3 se naam + link bane  ·  ${c.scanned.where((s) => s.hasPublicUrl).length} ke paas public URL",
                style: const TextStyle(color: AdminTheme.silver, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: c.scanned.length,
                  itemBuilder: (_, i) {
                    final s = c.scanned[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.title, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        "${s.bucket}  ·  ${s.r2Key}",
                        style: const TextStyle(color: AdminTheme.mute, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AdminTheme.danger, size: 20),
                        onPressed: c.busy
                            ? null
                            : () async {
                                final ok = await _confirm(
                                  "R2 se hatao?",
                                  "${s.title}\n${s.bucket}/${s.r2Key}",
                                );
                                if (ok) await c.deleteSong(s);
                              },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          onApprove: c.approveLinks,
        );
      case SyncStep.diff:
        final d = c.diff;
        final skip = (d?.missingInDb ?? const <CatalogSong>[])
            .where((s) => !s.hasPublicUrl)
            .length;
        return ApprovalGate(
          stepLabel: "Step 4 / 5  —  Supabase diff",
          onBack: c.back,
          busy: c.busy,
          details: c.busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Text("R2 MP3: ${d?.scanned.length ?? 0}",
                        style: const TextStyle(color: AdminTheme.silver)),
                    Text("Pehle se DB me: ${d?.alreadyInDb.length ?? 0}",
                        style: const TextStyle(color: AdminTheme.ok)),
                    Text("Naye (insert): ${c.insertableMissing.length}",
                        style: const TextStyle(color: AdminTheme.warn)),
                    if (skip > 0)
                      Text(
                        "$skip skip — unki bucket ki public URL secrets me nahi",
                        style: const TextStyle(color: AdminTheme.warn, fontSize: 12),
                      ),
                    const SizedBox(height: 12),
                    for (final s in c.insertableMissing)
                      Text("• ${s.title}  (${s.bucket})",
                          style: const TextStyle(fontSize: 13, color: AdminTheme.silver)),
                  ],
                ),
          onApprove: c.approveDiff,
          approveLabel: "SQL preview dikhao",
        );
      case SyncStep.sql:
        return ApprovalGate(
          stepLabel: "Step 5 / 5  —  SQL + insert  (${c.insertableMissing.length})",
          onBack: c.back,
          busy: c.busy,
          details: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.sql));
                  },
                  child: const Text("SQL copy"),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.line),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      c.sql,
                      style: const TextStyle(fontFamily: "monospace", fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
          onApprove: c.apply,
          approveLabel: "Haan, Supabase me daal do",
        );
      case SyncStep.done:
        final r = c.report;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Ho gaya.",
              style: TextStyle(
                color: AdminTheme.ok,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Buckets: ${r?.buckets.length ?? 0}\n"
              "Objects scan: ${r?.objects ?? 0}\n"
              "Folders: ${r?.folderCount ?? 0}\n"
              "MP3: ${r?.mp3 ?? 0}\n"
              "Naye songs insert: ${c.insertableMissing.length}",
              style: const TextStyle(color: AdminTheme.silver, height: 1.5),
            ),
            const Spacer(),
            PrimaryBtn(label: "Phir se sync", onTap: c.reset),
          ],
        );
    }
  }

  Widget _scanResult(ScanReport? r, String log) {
    if (r == null) {
      return SingleChildScrollView(
        child: Text(log, style: const TextStyle(color: AdminTheme.silver, height: 1.4)),
      );
    }
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip("Objects", "${r.objects}"),
            _chip("MP3", "${r.mp3}"),
            _chip("Baaki files", "${r.other}"),
            _chip("Folders", "${r.folderCount}"),
            _chip("Size", Format.bytes(r.bytes)),
            _chip("Buckets", "${r.buckets.length}"),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Buckets", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final b in r.buckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              "${b.bucket}\n  ${b.objects} objects · ${b.mp3} gaane · ${b.folders} folders · ${Format.bytes(b.bytes)}",
              style: const TextStyle(color: AdminTheme.silver, height: 1.35, fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        const Text("Folders", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final f in r.folders)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              "${f.bucket}  /  ${f.folder}",
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              "${f.mp3} gaane · ${f.objects} objects · ${Format.bytes(f.bytes)}",
              style: const TextStyle(color: AdminTheme.mute, fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
              onPressed: c.busy
                  ? null
                  : () async {
                      final ok = await _confirm(
                        "Folder delete?",
                        "${f.bucket}/${f.folder}\n${f.objects} objects R2 se hat jayenge.",
                      );
                      if (ok) await c.deleteFolder(f.bucket, f.folder);
                    },
            ),
          ),
        const SizedBox(height: 12),
        const Text("Supabase", style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (c.dbReport == null)
          const Text("Supabase scan pending…",
              style: TextStyle(color: AdminTheme.mute, fontSize: 12))
        else if (c.dbReport!.error != null)
          Text(c.dbReport!.error!,
              style: const TextStyle(color: AdminTheme.warn, fontSize: 12))
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("Tables", "${c.dbReport!.tableCount}"),
              _chip("Songs", "${c.dbReport!.songs}"),
              _chip("Singers", "${c.dbReport!.singers}"),
              _chip("Via", c.dbReport!.source),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in c.dbReport!.tables)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "${t.name}: ${t.rows} rows",
                style: const TextStyle(color: AdminTheme.silver, fontSize: 13),
              ),
            ),
          if (c.dbReport!.songCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Songs by category",
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final e in c.dbReport!.songCategories.entries)
              Text("${e.key}: ${e.value}",
                  style: const TextStyle(color: AdminTheme.silver, fontSize: 13)),
          ],
        ],
        if (log.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("Log", style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(log, style: const TextStyle(color: AdminTheme.mute, fontSize: 12, height: 1.4)),
        ],
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AdminTheme.mute, fontSize: 10)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
