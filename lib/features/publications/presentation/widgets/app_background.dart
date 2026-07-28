import 'package:flutter/material.dart';

/// Default background image path used when no section-specific background is set.
const String defaultBackgroundPath = 'assets/images/фон_облака.png';

/// Full-screen background widget that displays a section background image.
/// 
/// [imagePath] — path to the asset image. If null, [defaultBackgroundPath] is used.
/// The image is rendered with [BoxFit.cover] to fill the entire screen.
class AppBackground extends StatelessWidget {
  final String? imagePath;

  const AppBackground({super.key, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        imagePath ?? defaultBackgroundPath,
        fit: BoxFit.cover,
        key: const ValueKey('app_background'),
      ),
    );
  }
}
