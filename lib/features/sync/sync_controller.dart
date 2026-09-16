import "package:flutter/foundation.dart";

import "../../config/r2_config.dart";
import "../../core/format.dart";
import "../../models/catalog_diff.dart";
import "../../models/catalog_song.dart";
import "../../models/db_scan.dart";
import "../../models/r2_object.dart";
import "../../models/scan_report.dart";
import "../../services/catalog_sync.dart";
import "../../services/db_scan.dart";
import "../../services/r2_service.dart";
import "../../services/sql_preview.dart";
import "../../services/supabase_admin.dart";

enum SyncStep { buckets, scan, links, diff, sql, done }

class SyncController extends ChangeNotifier {
  final r2 = R2Service();
  final db = SupabaseAdmin.instance;

  SyncStep step = SyncStep.buckets;
  bool busy = false;
  String? error;

  List<String> buckets = [];
  final Set<String> selected = {};

  List<R2Object> objects = [];
  ScanReport? report;
  DbScanReport? dbReport;
  List<CatalogSong> scanned = [];
  CatalogDiff? diff;
  String sql = "";
  String log = "";

  Future<void> loadBuckets() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      buckets = await r2.listBuckets();
      if (selected.isEmpty) selected.addAll(buckets);
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  void toggleBucket(String name) {
    if (selected.contains(name)) {
      selected.remove(name);
    } else {
      selected.add(name);
    }
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(buckets);
    notifyListeners();
  }

  void selectNone() {
    selected.clear();
    notifyListeners();
  }

  Future<void> createBucket(String name) async {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) {
      error = "Bucket naam likho.";
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await r2.createBucket(n);
      buckets = await r2.listBuckets();
      selected.add(n);
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> deleteBucket(String name) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await r2.deleteBucket(name);
      buckets.remove(name);
      selected.remove(name);
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> scan() async {
    final chosen = buckets.where(selected.contains).toList();
    if (chosen.isEmpty) {
      error = "Kam se kam ek bucket tick karo.";
      notifyListeners();
      return;
    }
    step = SyncStep.scan;
    busy = true;
    error = null;
    objects = [];
    report = null;
    dbReport = null;
    log = "Scan shuru — ${chosen.length} bucket\n";
    notifyListeners();
    try {
      for (final b in chosen) {
        log += "\n$b list ho raha hai…";
        notifyListeners();
        final chunk = await r2.listAll(bucket: b);
        objects.addAll(chunk);
        final mp3 = chunk.where((o) => o.isMp3).length;
        log += "\n$b: ${chunk.length} objects, $mp3 MP3";
        notifyListeners();
      }
      report = ScanReport.from(objects);
      log += "\n\nSupabase scan…";
      notifyListeners();
      dbReport = await DbScan().scan();
      if (dbReport!.error != null) {
        log += "\nSupabase: ${dbReport!.error}";
      } else {
        log +=
            "\nSupabase (${dbReport!.source}): ${dbReport!.tableCount} tables, ${dbReport!.songs} songs, ${dbReport!.singers} singers";
        for (final t in dbReport!.tables) {
          log += "\n  ${t.name}: ${t.rows}";
        }
        for (final e in dbReport!.songCategories.entries) {
          log += "\n  category ${e.key}: ${e.value}";
        }
      }
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> deleteFolder(String bucket, String folder) async {
    final victims = objects
        .where((o) => o.bucket == bucket && Format.folderOf(o.key) == folder)
        .toList();
    busy = true;
    error = null;
    notifyListeners();
    try {
      for (final o in victims) {
        await r2.deleteObject(key: o.key, bucket: o.bucket);
      }
      objects.removeWhere(
        (o) => o.bucket == bucket && Format.folderOf(o.key) == folder,
      );
      report = ScanReport.from(objects);
      scanned.removeWhere(
        (s) => s.bucket == bucket && Format.folderOf(s.r2Key) == folder,
      );
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> deleteSong(CatalogSong s) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await r2.deleteObject(key: s.r2Key, bucket: s.bucket);
      objects.removeWhere((o) => o.bucket == s.bucket && o.key == s.r2Key);
      scanned.removeWhere((x) => x.bucket == s.bucket && x.r2Key == s.r2Key);
      report = ScanReport.from(objects);
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  void approveScan() {
    scanned = CatalogSync.songsFromR2(objects);
    step = SyncStep.links;
    notifyListeners();
  }

  void approveLinks() {
    step = SyncStep.diff;
    notifyListeners();
    loadDiff();
  }

  Future<void> loadDiff() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final rows = await db.songs();
      diff = CatalogSync.diff(scanned: scanned, dbRows: rows);
      final insertable =
          diff!.missingInDb.where((s) => s.hasPublicUrl).toList();
      sql = SqlPreview.insertSongs(
        singerName: R2Config.defaultSingerName,
        songs: insertable,
      );
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  void approveDiff() {
    step = SyncStep.sql;
    notifyListeners();
  }

  List<CatalogSong> get insertableMissing =>
      (diff?.missingInDb ?? const <CatalogSong>[])
          .where((s) => s.hasPublicUrl)
          .toList();

  Future<void> apply() async {
    final missing = insertableMissing;
    if (missing.isEmpty) {
      step = SyncStep.done;
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final singerId = await db.ensureSinger(R2Config.defaultSingerName);
      await db.insertSongs(singerId, missing);
      step = SyncStep.done;
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  void back() {
    error = null;
    switch (step) {
      case SyncStep.scan:
        step = SyncStep.buckets;
        break;
      case SyncStep.links:
        step = SyncStep.scan;
        break;
      case SyncStep.diff:
        step = SyncStep.links;
        break;
      case SyncStep.sql:
        step = SyncStep.diff;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void reset() {
    step = SyncStep.buckets;
    objects = [];
    scanned = [];
    diff = null;
    report = null;
    dbReport = null;
    sql = "";
    log = "";
    error = null;
    notifyListeners();
  }
}
