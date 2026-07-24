import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug provider for admin access - only works in debug mode
final debugAdminAccessProvider = Provider<bool>((ref) {
  // In debug mode, enable admin access by default
  return kDebugMode;
});

/// Provider that combines real admin check with debug override
final isAdminOrDebugProvider = Provider<bool>((ref) {
  // First check if debug admin access is enabled
  final isDebugAdmin = ref.watch(debugAdminAccessProvider);
  if (isDebugAdmin) {
    return true;
  }
  
  // Fall back to regular admin check (this would typically check user role)
  return false;
});
