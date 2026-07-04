/// Strips characters illegal in Windows (and awkward in zip/Excel) file and
/// folder names from free-text input like team names, and collapses
/// whitespace so the result is a clean single path segment.
String sanitizeFileSegment(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final collapsed = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.isEmpty ? 'Unnamed' : collapsed;
}
