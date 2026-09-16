class CatalogSong {
  final String? id;
  final String title;
  final String audioUrl;
  final String coverImageUrl;
  final String category;
  final String r2Key;
  final String bucket;

  const CatalogSong({
    this.id,
    required this.title,
    required this.audioUrl,
    required this.coverImageUrl,
    required this.category,
    required this.r2Key,
    this.bucket = "",
  });

  bool get hasPublicUrl => audioUrl.startsWith("http");
}
