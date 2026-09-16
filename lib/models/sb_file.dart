class SbBucket {
  final String id;
  final String name;
  final bool isPublic;
  const SbBucket({required this.id, required this.name, required this.isPublic});

  factory SbBucket.fromJson(Map<String, dynamic> j) => SbBucket(
        id: "${j["id"] ?? j["name"] ?? ""}",
        name: "${j["name"] ?? j["id"] ?? ""}",
        isPublic: j["public"] == true,
      );
}

class SbObject {
  final String name;
  final int bytes;
  final String? updatedAt;
  const SbObject({required this.name, required this.bytes, this.updatedAt});

  factory SbObject.fromJson(Map<String, dynamic> j) {
    final meta = j["metadata"];
    var size = 0;
    if (meta is Map) size = (meta["size"] as num?)?.toInt() ?? 0;
    return SbObject(
      name: "${j["name"] ?? ""}",
      bytes: size,
      updatedAt: j["updated_at"]?.toString(),
    );
  }

  bool get isFolder => name.endsWith("/") || bytes == 0 && !name.contains(".");
}

class SbUser {
  final String id;
  final String email;
  final String phone;
  final String createdAt;
  final String lastSignIn;
  const SbUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.lastSignIn,
  });

  factory SbUser.fromJson(Map<String, dynamic> j) => SbUser(
        id: "${j["id"] ?? ""}",
        email: "${j["email"] ?? ""}",
        phone: "${j["phone"] ?? ""}",
        createdAt: "${j["created_at"] ?? ""}",
        lastSignIn: "${j["last_sign_in_at"] ?? ""}",
      );
}
