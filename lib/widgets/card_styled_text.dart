import 'package:flutter/material.dart';

/// Shared "on-brand" styled text (bold `VTFRedZone`, white, drop-shadowed) —
/// used by [PlayerCardLayout] and [TeamRosterCard] so both surfaces share the
/// exact same look for text painted over the branded background image.
class CardStyledText extends StatelessWidget {
  const CardStyledText(this.text, {super.key, this.fontSize = 48, this.maxLines, this.overflow});

  final String text;
  final double fontSize;

  /// Left null (unconstrained) for the large single-focus text this is
  /// normally used for. Roster-grid tiles pass `maxLines: 1` +
  /// `TextOverflow.ellipsis` so an unusually long name/phone can't wrap to a
  /// second line and overflow the tile's fixed height budget — `FittedBox`
  /// only shrinks content when its own box is constrained smaller than the
  /// child wants, which a plain `Column` child never is.
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'VTFRedZone',
          color: Colors.white,
          shadows: [
            Shadow(
              offset: const Offset(2, 2),
              blurRadius: 4,
              color: Colors.black.withValues(alpha: 0.7),
            ),
            Shadow(
              offset: const Offset(-1, -1),
              blurRadius: 3,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
