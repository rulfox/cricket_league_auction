import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Non-web implementation: writes the bytes to a temp file and hands it to
/// the platform's native share/save sheet, since desktop/mobile has no
/// browser download prompt to piggyback on.
Future<void> downloadBytes(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: fileName);
}
