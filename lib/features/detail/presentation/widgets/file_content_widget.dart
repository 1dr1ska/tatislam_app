import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/file_transfer_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

const double _glassOpacity = 0.30;
const double _glassRadius = 12;
const double _glassWidth = 0.8;

/// Renders a [FileContentBlock] (pdf, docx и другие файлы) as a glass card with
/// the file name/size and «Скачать»/«Открыть» buttons.
class FileContentWidget extends ConsumerStatefulWidget {
  final FileContentBlock block;
  final MediaStorageRepository mediaStorage;

  const FileContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
  });

  @override
  ConsumerState<FileContentWidget> createState() => _FileContentWidgetState();
}

class _FileContentWidgetState extends ConsumerState<FileContentWidget> {
  bool _isDownloading = false;

  String _resolveUrl() {
    final path = widget.block.path;
    if (path.isEmpty) return '';
    return widget.mediaStorage.publicUrlFor(path);
  }

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes < 0) return '';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _handleDownload(BuildContext context) async {
    final url = _resolveUrl();
    if (url.isEmpty) return;
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final result = await service.saveFile(
        url: url,
        fileName: widget.block.name.isEmpty
            ? url.split('/').last
            : widget.block.name,
      );
      if (!mounted) return;
      if (result.status != FileSaveStatus.saved &&
          result.status != FileSaveStatus.canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось скачать файл'),
          ),
        );
      }
    } catch (e) {
      debugPrint('FileContentWidget: download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось скачать файл')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleOpen(BuildContext context) async {
    final url = _resolveUrl();
    if (url.isEmpty) return;
    if (await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
  }

  IconData _buildIcon() {
    final name = widget.block.name.toLowerCase();
    IconData icon = Icons.insert_drive_file;
    if (name.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (name.endsWith('.mp3') || name.endsWith('.m4a') ||
        name.endsWith('.wav') || name.endsWith('.ogg')) {
      icon = Icons.audiotrack;
    } else if (name.endsWith('.doc') || name.endsWith('.docx')) {
      icon = Icons.text_snippet;
    } else if (name.endsWith('.xls') || name.endsWith('.xlsx')) {
      icon = Icons.table_chart;
    } else if (name.endsWith('.zip') || name.endsWith('.rar') ||
        name.endsWith('.7z')) {
      icon = Icons.folder_zip;
    }
    return icon;
  }
@override
  Widget build(BuildContext context) {
    final url = _resolveUrl();
    final fileSize = _formatSize(widget.block.size);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _glassOpacity),
            borderRadius: BorderRadius.circular(_glassRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: _glassWidth),
              width: _glassWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_buildIcon(), size: 40, color: const Color(0xFFE0B84A)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.block.name.isEmpty
                                ? 'Файл'
                                : widget.block.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFEFEF7),
                            ),
                          ),
                          if (fileSize.isNotEmpty)
                            Text(
                              fileSize,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (url.isNotEmpty)
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleDownload(context),
                        child: Text(_isDownloading ? 'Загрузка…' : 'Скачать'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _handleOpen(context),
                        child: Text('Открыть'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}