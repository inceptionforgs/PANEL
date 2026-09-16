import "package:postgres/postgres.dart";

import "../models/sql_result.dart";
import "../secrets.dart";

class SqlRunner {
  Future<SqlResult> run(String sql) async {
    final conn = await Connection.open(
      Endpoint(
        host: Secrets.dbHost,
        port: Secrets.dbPort,
        database: Secrets.dbName,
        username: Secrets.dbUser,
        password: Secrets.dbPassword,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.verifyFull),
    );
    try {
      final rs = await conn.execute(sql);
      if (rs.isEmpty && rs.schema.columns.isEmpty) {
        return SqlResult(message: "OK. Rows: ${rs.affectedRows}", affected: rs.affectedRows);
      }
      final cols = [for (final c in rs.schema.columns) c.columnName ?? ""];
      final rows = [
        for (final row in rs)
          [for (final v in row) "${v ?? ""}"],
      ];
      return SqlResult(columns: cols, rows: rows, affected: rs.affectedRows);
    } finally {
      await conn.close();
    }
  }

  static bool looksDangerous(String sql) {
    final s = sql.toLowerCase();
    return s.contains("drop ") ||
        s.contains("truncate ") ||
        s.contains("alter ") ||
        s.contains("delete from") ||
        s.contains("update ");
  }
}
