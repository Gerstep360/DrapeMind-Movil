import 'package:flutter/material.dart';

/// A deliberately small, non-HTML Markdown renderer for Altair responses.
/// Fenced text is kept verbatim so diagrams do not lose spacing on phones.
class AltairMessageBody extends StatelessWidget {
  final String text;
  final TextStyle style;
  const AltairMessageBody({super.key, required this.text, required this.style});

  List<InlineSpan> _inline(String value) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    var end = 0;
    for (final match in pattern.allMatches(value)) {
      spans.add(TextSpan(text: value.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: match.group(1) ?? match.group(2),
          style: TextStyle(
            fontWeight: match.group(1) != null ? FontWeight.bold : null,
            fontFamily: match.group(2) != null ? 'monospace' : null,
          ),
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: value.substring(end)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        final code = <String>[];
        while (++i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
        }
        children.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD7D4CA)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code.join('\n'),
                style: style.copyWith(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        );
        continue;
      }
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final rows = <List<String>>[];
        while (i < lines.length &&
            lines[i].trim().startsWith('|') &&
            lines[i].trim().endsWith('|')) {
          final cells = lines[i].trim().split('|');
          final values = cells
              .sublist(1, cells.length - 1)
              .map((s) => s.trim())
              .toList();
          if (!values.every((s) => RegExp(r'^[-: ]+$').hasMatch(s))) {
            rows.add(values);
          }
          i++;
        }
        i--;
        children.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows
                  .asMap()
                  .entries
                  .map(
                    (entry) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: entry.value
                          .map(
                            (cell) => Container(
                              width: 150,
                              padding: const EdgeInsets.all(8),
                              child: Text.rich(
                                TextSpan(children: _inline(cell)),
                                style: style.copyWith(
                                  fontWeight: entry.key == 0
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        continue;
      }
      final heading = RegExp(r'^#{1,3}\s+').hasMatch(line);
      line = line
          .replaceFirst(RegExp(r'^#{1,3}\s+'), '')
          .replaceFirst(RegExp(r'^[-*]\s+'), '• ');
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 4, top: heading ? 8 : 0),
          child: SelectableText.rich(
            TextSpan(children: _inline(line)),
            style: heading
                ? style.copyWith(fontWeight: FontWeight.bold, fontSize: 16)
                : style,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
