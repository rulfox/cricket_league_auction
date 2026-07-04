import 'package:flutter/material.dart';

/// Gates every export action (and other destructive/consequential actions,
/// e.g. deleting a team or clearing bids in Settings) behind an explicit
/// confirmation.
Future<bool> confirmExport(
  BuildContext context, {
  String message = 'Are you sure you want to export?',
  String title = 'Confirm Export',
  String confirmLabel = 'Export',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
