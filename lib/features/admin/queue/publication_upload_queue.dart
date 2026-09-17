import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:tatislam_app/features/admin/queue/queue_state_providers.dart';
import 'package:tatislam_app/features/admin/queue/publication_save_job.dart';
import 'package:tatislam_app/features/admin/queue/publication_save_payload.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Lifecycle of a queued background save job.
enum UploadJobStatus { queued, uploading, done, error, canceled }

/// Ordered pipeline stages of a save job (used for the step label on the
/// uploads screen).
enum SaveJobStep {
  savingMetadata,
  uploadingFiles,
  savingSections,
  savingBlocks,
}

/// Mutable progress snapshot of one job.
class SaveJobProgress {
  final int stepIndex;
  final int stepCount;
  final int fileIndex;
  final int fileCount;

  const SaveJobProgress({
    required this.stepIndex,
    required this.stepCount,
    required this.fileIndex,
    required this.fileCount,
  });
}

/// One publication queued for background saving.
///
/// Created by the queue, mutated by the queue worker, read by the uploads
/// screen. The [payload] is released once the job is done or canceled, so the
/// selected file bytes are freed as soon as they are no longer needed.
class QueuedPublication {
  final String jobId;
  final String? publicationId;
  final String title;
  final String type;
  final bool isCreate;
  final DateTime createdAt;
  final List<SaveJobStep> steps;
  final int fileCount;

  PublicationSavePayload? payload;
  UploadJobStatus status;
  SaveJobProgress progress;
  String? errorMessage;
  bool cancelRequested = false;

  QueuedPublication({
    required this.jobId,
    this.publicationId,
    required this.title,
    required this.type,
    required this.isCreate,
    required this.createdAt,
    required this.steps,
    required this.fileCount,
    this.payload,
    required this.status,
    required this.progress,
  });
}

/// App-wide background save queue for publications.
///
/// Editors enqueue a [PublicationSavePayload] and close immediately; a worker
/// loop inside this object processes the queue one job at a time, reporting
/// progress through [publicationUploadQueueVersionProvider] so screens can
/// re-render. Jobs survive navigation because the queue lives independently of
/// any editor screen.
class PublicationUploadQueue {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Jobs in insertion order; the worker takes them strictly FIFO.
  final List<QueuedPublication> _items = [];
  bool _pumpRunning = false;

  PublicationUploadQueue(this._ref);

  List<QueuedPublication> get items => List.unmodifiable(_items.toList());

  int get activeCount => _items.fold(
    0,
    (count, job) =>
        count +
        (job.status == UploadJobStatus.queued ||
                job.status == UploadJobStatus.uploading
            ? 1
            : 0),
  );

  /// Whether [publicationId] currently has a queued or uploading job.
  bool hasActiveJobFor(String publicationId) =>
      _activeJobFor(publicationId) != null;

  bool get hasFinishedItems => _items.any((job) => _isFinished(job.status));

  /// Puts [payload] into the queue and starts the background worker.
  ///
  /// Returns false when the same publication already has an active (queued or
  /// uploading) job — the editor should keep its form open in that case.
  bool enqueue(PublicationSavePayload payload) {
    if (payload.publicationId != null &&
        _activeJobFor(payload.publicationId!) != null) {
      return false;
    }
    _items.add(_newJob(payload));
    _notify();
    _pump();
    return true;
  }

  /// Re-queues a failed job. Its payload (and therefore the file bytes) is
  /// kept while the status is [UploadJobStatus.error] specifically for this.
  void retry(String jobId) {
    final job = _jobById(jobId);
    if (job == null ||
        job.status != UploadJobStatus.error ||
        job.payload == null) {
      return;
    }
    job.status = UploadJobStatus.queued;
    job.errorMessage = null;
    job.cancelRequested = false;
    job.progress = _initialProgress(job);
    _notify();
    _pump();
  }

  /// Cancels a queued job immediately, or asks an uploading job to stop after
  /// its current file/step (rolling back the partial work).
  void cancel(String jobId) {
    final job = _jobById(jobId);
    if (job == null) return;
    switch (job.status) {
      case UploadJobStatus.queued:
        job.status = UploadJobStatus.canceled;
        job.payload = null;
        job.errorMessage = null;
        _notify();
        break;
      case UploadJobStatus.uploading:
        job.cancelRequested = true;
        break;
      default:
        break;
    }
  }

