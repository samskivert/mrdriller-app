import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart'
    if (dart.library.io) 'file_download_native.dart'
    as impl;

/// Whether [downloadFile] can save files: on web, through the browser's downloads; on iOS and
/// Android, through the share sheet.
bool get canDownloadFiles => impl.canDownloadFiles;

/// Saves [bytes] as a file called [name], of type [mimeType]: downloading it on web, or offering it
/// to share (to AirDrop or Files, say) on a phone, from [origin] on the screen (which iPads need,
/// to point the share sheet at).
void downloadFile(String name, Uint8List bytes, String mimeType, {Rect? origin}) =>
    impl.downloadFile(name, bytes, mimeType, origin: origin);
