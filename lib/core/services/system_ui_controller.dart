import 'package:flutter/services.dart';

/// Tracks the current system UI state so that [SystemChrome] is only called
/// when the state actually changes (idempotent).
enum SystemUiState { edgeToEdge, immersive }

/// Centralised controller for system UI mode transitions.
///
/// This is the **only** place in the app that calls [SystemChrome].
/// Every screen that needs to react to orientation changes does so via
/// [MediaQuery] / [LayoutBuilder] — never by calling [SystemChrome] directly.
class SystemUiController {
  static SystemUiState _current = SystemUiState.edgeToEdge;

  /// Switch to immersive sticky mode (hides system bars, tap to reveal).
  static void enterLandscape() {
    if (_current == SystemUiState.immersive) return;
    _current = SystemUiState.immersive;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Restore edge-to-edge mode (default system bars).
  static void exitLandscape() {
    if (_current == SystemUiState.edgeToEdge) return;
    _current = SystemUiState.edgeToEdge;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
