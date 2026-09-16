import "../models/catalog_song.dart";

class SqlPreview {
  static String insertSongs({
    required String singerName,
    required List<CatalogSong> songs,
  }) {
    final buf = StringBuffer();
    buf.writeln("begin;");
    buf.writeln();
    buf.writeln("with new_singer as (");
    buf.writeln("  insert into public.singers (name, bio)");
    buf.writeln("  select '${_esc(singerName)}', 'Mewati folk singer'");
    buf.writeln("  where not exists (select 1 from public.singers where name = '${_esc(singerName)}')");
    buf.writeln("  returning id");
    buf.writeln("), singer as (");
    buf.writeln("  select id from new_singer");
    buf.writeln("  union all");
    buf.writeln("  select id from public.singers where name = '${_esc(singerName)}'");
    buf.writeln("  limit 1");
    buf.writeln(")");
    buf.writeln("insert into public.songs (");
    buf.writeln("  title, singer_id, category, audio_url, cover_image_url,");
    buf.writeln("  play_count, like_count, is_premium");
    buf.writeln(")");
    buf.writeln("select v.title, s.id, v.category, v.audio_url, v.cover_image_url, 0, 0, false");
    buf.writeln("from singer s");
    buf.writeln("cross join (values");
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      final comma = i == songs.length - 1 ? "" : ",";
      buf.writeln(
        "  ('${_esc(song.title)}', '${_esc(song.category)}', '${_esc(song.audioUrl)}', '${_esc(song.coverImageUrl)}')$comma",
      );
    }
    buf.writeln(") as v(title, category, audio_url, cover_image_url);");
    buf.writeln();
    buf.writeln("commit;");
    return buf.toString();
  }

  static String _esc(String s) => s.replaceAll("'", "''");
}
