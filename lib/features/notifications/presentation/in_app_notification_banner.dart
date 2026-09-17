import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/navigation/app_router.dart';
import 'package:tatislam_app/features/notifications/domain/entities/push_payload.dart';
import 'package:tatislam_app/features/notifications/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// App-wide push notification wiring, mounted via `MaterialApp.builder`.
///
/// Responsibilities (notification-related UI only):
///  - shows a glassmorphism banner for *foreground* messages (the OS does not
///    display a system banner while the app is in the foreground);
///  - navigates to `/publication/:id` when a push is tapped while the app is
///    in background or was terminated (uses the existing go_router).
class InAppNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const InAppNotificationListener({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState
    extends ConsumerState<InAppNotificationListener> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<PushPayload>? _tapSub;

  @override
  void initState() {
    super.initState();
    _foregroundSub = NotificationService.instance.foregroundMessages.listen(
      _onForegroundMessage,
    );
    _tapSub = NotificationService.instance.publicationTapEvents.listen(
      _handleTap,
    );
    // Cold start: the tap that launched the app is available only once the
    // router is up, so defer it to the next frame.
    final pending = NotificationService.instance.takePendingInitialTap();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleTap(pending);
      });
    }
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    super.dispose();
  }

  void _handleTap(PushPayload payload) {
    final publicationId = payload.publicationId;
    if (publicationId == null) return;

    // Фото-публикации открываются полноэкранным просмотрщиком автоматически:
    // детальный экран (/publication/:id) сам рендерит ImageViewerScreen для
    // type == 'photo' (у них нет контент-блоков).
    final router = ref.read(appRouterProvider);
    final route = '/publication/$publicationId';
    if (router.state.matchedLocation != route) {
      router.go(route);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final payload = PushPayload.fromData(message.data);
    final publicationId = payload.publicationId;
    if (publicationId == null) return;

    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final t = AppLocalizations.of(ref);
    final title =
        message.notification?.title ??
        payload.publicationTitle ??
        t.notificationNewPublicationTitle;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xE61A1A2E),
          elevation: 0,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFFE0B84A),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8F7F2),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: t.notificationOpenAction,
            textColor: const Color(0xFFE0B84A),
            onPressed: () => _handleTap(payload),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}