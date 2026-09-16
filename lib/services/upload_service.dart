import "dart:io";
import "dart:typed_data";

import "r2_service.dart";

enum UploadStatus { queued, uploading, done, error }

class UploadJob {
  final String localPath;
  final String r2Key;
  UploadStatus status = UploadStatus.queued;
  String? error;
  UploadJob({required this.localPath, required this.r2Key});

  bool get done => status == UploadStatus.done;
}

class UploadService {
  final R2Service r2;
  UploadService(this.r2);

  static const parallel = 2;

  Future<void> uploadAll(
    List<UploadJob> jobs, {
    String? bucket,
    int concurrency = parallel,
    void Function(int done, int total, UploadJob job)? onEach,
  }) async {
    var next = 0;
    var finished = 0;
    final slots = concurrency < 1 ? 1 : concurrency;

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= jobs.length) return;
        final job = jobs[i];
        job.status = UploadStatus.uploading;
        onEach?.call(finished, jobs.length, job);
        try {
          final bytes = await File(job.localPath).readAsBytes();
          await r2.putObject(
            key: job.r2Key,
            bytes: Uint8List.fromList(bytes),
            bucket: bucket,
          );
          job.status = UploadStatus.done;
          job.error = null;
        } catch (e) {
          job.status = UploadStatus.error;
          job.error = e.toString();
        }
        finished++;
        onEach?.call(finished, jobs.length, job);
      }
    }

    await Future.wait([for (var s = 0; s < slots; s++) worker()]);
  }

  static String joinKey(String prefix, String filename) {
    final p = prefix.trim().replaceAll(RegExp(r"^/+|/+$"), "");
    final name = filename.split("/").last.split("\\").last;
    if (p.isEmpty) return name;
    return "$p/$name";
  }
}
