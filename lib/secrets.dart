/// Fill these BEFORE `flutter build apk`.
/// Personal phone only. Do not push real keys to a public repo.
class Secrets {
  static const r2AccountId = "PASTE_R2_ACCOUNT_ID";
  static const r2AccessKey = "PASTE_R2_ACCESS_KEY";
  static const r2SecretKey = "PASTE_R2_SECRET_KEY";
  static const r2Bucket = "mewati-songs";
  static const r2PublicBaseUrl =
      "https://pub-31576cb95c8740c8816316f85181ecdd.r2.dev";

  static const r2PublicBases = <String, String>{
    "mewati-songs":
        "https://pub-31576cb95c8740c8816316f85181ecdd.r2.dev",
  };

  static const cfApiToken = "PASTE_CF_API_TOKEN";

  static const supabaseUrl = "https://vryngmkjnposksoaknik.supabase.co";
  static const supabaseServiceKey = "PASTE_SUPABASE_SERVICE_ROLE_KEY";

  static const dbHost = "db.vryngmkjnposksoaknik.supabase.co";
  static const dbPort = 5432;
  static const dbName = "postgres";
  static const dbUser = "postgres";
  static const dbPassword = "PASTE_DATABASE_PASSWORD";

  static String? publicBaseFor(String bucket) => r2PublicBases[bucket];

  static bool get r2Ready =>
      !_isPaste(r2AccountId) && !_isPaste(r2AccessKey) && !_isPaste(r2SecretKey);

  static bool get cfReady => !_isPaste(cfApiToken);

  static bool get supabaseReady => !_isPaste(supabaseServiceKey);

  static bool get dbReady => !_isPaste(dbPassword);

  static bool _isPaste(String v) =>
      v.isEmpty || v.startsWith("PASTE_") || v.startsWith("tera ");
}
