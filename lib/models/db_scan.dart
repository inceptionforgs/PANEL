class TableStat {
  final String name;
  final int rows;
  const TableStat({required this.name, required this.rows});
}

class DbScanReport {
  final List<TableStat> tables;
  final Map<String, int> songCategories;
  final int songs;
  final int singers;
  final String source;
  final String? error;

  const DbScanReport({
    this.tables = const [],
    this.songCategories = const {},
    this.songs = 0,
    this.singers = 0,
    this.source = "rest",
    this.error,
  });

  int get tableCount => tables.length;
}
