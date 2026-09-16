import "package:flutter/material.dart";

import "../../config/r2_config.dart";
import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/singer_application.dart";
import "../../services/supabase_admin.dart";

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({super.key, required this.app});
  final SingerApplication app;
  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  String? idUrl;
  String? liveUrl;
  bool busy = true;
  String? error;
  final reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> _loadDocs() async {
    try {
      final db = SupabaseAdmin.instance;
      if (widget.app.idDocumentPath.isNotEmpty) {
        idUrl = await db.signedKycUrl(widget.app.idDocumentPath);
      }
      if (widget.app.livenessImagePath.isNotEmpty) {
        liveUrl = await db.signedKycUrl(widget.app.livenessImagePath);
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _set(String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$status?"),
        content: Text("${widget.app.name} ko $status karna hai?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.setApplicationStatus(
        id: widget.app.id,
        status: status,
        reason: status == "rejected" ? reason.text.trim() : null,
      );
      if (status == "approved") {
        await SupabaseAdmin.instance.ensureSinger(
          widget.app.name.isEmpty ? R2Config.defaultSingerName : widget.app.name,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = e.toString();
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    return AdminScaffold(
      title: a.name,
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null)
                  Text(error!, style: const TextStyle(color: AdminTheme.danger)),
                Text("Mobile: ${a.mobileNumber}"),
                Text("Status: ${a.status}"),
                Text("Terms: ${a.termsVersion}"),
                const SizedBox(height: 12),
                const Text("ID document", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (idUrl != null)
                  Image.network(idUrl!, height: 220, fit: BoxFit.contain),
                const SizedBox(height: 16),
                const Text("Liveness selfie", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (liveUrl != null)
                  Image.network(liveUrl!, height: 220, fit: BoxFit.contain),
                const SizedBox(height: 16),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: "Reject reason (optional)"),
                ),
                const SizedBox(height: 16),
                PrimaryBtn(label: "Approve", onTap: () => _set("approved"), color: AdminTheme.ok),
                const SizedBox(height: 8),
                PrimaryBtn(label: "Reject", onTap: () => _set("rejected"), color: AdminTheme.danger),
              ],
            ),
    );
  }
}
