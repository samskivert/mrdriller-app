import 'dart:typed_data';
import 'dart:ui' show Rect;

bool get canDownloadFiles => false;

void downloadFile(String name, Uint8List bytes, String mimeType, {Rect? origin}) =>
    throw UnsupportedError('Downloading files is only supported on web');
