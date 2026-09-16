import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../core/format.dart";
import "../../models/sb_file.dart";
import "../../secrets.dart";
import "../../services/supabase_admin.dart";

class SbFilesScreen extends StatefulWidget {
  const SbFilesScreen({super.key});
  @override
  State<SbFilesScreen> createState() => _SbFilesScreenState();
}

class _SbFilesScreenState extends State<SbFilesScreen> {
  final name = TextEditingController();
  bool busy = false;
  String? error;
  List<SbBucket> buckets = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (!Secrets.supabaseReady) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      buckets = await SupabaseAdmin.instance.storageBuckets();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _create() async {
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.createStorageBucket(name.text);
      name.clear();
      await load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(SbBucket b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Storage bucket delete?"),
        content: Text(b.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.deleteStorageBucket(b.name);
      await load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Storage files",
      embedded: true,
      actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh))],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!Secrets.supabaseReady)
              const Text("service_role PASTE karo.", style: TextStyle(color: AdminTheme.warn)),
            if (error != null) Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
            TextField(
              controller: name,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: "Nayi storage bucket",
                suffixIcon: IconButton(onPressed: busy ? null : _create, icon: const Icon(Icons.add_box)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: busy && buckets.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final b in buckets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.name),
                            subtitle: Text(b.isPublic ? "public" : "private",
                                style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                              onPressed: busy ? null : () => _delete(b),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SbObjectsScreen(bucket: b.name)),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SbObjectsScreen extends StatefulWidget {
  const SbObjectsScreen({super.key, required this.bucket});
  final String bucket;
  @override
  State<SbObjectsScreen> createState() => _SbObjectsScreenState();
}

class _SbObjectsScreenState extends State<SbObjectsScreen> {
  bool busy = false;
  String? error;
  List<SbObject> objects = [];

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
      objects = await SupabaseAdmin.instance.storageObjects(widget.bucket);
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _delete(SbObject o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("File delete?"),
        content: Text("${widget.bucket}/${o.name}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.deleteStorageObject(widget.bucket, o.name);
      await load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: widget.bucket,
      actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh))],
      body: busy && objects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
                Text("${objects.length} objects", style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
                for (final o in objects)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(Format.bytes(o.bytes),
                        style: const TextStyle(color: AdminTheme.mute, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                      onPressed: busy ? null : () => _delete(o),
                    ),
                  ),
              ],
            ),
    );
  }
}
