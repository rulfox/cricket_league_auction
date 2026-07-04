import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/player.dart';

/// One line of styled text on a player card, e.g. `CardLine("#12", 70)`.
class CardLine {
  const CardLine(this.text, this.fontSize);

  final String text;
  final double fontSize;
}

/// Shared card layout (background + logo + styled info lines on the left,
/// player photo on the right) used both by the home screen's live browsing
/// card and by the "complete as photo" per-player export card. Deliberately
/// contains no icons/buttons of its own, so anything wrapping it in a
/// `RepaintBoundary` for capture never accidentally includes UI chrome.
class PlayerCardLayout extends StatelessWidget {
  const PlayerCardLayout({
    super.key,
    required this.player,
    required this.lines,
    this.onPhotoTap,
  });

  final Player player;
  final List<CardLine> lines;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background.png"),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Image.asset(
                        "assets/images/msl_logo.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (int i = 0; i < lines.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _StyledText(lines[i].text, fontSize: lines[i].fontSize),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _PlayerPhotoPanel(player: player, onTap: onPhotoTap)),
      ],
    );
  }
}

class _StyledText extends StatelessWidget {
  const _StyledText(this.text, {this.fontSize = 48});

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

class _PlayerPhotoPanel extends StatelessWidget {
  const _PlayerPhotoPanel({required this.player, this.onTap});

  final Player player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photo = Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Image.asset(
              player.getPlayerPhoto(),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Image.asset(
          player.getPlayerPhoto(),
          fit: BoxFit.fitHeight,
          width: double.infinity,
          height: double.infinity,
        ),
      ],
    );
    if (onTap == null) return photo;
    return GestureDetector(onTap: onTap, child: photo);
  }
}
