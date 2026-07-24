import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/features/admin/providers/debug_admin_provider.dart';

class DebugAdminAccess extends ConsumerWidget {
  const DebugAdminAccess({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final isAdminOrDebug = ref.watch(isAdminOrDebugProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAdminOrDebug 
          ? Colors.green.withValues(alpha: 0.1) 
          : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAdminOrDebug ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEBUG ADMIN ACCESS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isAdminOrDebug ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdminOrDebug
                          ? 'Admin access enabled (DEBUG MODE)'
                          : 'Tap button to enable admin access',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isAdminOrDebug ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAdminOrDebug)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                  onPressed: () {
                    // Enable debug admin access
                    // In a real implementation, this would set a flag
                    // For now, we'll just navigate to admin screen directly
                    context.push('/admin');
                  },
                ),
            ],
          ),
          if (!isAdminOrDebug)
            const SizedBox(height: 8),
          if (!isAdminOrDebug)
            Text(
              '⚠️ This is only visible in debug builds',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}