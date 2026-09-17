import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart' as loc;
import 'package:tatislam_app/features/admin/queue/publication_upload_queue.dart';
import 'package:tatislam_app/features/admin/queue/queue_providers.dart';

/// Admin screen showing the background publication save queue: every job
/// (queued / uploading / done / error / canceled) with its progress.
///
/// Re-renders automatically whenever the queue changes by watching the queue
/// version provider.
class UploadsQueueScreen extends ConsumerWidget {
  const UploadsQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(publicationUploadQueueProvider);
    ref.watch(publicationUploadQueueVersionProvider);
    final jobs = queue.items;

    return Column(
      children: [
        _buildSummary(queue, jobs, ref),
        const SizedBox(height: 8),
        Expanded(
          child: jobs.isEmpty ? _buildEmptyState() : _buildJobList(jobs, ref),
        ),
      ],
    );
  }

  Widget _buildSummary(
    PublicationUploadQueue queue,
    List<QueuedPublication> jobs,
    WidgetRef ref,
  ) {
    final t = loc.AppLocalizations.admin;
    final active = jobs
        .where(
          (job) =>
              job.status == UploadJobStatus.queued ||
              job.status == UploadJobStatus.uploading,
        )
        .length;
    final done = jobs.where((job) => job.status == UploadJobStatus.done).length;
    final errors = jobs
        .where((job) => job.status == UploadJobStatus.error)
        .length;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 24, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.uploadsTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _summaryLine(t, active, done, errors),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (queue.hasFinishedItems)
              TextButton(
                onPressed: () =>
                    ref.read(publicationUploadQueueProvider).clearFinished(),
                child: Text(t.uploadsClearFinished),
              ),
          ],
        ),
      ),
    );
  }

  String _summaryLine(
    loc.AppLocalizations t,
    int active,
    int done,
    int errors,
  ) {
    final parts = <String>[t.uploadsActiveCount(active)];
    if (done > 0) {
      parts.add('${t.uploadsDone}: $done');
    }
    if (errors > 0) {
      parts.add('${t.uploadsError}: $errors');
    }
    return parts.join('  ·  ');
  }

  Widget _buildEmptyState() {
    final t = loc.AppLocalizations.admin;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, size: 64, color: AppColors.secondary),
          const SizedBox(height: 16),
          Text(
            t.uploadsEmpty,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList(List<QueuedPublication> jobs, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return _buildJobCard(jobs[index], ref);
      },
    );
  }

  Widget _buildJobCard(QueuedPublication job, WidgetRef ref) {
    final t = loc.AppLocalizations.admin;
    final style = _statusStyle(job.status);
    final typeInfo = _typeInfoFor(job.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: typeInfo.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(typeInfo.icon, size: 22, color: typeInfo.color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _jobSubtitle(job),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(style.icon, size: 18, color: style.color),
                const SizedBox(width: 6),
                if (job.status == UploadJobStatus.queued ||
                    job.status == UploadJobStatus.uploading)
                  IconButton(
                    icon: const Icon(Icons.block),
                    tooltip: t.uploadsCancel,
                    onPressed: () => ref
                        .read(publicationUploadQueueProvider)
                        .cancel(job.jobId),
                  )
                else if (job.status == UploadJobStatus.error)
                  IconButton(
                    icon: const Icon(Icons.replay),
                    tooltip: t.uploadsRetry,
                    onPressed: () => ref
                        .read(publicationUploadQueueProvider)
                        .retry(job.jobId),
                  ),
              ],
            ),
            if (job.status == UploadJobStatus.queued ||
                job.status == UploadJobStatus.uploading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: job.status == UploadJobStatus.uploading
                    ? _progressValue(job)
                    : null,
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(_progressLabel(job), style: const TextStyle(fontSize: 12)),
            ],
            if (job.status == UploadJobStatus.error &&
                job.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                job.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _jobSubtitle(QueuedPublication job) {
    return '${_typeInfoFor(job.type).label}  ·  ${_statusWord(job.status)}  ·  ${_formatTime(job.createdAt)}';
  }

  String _statusWord(UploadJobStatus status) {
    final t = loc.AppLocalizations.admin;
    switch (status) {
      case UploadJobStatus.queued:
        return t.uploadsQueued;
      case UploadJobStatus.uploading:
        return t.uploadsUploading;
      case UploadJobStatus.done:
        return t.uploadsDone;
      case UploadJobStatus.error:
        return t.uploadsError;
      case UploadJobStatus.canceled:
        return t.uploadsCanceled;
    }
  }

  String _progressLabel(QueuedPublication job) {
    final t = loc.AppLocalizations.admin;
    final progress = job.progress;
    final stepIndex = progress.stepIndex < job.steps.length
        ? progress.stepIndex
        : job.steps.length - 1;
    if (job.steps[stepIndex] == SaveJobStep.uploadingFiles &&
        progress.fileCount > 0) {
      return t.uploadingFileProgress(progress.fileIndex, progress.fileCount);
    }
    return _stepLabel(job.steps[stepIndex]);
  }

  String _stepLabel(SaveJobStep step) {
    final t = loc.AppLocalizations.admin;
    switch (step) {
      case SaveJobStep.savingMetadata:
        return t.savingMetadata;
      case SaveJobStep.uploadingFiles:
        return t.uploadingFiles;
      case SaveJobStep.savingSections:
        return t.savingSections;
      case SaveJobStep.savingBlocks:
        return t.savingBlocks;
    }
  }

  double _progressValue(QueuedPublication job) {
    final progress = job.progress;
    final stepCount = job.steps.length;
    var value = stepCount == 0 ? 0.0 : progress.stepIndex / stepCount;
    if (progress.fileCount > 0 &&
        progress.stepIndex < job.steps.length &&
        job.steps[progress.stepIndex] == SaveJobStep.uploadingFiles) {
      value += (progress.fileIndex / progress.fileCount) * (1.0 / stepCount);
    }
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  _JobStatusStyle _statusStyle(UploadJobStatus status) {
    switch (status) {
      case UploadJobStatus.queued:
        return _JobStatusStyle(Icons.schedule, Colors.grey.shade600);
      case UploadJobStatus.uploading:
        return _JobStatusStyle(Icons.cloud_upload, Colors.blue.shade600);
      case UploadJobStatus.done:
        return _JobStatusStyle(Icons.check_circle, Colors.green.shade600);
      case UploadJobStatus.error:
        return _JobStatusStyle(Icons.error, Colors.red.shade600);
      case UploadJobStatus.canceled:
        return _JobStatusStyle(Icons.block, Colors.orange.shade600);
    }
  }

  _TypeInfo _typeInfoFor(String type) {
    switch (type) {
      case 'article':
        return _TypeInfo(Icons.article, 'Статья', AppColors.articleColor);
      case 'audio':
        return _TypeInfo(Icons.audiotrack, 'Аудио', AppColors.audioColor);
      case 'video':
        return _TypeInfo(Icons.play_circle, 'Видео', AppColors.videoColor);
      case 'photo':
        return _TypeInfo(Icons.photo, 'Фото', AppColors.photoColor);
      default:
        return _TypeInfo(Icons.article, 'Статья', AppColors.articleColor);
    }
  }
}

class _JobStatusStyle {
  final IconData icon;
  final Color color;
  const _JobStatusStyle(this.icon, this.color);
}

class _TypeInfo {
  final IconData icon;
  final String label;
  final Color color;
  const _TypeInfo(this.icon, this.label, this.color);
}
