class SqlResult {
  final List<String> columns;
  final List<List<String>> rows;
  final String? message;
  final int affected;

  const SqlResult({
    this.columns = const [],
    this.rows = const [],
    this.message,
    this.affected = 0,
  });
}
