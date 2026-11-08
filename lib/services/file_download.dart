import 'dart:typed_data';

import 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart' as impl;

/// Whether [downloadFile] can save files (on web, through the browser's downloads).
bool get canDownloadFiles => impl.canDownloadFiles;

/// Saves [bytes] as a file called [name], of type [mimeType], as the browser downloads it.
void downloadFile(String name, Uint8List bytes, String mimeType) =>
    impl.downloadFile(name, bytes, mimeType);
