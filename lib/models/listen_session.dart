class ListenSession {
  final String sessionId;
  final String? songId;
  final String songTitle;
  final String category;
  final String ip;
  final String country;
  final String region;
  final String city;
  final double? lat;
  final double? lon;
  final DateTime lastSeen;
  final DateTime startedAt;

  const ListenSession({
    required this.sessionId,
    this.songId,
    required this.songTitle,
    required this.category,
    required this.ip,
    required this.country,
    required this.region,
    required this.city,
    this.lat,
    this.lon,
    required this.lastSeen,
    required this.startedAt,
  });

  bool get live => DateTime.now().toUtc().difference(lastSeen.toUtc()).inSeconds <= 120;

  String get place {
    final bits = [city, region, country].where((s) => s.trim().isNotEmpty).toList();
    return bits.isEmpty ? "Unknown" : bits.join(", ");
  }

  factory ListenSession.fromJson(Map<String, dynamic> r) {
    DateTime ts(String k) {
      final v = r[k];
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    double? asDouble(String k) {
      final v = r[k];
      if (v is num) return v.toDouble();
      return double.tryParse("$v");
    }

    return ListenSession(
      sessionId: "${r["session_id"] ?? ""}",
      songId: r["song_id"] as String?,
      songTitle: "${r["song_title"] ?? ""}",
      category: "${r["category"] ?? ""}",
      ip: "${r["ip"] ?? ""}",
      country: "${r["country"] ?? ""}",
      region: "${r["region"] ?? ""}",
      city: "${r["city"] ?? ""}",
      lat: asDouble("lat"),
      lon: asDouble("lon"),
      lastSeen: ts("last_seen"),
      startedAt: ts("started_at"),
    );
  }
}

class RegionCount {
  final String label;
  final int total;
  final int live;
  const RegionCount({required this.label, required this.total, required this.live});
}
