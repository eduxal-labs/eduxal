import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Convenience helper. If bodyFormat == 'tiptap', parses JSON and returns
/// a TiptapRenderer. Otherwise returns a plain Text widget.
Widget renderBody(String body, String bodyFormat, {TextStyle? style}) {
  if (bodyFormat == 'tiptap') {
    final doc = jsonDecode(body) as Map<String, dynamic>;
    return TiptapRenderer(document: doc, baseStyle: style);
  }
  return Text(body, style: style);
}

/// Read-only renderer for TipTap/ProseMirror JSON documents.
class TiptapRenderer extends StatelessWidget {
  const TiptapRenderer({super.key, required this.document, this.baseStyle});

  final Map<String, dynamic> document;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) => _renderNode(context, document);

  Widget _renderNode(BuildContext context, Map<String, dynamic> node) {
    final type = node['type'] as String? ?? '';
    final content =
        (node['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    switch (type) {
      case 'doc':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.map((n) => _renderNode(context, n)).toList(),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style: baseStyle ?? DefaultTextStyle.of(context).style,
              children: content.map((n) => _renderInline(context, n)).toList(),
            ),
          ),
        );

      case 'orderedList':
        int idx = 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.map((item) {
            idx++;
            return _renderListItem(context, item, prefix: '$idx. ');
          }).toList(),
        );

      case 'bulletList':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content
              .map((item) => _renderListItem(context, item, prefix: '• '))
              .toList(),
        );

      case 'mathBlock':
        final latex = ((node['attrs'] as Map?)?['latex'] as String?) ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Math.tex(
              latex,
              mathStyle: MathStyle.display,
              textStyle: baseStyle ?? const TextStyle(fontSize: 16),
            ),
          ),
        );

      case 'table':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _renderTable(context, content),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  InlineSpan _renderInline(BuildContext context, Map<String, dynamic> node) {
    final type = node['type'] as String? ?? '';

    if (type == 'hardBreak') return const TextSpan(text: '\n');

    if (type == 'mathInline') {
      final latex = ((node['attrs'] as Map?)?['latex'] as String?) ?? '';
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          latex,
          textStyle: baseStyle ?? const TextStyle(fontSize: 14),
        ),
      );
    }

    if (type == 'text') {
      final text = node['text'] as String? ?? '';
      final marks =
          (node['marks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      var style = baseStyle ?? const TextStyle();
      for (final mark in marks) {
        switch (mark['type'] as String? ?? '') {
          case 'bold':
            style = style.copyWith(fontWeight: FontWeight.bold);
          case 'italic':
            style = style.copyWith(fontStyle: FontStyle.italic);
          case 'code':
            style = style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Colors.grey.shade100,
            );
        }
      }
      return TextSpan(text: text, style: style);
    }

    // Container inline nodes — recurse into content
    final content =
        (node['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return TextSpan(
      children: content.map((n) => _renderInline(context, n)).toList(),
    );
  }

  Widget _renderListItem(
    BuildContext ctx,
    Map<String, dynamic> item, {
    required String prefix,
  }) {
    final content =
        (item['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prefix, style: baseStyle),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.map((n) => _renderNode(ctx, n)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderTable(BuildContext ctx, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      defaultColumnWidth: const FlexColumnWidth(),
      children: rows.map((row) {
        final cells =
            (row['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final isHeader = row['type'] == 'tableHeader';
        return TableRow(
          decoration: isHeader
              ? BoxDecoration(color: Colors.grey.shade100)
              : null,
          children: cells.map((cell) {
            final cellContent =
                (cell['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            return Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cellContent.map((n) => _renderNode(ctx, n)).toList(),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
