import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/admin/presentation/screens/admin_dashboard_screen.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PopScope(
      canPop: false,
      child: AdminDashboardScreen(),
    );
  }
}
