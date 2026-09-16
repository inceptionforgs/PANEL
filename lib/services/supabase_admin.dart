import "dart:convert";

import "package:http/http.dart" as http;
import "package:supabase/supabase.dart";

import "../models/catalog_song.dart";
import "../models/listen_session.dart";
import "../models/sb_file.dart";
import "../models/singer_application.dart";
import "../secrets.dart";

class SupabaseAdmin {
  SupabaseAdmin._();
  static final SupabaseAdmin instance = SupabaseAdmin._();

  static final tableName = RegExp(r"^[a-zA-Z_][a-zA-Z0-9_]*$");

  SupabaseClient? _client;
  SupabaseClient get client {
    _client ??= SupabaseClient(Secrets.supabaseUrl, Secrets.supabaseServiceKey);
    return _client!;
  }

  Future<List<Map<String, dynamic>>> songs({int limit = 5000}) async {
    final rows = await client.from("songs").select("id,title,audio_url,cover_image_url,category").limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<int> count(String table) async {
    _assertTable(table);
    final rows = await client.from(table).select().limit(20000);
    return (rows as List).length;
  }

  Future<List<Map<String, dynamic>>> tableRows(String table, {int limit = 200}) async {
    _assertTable(table);
    final rows = await client.from(table).select().limit(limit);
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  Future<void> deleteById(String table, String id) async {
    _assertTable(table);
    await client.from(table).delete().eq("id", id);
  }

  Future<void> insertRow(String table, Map<String, dynamic> row) async {
    _assertTable(table);
    await client.from(table).insert(row);
  }

  Future<String> ensureSinger(String name) async {
    final found = await client.from("singers").select("id").eq("name", name).limit(1);
    final list = List<Map<String, dynamic>>.from(found as List);
    if (list.isNotEmpty) return list.first["id"] as String;
    final inserted = await client.from("singers").insert({"name": name, "bio": "Mewati folk singer"}).select("id").single();
    return inserted["id"] as String;
  }

  Future<void> insertSongs(String singerId, List<CatalogSong> songs) async {
    const chunk = 80;
    for (var i = 0; i < songs.length; i += chunk) {
      final slice = songs.sublist(i, i + chunk > songs.length ? songs.length : i + chunk);
      await client.from("songs").insert([
        for (final s in slice)
          {
            "title": s.title,
            "singer_id": singerId,
            "category": s.category,
            "audio_url": s.audioUrl,
            "cover_image_url": s.coverImageUrl,
            "play_count": 0,
            "like_count": 0,
            "is_premium": false,
          }
      ]);
    }
  }

  Future<List<SingerApplication>> applications() async {
    final rows = await client
        .from("singer_applications")
        .select("id,name,mobile_number,id_document_path,liveness_image_path,status,rejection_reason,created_at,reviewed_at,terms_version")
        .order("created_at", ascending: false)
        .limit(200);
    return [
      for (final r in List<Map<String, dynamic>>.from(rows as List))
        SingerApplication.fromJson(r),
    ];
  }

  Future<String> signedKycUrl(String path) async {
    final signed = await client.storage.from("singer-kyc-docs").createSignedUrl(path, 60 * 30);
    return signed;
  }

  Future<void> setApplicationStatus({
    required String id,
    required String status,
    String? reason,
  }) async {
    await client.from("singer_applications").update({
      "status": status,
      "rejection_reason": reason,
      "reviewed_at": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", id);
  }

  Future<Map<String, int>> monitorCounts() async {
    final songsN = await count("songs");
    final singersN = await count("singers");
    final likesN = await count("likes");
    final favN = await count("favorites");
    final apps = await applications();
    final pending = apps.where((a) => a.status == "pending").length;
    return {
      "songs": songsN,
      "singers": singersN,
      "likes": likesN,
      "favorites": favN,
      "applications": apps.length,
      "pending": pending,
    };
  }

  Future<List<ListenSession>> listenSessions({int limit = 2000}) async {
    final rows = await client
        .from("listen_sessions")
        .select(
          "session_id,song_id,song_title,category,ip,country,region,city,lat,lon,last_seen,started_at",
        )
        .order("last_seen", ascending: false)
        .limit(limit);
    return [
      for (final r in List<Map<String, dynamic>>.from(rows as List))
        ListenSession.fromJson(r),
    ];
  }

  Future<List<SbBucket>> storageBuckets() async {
    final res = await http.get(Uri.parse("${Secrets.supabaseUrl}/storage/v1/bucket"), headers: _headers);
    _ok(res, "storage buckets");
    final list = jsonDecode(res.body);
    if (list is! List) return [];
    return [for (final b in list) if (b is Map) SbBucket.fromJson(Map<String, dynamic>.from(b))];
  }

  Future<void> createStorageBucket(String name, {bool isPublic = false}) async {
    final n = name.trim();
    if (n.isEmpty) throw Exception("Bucket naam likho.");
    final res = await http.post(
      Uri.parse("${Secrets.supabaseUrl}/storage/v1/bucket"),
      headers: _headers,
      body: jsonEncode({"id": n, "name": n, "public": isPublic}),
    );
    _ok(res, "create bucket");
  }

  Future<void> deleteStorageBucket(String name) async {
    final res = await http.delete(
      Uri.parse("${Secrets.supabaseUrl}/storage/v1/bucket/$name"),
      headers: _headers,
    );
    _ok(res, "delete bucket");
  }

  Future<List<SbObject>> storageObjects(String bucket, {String prefix = ""}) async {
    final res = await http.post(
      Uri.parse("${Secrets.supabaseUrl}/storage/v1/object/list/$bucket"),
      headers: _headers,
      body: jsonEncode({"prefix": prefix, "limit": 1000, "offset": 0}),
    );
    _ok(res, "list objects");
    final list = jsonDecode(res.body);
    if (list is! List) return [];
    return [for (final o in list) if (o is Map) SbObject.fromJson(Map<String, dynamic>.from(o))];
  }

  Future<void> deleteStorageObject(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }

  Future<List<SbUser>> authUsers() async {
    final res = await http.get(
      Uri.parse("${Secrets.supabaseUrl}/auth/v1/admin/users?page=1&per_page=200"),
      headers: _headers,
    );
    _ok(res, "auth users");
    final json = jsonDecode(res.body);
    final list = json is Map ? json["users"] : json;
    if (list is! List) return [];
    return [for (final u in list) if (u is Map) SbUser.fromJson(Map<String, dynamic>.from(u))];
  }

  Future<void> deleteAuthUser(String id) async {
    final res = await http.delete(
      Uri.parse("${Secrets.supabaseUrl}/auth/v1/admin/users/$id"),
      headers: _headers,
    );
    _ok(res, "delete user");
  }

  Map<String, String> get _headers => {
        "apikey": Secrets.supabaseServiceKey,
        "Authorization": "Bearer ${Secrets.supabaseServiceKey}",
        "Content-Type": "application/json",
      };

  void _assertTable(String table) {
    if (!tableName.hasMatch(table)) {
      throw Exception("Bad table name");
    }
  }

  void _ok(http.Response res, String what) {
    if (res.statusCode >= 400) {
      final body = res.body.length > 220 ? res.body.substring(0, 220) : res.body;
      throw Exception("$what ${res.statusCode}: $body");
    }
  }
}
