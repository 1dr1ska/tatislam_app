import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/providers/text_scale_provider.dart';
import 'package:tatislam_app/features/detail/domain/services/html_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders a [TextContentBlock] as plain text with HTML stripped.
class TextContentWidget extends ConsumerWidget {
  final TextContentBlock block;
  final HtmlParserService htmlParser;

  const TextContentWidget({
    super.key,
    required this.block,
    this.htmlParser = const HtmlParserService(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(textScaleProvider).scale;
    // At large text sizes justified alignment creates excessive word gaps.
    // Switch to start-aligned for better readability.
    final align = textScale > 1.15 ? TextAlign.start : TextAlign.justify;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText(
        htmlParser.parseToPlainText(block.text),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF2D2D44),
          height: 1.7,
          letterSpacing: 0.2,
        ),
        textAlign: align,
      ),
    );
  }
}
