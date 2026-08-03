import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Shared glassmorphism constants for the entire design system.
const double glassBlur = 12;
const double glassOpacity = 0.22;
const double glassBorderOpacity = 0.35;
const double glassBorderWidth = 0.8;
const double glassRadius = 8;

/// Detail screen glass constants (slightly larger radius, more transparency).
const double detailGlassBlur = 18;
const double detailGlassOpacity = 0.45;
const double detailGlassPadding = 24;
const double detailGlassRadius = 16;

/// A reusable glassmorphism container with BackdropFilter blur effect.
/// Used throughout the app for cards, buttons, and panels.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double? opacity;
  final double? borderRadius;
  final double? borderOpacity;
  final double? borderWidth;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity,
    this.borderRadius,
    this.borderOpacity,
    this.borderWidth,
    this.padding,
    this.width,
    this.height,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? glassRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? glassBlur,
          sigmaY: blur ?? glassBlur,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity ?? glassOpacity),
            borderRadius: BorderRadius.circular(borderRadius ?? glassRadius),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: borderOpacity ?? glassBorderOpacity,
              ),
              width: borderWidth ?? glassBorderWidth,
            ),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}