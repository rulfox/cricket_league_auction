import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/jackpot_override_screen.dart';

/// Wraps the whole app to detect a secret gesture — Ctrl+Shift+9 held
/// continuously for 5 seconds — that opens the hidden Jackpot override
/// screen. Deliberately not a memorable mnemonic (a "secret" gesture that's
/// easy to guess defeats the point), and deliberately not Ctrl+Shift+J,
/// which is the actual Chrome/Firefox DevTools shortcut and would likely be
/// intercepted by the browser before reaching the app.
///
/// Uses `HardwareKeyboard`'s raw key-event stream (not `Shortcuts`/`Focus`,
/// which are focus-tree-dependent) so it keeps working regardless of which
/// screen/widget currently has focus (a `TextField` in Settings, the Bid
/// sheet, anywhere), and the handler never consumes events, so normal
/// typing/shortcuts elsewhere in the app are completely unaffected.
class SecretJackpotGestureDetector extends StatefulWidget {
  const SecretJackpotGestureDetector({super.key, required this.child});

  final Widget child;

  @override
  State<SecretJackpotGestureDetector> createState() =>
      _SecretJackpotGestureDetectorState();
}

class _SecretJackpotGestureDetectorState extends State<SecretJackpotGestureDetector> {
  Timer? _holdTimer;
  bool _wasComboActive = false;
  bool _triggeredForThisHold = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _holdTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final comboActive = keyboard.isControlPressed &&
        keyboard.isShiftPressed &&
        keyboard.logicalKeysPressed.contains(LogicalKeyboardKey.digit9);

    if (comboActive && !_wasComboActive && !_triggeredForThisHold) {
      // Edge-triggered: only arm the timer on the transition into "all 3
      // held," not on every key-repeat event while already held.
      _holdTimer = Timer(const Duration(seconds: 5), _onHoldComplete);
    } else if (!comboActive) {
      // Any of the 3 keys released cancels the pending hold and requires a
      // fresh press-and-hold to arm again.
      _holdTimer?.cancel();
      _holdTimer = null;
      _triggeredForThisHold = false;
    }
    _wasComboActive = comboActive;
    return false; // passive observer — never consume the event
  }

  void _onHoldComplete() {
    _triggeredForThisHold = true;
    _holdTimer = null;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const JackpotOverrideScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
