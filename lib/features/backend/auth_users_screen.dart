import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/sb_file.dart";
import "../../secrets.dart";
import "../../services/supabase_admin.dart";

class AuthUsersScreen extends StatefulWidget {
  const AuthUsersScreen({super.key});
  @override
  State<AuthUsersScreen> createState() => _AuthUsersScreenState();
}

class _AuthUsersScreenState extends State<AuthUsersScreen> {
  bool busy = false;
  String? error;
  List<SbUser> users = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!Secrets.supabaseReady) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      users = await SupabaseAdmin.instance.authUsers();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _delete(SbUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Auth user delete?"),
        content: Text("${u.email.isEmpty ? u.phone : u.email}\n${u.id}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nahi")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Haan")),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await SupabaseAdmin.instance.deleteAuthUser(u.id);
      await load();
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Auth users",
      embedded: true,
      actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh))],
      body: !Secrets.supabaseReady
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text("service_role PASTE karo.", style: TextStyle(color: AdminTheme.warn)),
            )
          : busy && users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (error != null)
                      Text(error!, style: const TextStyle(color: AdminTheme.danger, fontSize: 12)),
                    Text("${users.length} users", style: const TextStyle(color: AdminTheme.mute, fontSize: 12)),
                    for (final u in users)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          u.email.isNotEmpty ? u.email : (u.phone.isNotEmpty ? u.phone : u.id),
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          "in ${u.lastSignIn.isEmpty ? u.createdAt : u.lastSignIn}",
                          style: const TextStyle(color: AdminTheme.mute, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AdminTheme.danger),
                          onPressed: busy ? null : () => _delete(u),
                        ),
                      ),
                  ],
                ),
    );
  }
}
