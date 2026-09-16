import "../core/format.dart";
import "r2_object.dart";

class FolderStat {
  final String bucket;
  final String folder;
  final int objects;
  final int mp3;
  final int bytes;

  const FolderStat({
    required this.bucket,
    required this.folder,
    required this.objects,
    required this.mp3,
    required this.bytes,
  });
}

class BucketStat {
  final String bucket;
  final int objects;
  final int mp3;
  final int folders;
  final int bytes;

  const BucketStat({
    required this.bucket,
    required this.objects,
    required this.mp3,
    required this.folders,
    required this.bytes,
  });
}

class ScanReport {
  final int objects;
  final int mp3;
  final int other;
  final int bytes;
  final List<BucketStat> buckets;
  final List<FolderStat> folders;

  const ScanReport({
    required this.objects,
    required this.mp3,
    required this.other,
    required this.bytes,
    required this.buckets,
    required this.folders,
  });

  int get folderCount => folders.length;

  static ScanReport from(List<R2Object> objects) {
    final folderAcc = <String, List<int>>{};
    for (final o in objects) {
      final bucket = o.bucket.isEmpty ? "-" : o.bucket;
      final folder = Format.folderOf(o.key);
      final k = "$bucket\u0000$folder";
      final row = folderAcc.putIfAbsent(k, () => [0, 0, 0]);
      row[0]++;
      if (o.isMp3) row[1]++;
      row[2] += o.size;
    }
    final folders = folderAcc.entries.map((e) {
      final parts = e.key.split("\u0000");
      return FolderStat(
        bucket: parts[0],
        folder: parts[1],
        objects: e.value[0],
        mp3: e.value[1],
        bytes: e.value[2],
      );
    }).toList()
      ..sort((a, b) {
        final c = a.bucket.compareTo(b.bucket);
        if (c != 0) return c;
        return a.folder.compareTo(b.folder);
      });

    final bucketAcc = <String, List<int>>{};
    final bucketFolders = <String, Set<String>>{};
    for (final f in folders) {
      final row = bucketAcc.putIfAbsent(f.bucket, () => [0, 0, 0]);
      row[0] += f.objects;
      row[1] += f.mp3;
      row[2] += f.bytes;
      bucketFolders.putIfAbsent(f.bucket, () => <String>{}).add(f.folder);
    }
    final buckets = bucketAcc.entries
        .map(
          (e) => BucketStat(
            bucket: e.key,
            objects: e.value[0],
            mp3: e.value[1],
            folders: bucketFolders[e.key]?.length ?? 0,
            bytes: e.value[2],
          ),
        )
        .toList()
      ..sort((a, b) => a.bucket.compareTo(b.bucket));

    final mp3 = objects.where((o) => o.isMp3).length;
    final bytes = objects.fold<int>(0, (a, o) => a + o.size);
    return ScanReport(
      objects: objects.length,
      mp3: mp3,
      other: objects.length - mp3,
      bytes: bytes,
      buckets: buckets,
      folders: folders,
    );
  }
}
