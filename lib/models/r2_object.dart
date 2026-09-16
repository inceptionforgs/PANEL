class R2Object {
  final String key;
  final int size;
  final DateTime? lastModified;
  final String bucket;

  const R2Object({
    required this.key,
    required this.size,
    this.lastModified,
    this.bucket = "",
  });

  bool get isMp3 => key.toLowerCase().endsWith(".mp3");
}
