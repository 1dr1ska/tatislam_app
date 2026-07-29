import 'package:flutter/material.dart';
import 'package:tatislam_app/features/detail/domain/services/html_parser_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Renders a [TextContentBlock] as plain text with HTML stripped.
class TextContentWidget extends StatelessWidget {
  final TextContentBlock block;
  final HtmlParserService htmlParser;

  const TextContentWidget({
    super.key,
    required this.block,
    this.htmlParser = const HtmlParserService(),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        htmlParser.parseToPlainText(block.text),
        style: const TextStyle(
          color: Color(0xFF2D2D44),
          fontSize: 16,
          height: 1.7,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }
}