import 'dart:typed_data';

bool get canDownloadFiles => false;

void downloadFile(String name, Uint8List bytes, String mimeType) =>
    throw UnsupportedError('Downloading files is only supported on web');
