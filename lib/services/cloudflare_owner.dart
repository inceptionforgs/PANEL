import "dart:convert";

import "package:http/http.dart" as http;

import "../models/owner_usage.dart";
import "../secrets.dart";

class CloudflareOwner {
  static const _classA = {
    "PutObject",
    "CopyObject",
    "CompleteMultipartUpload",
    "CreateMultipartUpload",
    "ListBuckets",
    "ListMultipartUploads",
    "ListObjects",
    "ListObjectsV2",
    "ListParts",
    "PutBucketCors",
    "PutBucketEncryption",
    "PutBucketLifecycleConfiguration",
    "UploadPart",
    "DeleteObjects",
    "CreateBucket",
  };

  Future<OwnerUsage> load() async {
    if (!Secrets.cfReady) {
      return const OwnerUsage(error: "Cloudflare API token nahi. Billing Read + Analytics Read.");
    }
    try {
      final billing = await _billable();
      final metrics = await _metrics();
      return OwnerUsage(
        currency: billing.$1,
        costUsd: billing.$2,
        lines: billing.$3,
        r2Bytes: metrics.$1,
        objectCount: metrics.$2,
        classA: metrics.$3,
        classB: metrics.$4,
      );
    } catch (e) {
      return OwnerUsage(error: e.toString());
    }
  }

  Future<(String, double, List<CfLine>)> _billable() async {
    final uri = Uri.parse(
      "https://api.cloudflare.com/client/v4/accounts/${Secrets.r2AccountId}/billable-usage",
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 403 || res.statusCode == 401) {
      throw Exception("Token me Account Billing Read nahi hai.");
    }
    if (res.statusCode >= 400) {
      throw Exception("Billing ${res.statusCode}: ${res.body.length > 180 ? res.body.substring(0, 180) : res.body}");
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json["result"] as List?) ?? const [];
    var cost = 0.0;
    var currency = "USD";
    final lines = <CfLine>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      currency = "${m["BillingCurrency"] ?? currency}";
      final c = (m["ContractedCost"] as num?)?.toDouble() ??
          (m["CumulatedContractedCost"] as num?)?.toDouble() ??
          0;
      cost += c;
      lines.add(CfLine(
        name: "${m["ServiceName"] ?? m["x_ProductFamilyName"] ?? "Usage"}",
        family: "${m["ServiceFamilyName"] ?? ""}",
        cost: c,
        quantity: (m["ConsumedQuantity"] as num?)?.toDouble() ?? 0,
        unit: "${m["ConsumedUnit"] ?? ""}",
      ));
    }
    return (currency, cost, lines);
  }

  Future<(int, int, int, int)> _metrics() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, 1).toIso8601String();
    final end = now.toIso8601String();
    const q = r"""
query ($accountTag: string!, $startDate: Time, $endDate: Time) {
  viewer {
    accounts(filter: { accountTag: $accountTag }) {
      r2OperationsAdaptiveGroups(
        limit: 10000
        filter: { datetime_geq: $startDate, datetime_leq: $endDate }
      ) {
        sum { requests }
        dimensions { actionType }
      }
      r2StorageAdaptiveGroups(
        limit: 24
        filter: { datetime_geq: $startDate, datetime_leq: $endDate }
        orderBy: [datetime_DESC]
      ) {
        max { objectCount payloadSize }
      }
    }
  }
}
""";
    final res = await http.post(
      Uri.parse("https://api.cloudflare.com/client/v4/graphql"),
      headers: { ..._headers, "Content-Type": "application/json" },
      body: jsonEncode({
        "query": q,
        "variables": {
          "accountTag": Secrets.r2AccountId,
          "startDate": start,
          "endDate": end,
        },
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception("Analytics ${res.statusCode}");
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final errs = json["errors"];
    if (errs is List && errs.isNotEmpty) {
      throw Exception("Analytics: ${errs.first}");
    }
    final accounts = json["data"]?["viewer"]?["accounts"];
    if (accounts is! List || accounts.isEmpty) {
      return (0, 0, 0, 0);
    }
    final acc = accounts.first as Map;
    var classA = 0;
    var classB = 0;
    final ops = acc["r2OperationsAdaptiveGroups"];
    if (ops is List) {
      for (final row in ops) {
        if (row is! Map) continue;
        final action = "${(row["dimensions"] as Map?)?["actionType"] ?? ""}";
        final n = ((row["sum"] as Map?)?["requests"] as num?)?.toInt() ?? 0;
        if (_classA.contains(action)) {
          classA += n;
        } else {
          classB += n;
        }
      }
    }
    var bytes = 0;
    var objects = 0;
    final storage = acc["r2StorageAdaptiveGroups"];
    if (storage is List && storage.isNotEmpty && storage.first is Map) {
      final max = (storage.first as Map)["max"];
      if (max is Map) {
        bytes = (max["payloadSize"] as num?)?.toInt() ?? 0;
        objects = (max["objectCount"] as num?)?.toInt() ?? 0;
      }
    }
    return (bytes, objects, classA, classB);
  }

  Map<String, String> get _headers => {
        "Authorization": "Bearer ${Secrets.cfApiToken}",
        "Accept": "application/json",
      };
}
