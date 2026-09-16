class CfLine {
  final String name;
  final String family;
  final double cost;
  final double quantity;
  final String unit;
  const CfLine({
    required this.name,
    required this.family,
    required this.cost,
    required this.quantity,
    required this.unit,
  });
}

class OwnerUsage {
  final String? error;
  final String currency;
  final double costUsd;
  final int r2Bytes;
  final int classA;
  final int classB;
  final int objectCount;
  final List<CfLine> lines;

  const OwnerUsage({
    this.error,
    this.currency = "USD",
    this.costUsd = 0,
    this.r2Bytes = 0,
    this.classA = 0,
    this.classB = 0,
    this.objectCount = 0,
    this.lines = const [],
  });

  static const freeStorageBytes = 10 * 1024 * 1024 * 1024;
  static const freeClassA = 1000000;
  static const freeClassB = 10000000;

  double get storagePct => r2Bytes / freeStorageBytes;
  double get classAPct => classA / freeClassA;
  double get classBPct => classB / freeClassB;
}
