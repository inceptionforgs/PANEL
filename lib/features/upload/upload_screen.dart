import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../secrets.dart";
import "../../services/r2_service.dart";
import "../../services/upload_service.dart";

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final prefix = TextEditingController(text: "testing/testing_songs/Mewati/");
  final r2 = R2Service();
  List<String> buckets = [];
  String? bucket;
  List<UploadJob> jobs = [];
  bool busy = false;
  String? error;
  int done = 0;

  @override
  void initState() {
    super.initState();
    _loadBuckets();
  }

  @override
  void dispose() {
    prefix.dispose();
    super.dispose();
  }

  Future<void> _loadBuckets() async {
    if (!Secrets.r2Ready) return;
    setState(() => error = null);
    try {
      final list = await r2.listBuckets();
      setState(() {
        buckets = list;
        bucket ??= list.contains(Secrets.r2Bucket) ? Secrets.r2Bucket : (list.isEmpty ? null : list.first);
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> pick() async {
    if (busy) return;
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ["mp3", "m4a", "aac", "wav", "flac"],
      withData: false,
    );
    if (res == null) return;
    setState(() {
      done = 0;
      jobs = [
        for (final f in res.files)
          if (f.path != null)
            UploadJob(
              localPath: f.path!,
              r2Key: UploadService.joinKey(prefix.text, f.name),
            ),
      ];
    });
  }

  Future<void> start() async {
    if (jobs.isEmpty || bucket == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("R2 pe upload?"),
        content: Text(
          "${jobs.length} files → $bucket\n"
          "Prefix: ${prefix.text}\n"
          "Parallel: ${UploadService.parallel}  ·  baaki queue",
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
      done = 0;
      for (final j in jobs) {
        j.status = UploadStatus.queued;
        j.error = null;
      }
    });
    await UploadService(r2).uploadAll(
      jobs,
      bucket: bucket,
      onEach: (d, t, _) {
        if (mounted) setState(() => done = d);
      },
    );
    if (mounted) setState(() => busy = false);
  }

  int get uploading => jobs.where((j) => j.status == UploadStatus.uploading).length;
  int get queued => jobs.where((j) => j.status == UploadStatus.queued).length;
  int get failed => jobs.where((j) => j.status == UploadStatus.error).length;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Bulk upload",
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!Secrets.r2Ready)
              const Text(
                "R2 keys secrets.dart me PASTE karo.",
                style: TextStyle(color: AdminTheme.warn),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
            DropdownButtonFormField<String>(
              value: bucket != null && buckets.contains(bucket) ? bucket : null,
              items: [
                for (final b in buckets)
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: busy ? null : (v) => setState(() => bucket = v),
              decoration: const InputDecoration(labelText: "Bucket"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prefix,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: "R2 folder prefix (subfolder ke saath)",
                hintText: "testing/testing_songs/Mewati/",
              ),
            ),
            const SizedBox(height: 12),
            PrimaryBtn(label: "MP3 files chuno (bulk)", onTap: busy ? null : pick),
            const SizedBox(height: 8),
            Text(
              "${jobs.length} files  ·  $done done  ·  $uploading uploading  ·  $queued queue  ·  $failed fail  ·  ${bucket ?? "-"}",
              style: const TextStyle(color: AdminTheme.mute, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (_, i) {
                  final j = jobs[i];
                  return ListTile(
                    dense: true,
                    title: Text(j.r2Key, style: const TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _label(j),
                      style: TextStyle(color: _color(j), fontSize: 11),
                    ),
                    trailing: _icon(j),
                  );
                },
              ),
            ),
            PrimaryBtn(
              label: busy ? "Queue chal rahi hai (2 parallel)" : "Upload shuru",
              onTap: Secrets.r2Ready && jobs.isNotEmpty && bucket != null && !busy ? start : null,
              busy: busy,
              color: AdminTheme.ok,
            ),
          ],
        ),
      ),
    );
  }

  String _label(UploadJob j) {
    switch (j.status) {
      case UploadStatus.queued:
        return "Queue";
      case UploadStatus.uploading:
        return "Uploading";
      case UploadStatus.done:
        return "Done";
      case UploadStatus.error:
        return j.error ?? "Error";
    }
  }

  Color _color(UploadJob j) {
    switch (j.status) {
      case UploadStatus.queued:
        return AdminTheme.mute;
      case UploadStatus.uploading:
        return AdminTheme.accent;
      case UploadStatus.done:
        return AdminTheme.ok;
      case UploadStatus.error:
        return AdminTheme.danger;
    }
  }

  Widget? _icon(UploadJob j) {
    switch (j.status) {
      case UploadStatus.queued:
        return const Icon(Icons.schedule, color: AdminTheme.mute, size: 18);
      case UploadStatus.uploading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UploadStatus.done:
        return const Icon(Icons.check, color: AdminTheme.ok);
      case UploadStatus.error:
        return const Icon(Icons.error, color: AdminTheme.danger);
    }
  }
}
