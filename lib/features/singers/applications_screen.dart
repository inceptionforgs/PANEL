import "package:flutter/material.dart";

import "../../config/theme.dart";
import "../../core/admin_scaffold.dart";
import "../../models/singer_application.dart";
import "../../secrets.dart";
import "../../services/supabase_admin.dart";
import "application_detail_screen.dart";

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  bool busy = true;
  String? error;
  List<SingerApplication> rows = [];

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
      rows = await SupabaseAdmin.instance.applications();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: "Singer requests",
      embedded: widget.embedded,
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      body: !Secrets.supabaseReady
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Supabase service key secrets.dart me daalo.",
                  style: TextStyle(color: AdminTheme.warn)),
            )
          : busy
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error!, style: const TextStyle(color: AdminTheme.danger)))
                  : rows.isEmpty
                      ? const Center(child: Text("Koi request nahi"))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final a = rows[i];
                            return ListTile(
                              title: Text(a.name),
                              subtitle: Text("${a.mobileNumber}  •  ${a.status}"),
                              trailing: Text(a.status,
                                  style: TextStyle(
                                    color: a.status == "pending"
                                        ? AdminTheme.warn
                                        : a.status == "approved"
                                            ? AdminTheme.ok
                                            : AdminTheme.danger,
                                  )),
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ApplicationDetailScreen(app: a),
                                ));
                                load();
                              },
                            );
                          },
                        ),
    );
  }
}
