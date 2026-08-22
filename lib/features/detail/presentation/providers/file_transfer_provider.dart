import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';

/// Provides the platform-aware audio transfer service for downloads and
/// sharing. Kept alive for the app lifetime so the shared HTTP client is not
/// torn down between uses.
final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  final service = FileTransferService();
  ref.keepAlive();
  return service;
});