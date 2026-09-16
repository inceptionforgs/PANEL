import "dart:convert";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;

import "../models/r2_object.dart";
import "../secrets.dart";

/// Cloudflare R2 via S3 path-style + AWS SigV4.
/// Region is always `auto`. PUT uses UNSIGNED-PAYLOAD (no body hash).
class R2Service {
  static const _emptyHash =
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
  static const _unsigned = "UNSIGNED-PAYLOAD";

  final http.Client _http;
  R2Service({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  String get _host => "${Secrets.r2AccountId}.r2.cloudflarestorage.com";

  Future<List<String>> listBuckets() async {
    final xml = await _signed("GET", path: "/");
    return parseBuckets(xml);
  }

  Future<void> createBucket(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw Exception("Bucket naam khali hai");
    await _signed("PUT", path: "/$n");
  }

  Future<void> deleteBucket(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw Exception("Bucket naam khali hai");
    await _signed("DELETE", path: "/$n");
  }

  Future<List<R2Object>> listAll({String? bucket, String prefix = ""}) async {
    final b = (bucket == null || bucket.isEmpty) ? Secrets.r2Bucket : bucket;
    final out = <R2Object>[];
    String? token;
    do {
      final q = <String, String>{
        "list-type": "2",
        "max-keys": "1000",
      };
      if (prefix.isNotEmpty) q["prefix"] = prefix;
      if (token != null) q["continuation-token"] = token;
      final xml = await _signed(
        "GET",
        path: "/$b",
        query: q,
      );
      out.addAll(parseList(xml, bucket: b));
      final truncated = xml.contains("<IsTruncated>true</IsTruncated>");
      token = truncated ? _tag(xml, "NextContinuationToken") : null;
    } while (token != null && token.isNotEmpty);
    return out;
  }

  Future<void> putObject({
    required String key,
    required Uint8List bytes,
    String contentType = "audio/mpeg",
    String? bucket,
  }) async {
    final b = (bucket == null || bucket.isEmpty) ? Secrets.r2Bucket : bucket;
    await _signed(
      "PUT",
      path: "/$b/${key.split("/").where((s) => s.isNotEmpty).join("/")}",
      headersExtra: {"content-type": contentType},
      body: bytes,
    );
  }

  Future<void> deleteObject({
    required String key,
    String? bucket,
  }) async {
    final b = (bucket == null || bucket.isEmpty) ? Secrets.r2Bucket : bucket;
    await _signed(
      "DELETE",
      path: "/$b/${key.split("/").where((s) => s.isNotEmpty).join("/")}",
    );
  }

  Future<String> _signed(
    String method, {
    required String path,
    Map<String, String>? query,
    Map<String, String>? headersExtra,
    Uint8List? body,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = amzDate.substring(0, 8);
    final payloadHash = body == null ? _emptyHash : _unsigned;
    final canonicalPath = _canonicalPath(path);

    final headers = <String, String>{
      "host": _host,
      "x-amz-content-sha256": payloadHash,
      "x-amz-date": amzDate,
      ...?headersExtra,
    };

    final signedHeaders = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    final canonicalHeaders =
        signedHeaders.map((k) => "$k:${headers[k]!.trim()}\n").join();
    final canonicalQuery = _canonicalQuery(query ?? {});
    final canonicalRequest = [
      method,
      canonicalPath,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders.join(";"),
      payloadHash,
    ].join("\n");

    const region = "auto";
    const service = "s3";
    final scope = "$dateStamp/$region/$service/aws4_request";
    final stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join("\n");
    final signingKey = _signingKey(dateStamp, region, service);
    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();
    headers["authorization"] =
        "AWS4-HMAC-SHA256 Credential=${Secrets.r2AccessKey}/$scope, SignedHeaders=${signedHeaders.join(";")}, Signature=$signature";

    final uri = Uri.parse(
      "https://$_host$canonicalPath${canonicalQuery.isEmpty ? "" : "?$canonicalQuery"}",
    );
    final req = http.Request(method, uri);
    req.headers.addAll(headers);
    if (body != null) req.bodyBytes = body;
    final res = await _http.send(req).then(http.Response.fromStream);
    if (res.statusCode >= 400) {
      throw Exception("R2 ${res.statusCode}: ${res.body}");
    }
    return res.body;
  }

  String _amzDate(DateTime now) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${now.year}${two(now.month)}${two(now.day)}T${two(now.hour)}${two(now.minute)}${two(now.second)}Z";
  }

  /// Encode each path segment once (S3/R2 canonical URI). Never pass a
  /// pre-encoded path into Dart's Uri() — that double-encodes `%`.
  String _canonicalPath(String path) {
    final raw = path.startsWith("/") ? path : "/$path";
    final segs = raw.split("/");
    return segs.map((s) => s.isEmpty ? "" : _awsEncode(s)).join("/");
  }

  List<int> _signingKey(String date, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode("AWS4${Secrets.r2SecretKey}"))
        .convert(utf8.encode(date))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode("aws4_request")).bytes;
  }

  String _canonicalQuery(Map<String, String> q) {
    if (q.isEmpty) return "";
    final keys = q.keys.toList()..sort();
    return keys.map((k) => "${_awsEncode(k)}=${_awsEncode(q[k]!)}").join("&");
  }

  String _awsEncode(String s) {
    return Uri.encodeQueryComponent(s).replaceAll("+", "%20");
  }

  static List<String> parseBuckets(String xml) {
    final out = <String>[];
    final blocks = RegExp(r"<Bucket>([\s\S]*?)</Bucket>").allMatches(xml);
    for (final m in blocks) {
      final name = _unescape(_tag(m.group(1)!, "Name") ?? "");
      if (name.isNotEmpty) out.add(name);
    }
    out.sort();
    return out;
  }

  static List<R2Object> parseList(String xml, {String bucket = ""}) {
    final out = <R2Object>[];
    final contents = RegExp(r"<Contents>([\s\S]*?)</Contents>").allMatches(xml);
    for (final m in contents) {
      final block = m.group(1)!;
      final key = _unescape(_tag(block, "Key") ?? "");
      if (key.isEmpty || key.endsWith("/")) continue;
      final size = int.tryParse(_tag(block, "Size") ?? "0") ?? 0;
      final lm = DateTime.tryParse(_tag(block, "LastModified") ?? "");
      out.add(R2Object(key: key, size: size, lastModified: lm, bucket: bucket));
    }
    return out;
  }

  static String? _tag(String xml, String name) {
    final m = RegExp("<$name>([^<]*)</$name>").firstMatch(xml);
    return m?.group(1);
  }

  static String _unescape(String s) {
    return s
        .replaceAll("&quot;", '"')
        .replaceAll("&apos;", "'")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&amp;", "&");
  }
}
