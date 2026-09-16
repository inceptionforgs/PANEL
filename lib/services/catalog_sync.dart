import "../config/r2_config.dart";
import "../core/format.dart";
import "../models/catalog_diff.dart";
import "../models/catalog_song.dart";
import "../models/r2_object.dart";
import "../secrets.dart";

class CatalogSync {
  static List<CatalogSong> songsFromR2(List<R2Object> objects) {
    final mp3 = objects.where((o) => o.isMp3).toList()
      ..sort((a, b) {
        final c = a.bucket.compareTo(b.bucket);
        if (c != 0) return c;
        return a.key.compareTo(b.key);
      });
    return [
      for (var i = 0; i < mp3.length; i++)
        CatalogSong(
          title: Format.titleFromKey(mp3[i].key),
          audioUrl: _audioUrl(mp3[i]),
          coverImageUrl: R2Config.zipperCover(i + 1),
          category: Format.categoryFromKey(mp3[i].key),
          r2Key: mp3[i].key,
          bucket: mp3[i].bucket.isEmpty ? Secrets.r2Bucket : mp3[i].bucket,
        ),
    ];
  }

  static String _audioUrl(R2Object o) {
    final bucket = o.bucket.isEmpty ? Secrets.r2Bucket : o.bucket;
    final base = Secrets.publicBaseFor(bucket);
    if (base == null || base.isEmpty) return "";
    return Format.publicUrl(base, o.key);
  }

  static CatalogDiff diff({
    required List<CatalogSong> scanned,
    required List<Map<String, dynamic>> dbRows,
  }) {
    final dbUrls = <String>{};
    final dbTitles = <String>{};
    for (final r in dbRows) {
      final u = (r["audio_url"] as String? ?? "").trim().toLowerCase();
      final t = (r["title"] as String? ?? "").trim().toLowerCase();
      if (u.isNotEmpty) dbUrls.add(u);
      if (t.isNotEmpty) dbTitles.add(t);
    }
    final already = <CatalogSong>[];
    final missing = <CatalogSong>[];
    for (final s in scanned) {
      final hit = dbUrls.contains(s.audioUrl.toLowerCase()) ||
          dbTitles.contains(s.title.toLowerCase());
      (hit ? already : missing).add(s);
    }
    return CatalogDiff(alreadyInDb: already, missingInDb: missing, scanned: scanned);
  }

  static List<String> duplicateTitles(List<CatalogSong> songs) {
    final map = <String, List<CatalogSong>>{};
    for (final s in songs) {
      map.putIfAbsent(s.title.toLowerCase(), () => []).add(s);
    }
    final out = <String>[];
    for (final e in map.entries) {
      if (e.value.length < 2) continue;
      out.add("${e.value.first.title}  ×${e.value.length}");
    }
    out.sort();
    return out;
  }

  static Map<String, int> byCategory(List<CatalogSong> songs) {
    final map = <String, int>{};
    for (final s in songs) {
      final k = s.category.isEmpty ? "-" : s.category;
      map[k] = (map[k] ?? 0) + 1;
    }
    return map;
  }
}
