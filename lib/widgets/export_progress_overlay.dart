import 'package:flutter/material.dart';

/// Presentational extraction of the app's original capture-progress overlay,
/// parameterized so both the home card screen (all-cards export) and the
/// teams export screen (complete/photo export) can reuse it.
class ExportProgressOverlay extends StatelessWidget {
  const ExportProgressOverlay({
    super.key,
    required this.completed,
    required this.total,
    required this.packaging,
  });

  final int completed;
  final int total;
  final bool packaging;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                packaging ? "Packaging ZIP…" : "Exporting $completed / $total",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