  /// Drops finished, failed and canceled jobs entirely (releases file bytes).
  void clearFinished() {
    _items.removeWhere((job) => _isFinished(job.status));
    _notify();
  }

  // ---------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------

  QueuedPublication _newJob(PublicationSavePayload payload) {
    final steps = _stepsFor(payload);
    final fileCount = _fileCountFor(payload);
    return QueuedPublication(
      jobId: _uuid.v4(),
      publicationId: payload.publicationId,
      title: payload.title,
      type: payload.type,
      isCreate: payload.publicationId == null,
      createdAt: DateTime.now(),
      steps: steps,
      fileCount: fileCount,
      payload: payload,
      status: UploadJobStatus.queued,
      progress: SaveJobProgress(
        stepIndex: 0,
        stepCount: steps.length,
        fileIndex: 0,
        fileCount: fileCount,
      ),
    );
  }

  static List<SaveJobStep> _stepsFor(PublicationSavePayload payload) {
    if (!payload.isPhoto) {
      return [
        SaveJobStep.savingMetadata,
        SaveJobStep.uploadingFiles,
        SaveJobStep.savingSections,
        SaveJobStep.savingBlocks,
      ];
    }
    if (payload.publicationId == null) {
      return [
        SaveJobStep.savingMetadata,
        SaveJobStep.uploadingFiles,
        SaveJobStep.savingSections,
      ];
    }
    // Updating: the new photo is uploaded before the row is updated.
    return [
      SaveJobStep.uploadingFiles,
      SaveJobStep.savingMetadata,
      SaveJobStep.savingSections,
    ];
  }

  static int _fileCountFor(PublicationSavePayload payload) {
    if (payload.isPhoto) {
      return payload.newPhoto == null ? 0 : 1;
    }
    return payload.contentBlocks.fold(0, (count, block) {
      if (block is ImageContentBlock &&
          payload.newBlockImages.containsKey(block.id)) {
        return count + 1;
      }
      if (block is AudioContentBlock &&
          payload.newBlockAudios.containsKey(block.id)) {
        return count + 1;
      }
      return count;
    });
  }

  static SaveJobProgress _initialProgress(QueuedPublication job) =>
      SaveJobProgress(
        stepIndex: 0,
        stepCount: job.steps.length,
        fileIndex: 0,
        fileCount: job.fileCount,
      );

  QueuedPublication? _activeJobFor(String publicationId) {
    for (final job in _items) {
      if (job.publicationId == publicationId &&
          (job.status == UploadJobStatus.queued ||
              job.status == UploadJobStatus.uploading)) {
        return job;
      }
    }
    return null;
  }

  QueuedPublication? _jobById(String jobId) {
    for (final job in _items) {
      if (job.jobId == jobId) return job;
    }
    return null;
  }

  static bool _isFinished(UploadJobStatus status) =>
      status == UploadJobStatus.done ||
      status == UploadJobStatus.error ||
      status == UploadJobStatus.canceled;

  void _notify() {
    _ref.read(publicationUploadQueueVersionProvider.notifier).state++;
  }

  Future<void> _pump() async {
    if (_pumpRunning) return;
    _pumpRunning = true;
    try {
      while (true) {
        final job = _nextQueuedJob();
        if (job == null) return;
        await _runJob(job);
      }
    } finally {
      _pumpRunning = false;
    }
  }

  QueuedPublication? _nextQueuedJob() {
    for (final job in _items) {
      if (job.status == UploadJobStatus.queued) return job;
    }
    return null;
  }

  Future<void> _runJob(QueuedPublication job) async {
    job.status = UploadJobStatus.uploading;
    _notify();

    void report(int stepIndex, int fileIndex) {
      job.progress = SaveJobProgress(
        stepIndex: stepIndex,
        stepCount: job.steps.length,
        fileIndex: fileIndex,
        fileCount: job.fileCount,
      );
      _notify();
    }

    try {
      await PublicationSaveJob.run(
        _ref,
        job.payload!,
        report,
        () => job.cancelRequested,
      );
      job.status = UploadJobStatus.done;
      job.errorMessage = null;
      job.payload = null; // Release the selected file bytes.
    } catch (e) {
      if (e is PublicationSaveJobCanceled) {
        job.status = UploadJobStatus.canceled;
        job.errorMessage = null;
        job.payload = null;
      } else {
        job.status = UploadJobStatus.error;
        job.errorMessage = '$e';
      }
    } finally {
      job.cancelRequested = false;
      _notify();
    }
  }
}
