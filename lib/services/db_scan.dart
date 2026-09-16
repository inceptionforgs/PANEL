import "../models/db_scan.dart";
import "../secrets.dart";
import "sql_runner.dart";
import "supabase_admin.dart";

class DbScan {
  static const restTables = [
    "songs",
    "singers",
    "likes",
    "favorites",
    "singer_applications",
    "listen_sessions",
    "profiles",
    "gana_requests",
  ];

  static const tablesSql = """
select c.relname as table_name,
       (xpath('/row/cnt/text()',
          query_to_xml(format('select count(*) as cnt from public.%I', c.relname), false, true, '')
       ))[1]::text::int as n
from pg_class c
join pg_namespace ns on ns.oid = c.relnamespace
where ns.nspname = 'public' and c.relkind = 'r'
order by n desc, c.relname;
""";

  static const categorySql = """
select coalesce(nullif(trim(category), ''), '(none)') as category, count(*)::int as n
from songs
group by 1
order by n desc;
""";

  Future<DbScanReport> scan() async {
    if (Secrets.dbReady) {
      try {
        return await _viaSql();
      } catch (_) {
        /* REST fallback */
      }
    }
    if (!Secrets.supabaseReady) {
      return const DbScanReport(error: "Supabase service key / DB password PASTE karo.");
    }
    return _viaRest();
  }

  Future<DbScanReport> _viaSql() async {
    final runner = SqlRunner();
    final tablesRs = await runner.run(tablesSql);
    final tables = <TableStat>[
      for (final row in tablesRs.rows)
        if (row.length >= 2)
          TableStat(name: row[0], rows: int.tryParse(row[1]) ?? 0),
    ];
    var cats = <String, int>{};
    try {
      final catRs = await runner.run(categorySql);
      for (final row in catRs.rows) {
        if (row.length < 2) continue;
        cats[row[0]] = int.tryParse(row[1]) ?? 0;
      }
    } catch (_) {}
    int n(String name) =>
        tables.where((t) => t.name == name).map((t) => t.rows).fold(0, (a, b) => a + b);
    return DbScanReport(
      tables: tables,
      songCategories: cats,
      songs: n("songs"),
      singers: n("singers"),
      source: "sql",
    );
  }

  Future<DbScanReport> _viaRest() async {
    final db = SupabaseAdmin.instance;
    final tables = <TableStat>[];
    for (final name in restTables) {
      try {
        tables.add(TableStat(name: name, rows: await db.count(name)));
      } catch (_) {}
    }
    tables.sort((a, b) => b.rows.compareTo(a.rows));
    final cats = <String, int>{};
    try {
      final rows = await db.songs();
      for (final r in rows) {
        final c = "${r["category"] ?? ""}".trim();
        final k = c.isEmpty ? "(none)" : c;
        cats[k] = (cats[k] ?? 0) + 1;
      }
    } catch (_) {}
    int n(String name) =>
        tables.where((t) => t.name == name).map((t) => t.rows).fold(0, (a, b) => a + b);
    return DbScanReport(
      tables: tables,
      songCategories: cats,
      songs: n("songs"),
      singers: n("singers"),
      source: "rest",
    );
  }
}
