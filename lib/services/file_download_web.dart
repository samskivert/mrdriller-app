import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

bool get canDownloadFiles => true;

void downloadFile(String name, Uint8List bytes, String mimeType, {Rect? origin}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // (After the download has had a chance to start.)
  Future<void>.delayed(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}
