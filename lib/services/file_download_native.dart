import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

bool get canDownloadFiles => Platform.isIOS || Platform.isAndroid;

// Writes it to a temporary file and offers it through the share sheet (to AirDrop it to a
// computer, or save it to Files).
void downloadFile(String name, Uint8List bytes, String mimeType, {Rect? origin}) async {
  final file = File('${Directory.systemTemp.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType, name: name)],
      sharePositionOrigin: origin,
    ),
  );
}
