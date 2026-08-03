import 'package:flutter/material.dart';
import 'package:tatislam_app/core/services/system_ui_controller.dart';

/// Wraps the app's root widget and centrally manages [SystemChrome] transitions
/// when the device orientation changes between portrait and landscape.
///
/// **Why a separate widget instead of putting this logic in [MaterialApp]:**
///   - Keeps the system UI controller decoupled from the app configuration.
///   - [build()] stays pure — [SystemChrome] is only called inside
///     [WidgetsBinding.instance.addPostFrameCallback].
///   - [WidgetsBindingObserver] guarantees system bars are restored after
///     the app is resumed (Android may reset immersive mode after a system
///     dialog or app switch).
///
/// **Layout decisions** (e.g. hiding the AppBar in landscape) remain the
/// responsibility of each screen — this widget only manages system bars.
class SystemUiListener extends StatefulWidget {
  final Widget child;

  const SystemUiListener({super.key, required this.child});

  @override
  State<SystemUiListener> createState() => _SystemUiListenerState();
}

class _SystemUiListenerState extends State<SystemUiListener>
    with WidgetsBindingObserver {
  Orientation? _previousOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Guarantee system bars are restored no matter how the app exits.
    SystemUiController.exitLandscape();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Android may reset immersive mode after:
      //   - app switch / minimise
      //   - system permission dialog
      //   - any other system overlay
      // Re-apply the correct mode for the current orientation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyForCurrentOrientation();
      });
    }
  }

  void _applyForCurrentOrientation() {
    if (!mounted) return;
    final orientation = MediaQuery.orientationOf(context);
    if (orientation == Orientation.landscape) {
      SystemUiController.enterLandscape();
    } else {
      SystemUiController.exitLandscape();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);

    // First build — remember the orientation and apply the correct mode
    // after the frame is laid out (pure build, no side effects).
    if (_previousOrientation == null) {
      _previousOrientation = orientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyForCurrentOrientation();
      });
      return widget.child;
    }

    // Real orientation change — switch system UI mode.
    if (_previousOrientation != orientation) {
      _previousOrientation = orientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (orientation == Orientation.landscape) {
          SystemUiController.enterLandscape();
        } else {
          SystemUiController.exitLandscape();
        }
      });
    }

    return widget.child;
  }
}