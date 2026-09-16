class Format {
  static String bytes(int n) {
    if (n < 1024) return "$n B";
    if (n < 1024 * 1024) return "${(n / 1024).toStringAsFixed(1)} KB";
    if (n < 1024 * 1024 * 1024) {
      return "${(n / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  static String publicUrl(String base, String key) {
    final b = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
    final parts = key.split("/").map(Uri.encodeComponent).join("/");
    return "$b/$parts";
  }

  static String titleFromKey(String key) {
    final name = key.split("/").last;
    final stem = name.toLowerCase().endsWith(".mp3")
        ? name.substring(0, name.length - 4)
        : name;
    final mewati = RegExp(r"mewati\s*song\s*(\d+)", caseSensitive: false);
    final m = mewati.firstMatch(stem);
    if (m != null) return "Mewati Song ${m.group(1)}";
    return stem.replaceAll("_", " ").replaceAll("-", " ").trim();
  }

  static String categoryFromKey(String key) {
    final parts = key.split("/");
    if (parts.length < 2) return "Mewati";
    for (final p in parts) {
      final l = p.toLowerCase();
      if (l == "mewati") return "Mewati";
      if (l == "punjabi") return "Punjabi";
      if (l.startsWith("hindi")) return "Hindi";
      if (l == "golu") return "Golu";
    }
    return parts[parts.length - 2];
  }

  static String folderOf(String key) {
    final i = key.lastIndexOf("/");
    return i <= 0 ? "/" : key.substring(0, i);
  }
}
