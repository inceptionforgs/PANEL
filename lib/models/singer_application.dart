class SingerApplication {
  final String id;
  final String name;
  final String mobileNumber;
  final String idDocumentPath;
  final String livenessImagePath;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String termsVersion;

  const SingerApplication({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.idDocumentPath,
    required this.livenessImagePath,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
    required this.termsVersion,
  });

  factory SingerApplication.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return SingerApplication(
      id: json["id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      mobileNumber: json["mobile_number"] as String? ?? "",
      idDocumentPath: json["id_document_path"] as String? ?? "",
      livenessImagePath: json["liveness_image_path"] as String? ?? "",
      status: json["status"] as String? ?? "pending",
      rejectionReason: json["rejection_reason"] as String?,
      createdAt: dt(json["created_at"]) ?? DateTime.now(),
      reviewedAt: dt(json["reviewed_at"]),
      termsVersion: json["terms_version"] as String? ?? "",
    );
  }
}
