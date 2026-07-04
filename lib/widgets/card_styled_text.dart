import 'package:flutter/material.dart';

/// Shared "on-brand" styled text (bold `VTFRedZone`, white, drop-shadowed) —
/// used by [PlayerCardLayout] and [TeamRosterCard] so both surfaces share the
/// exact same look for text painted over the branded background image.
class CardStyledText extends StatelessWidget {
  const CardStyledText(this.text, {super.key, this.fontSize = 48});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
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
