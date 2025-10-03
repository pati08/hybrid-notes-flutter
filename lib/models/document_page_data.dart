import 'dart:typed_data';
import 'package:fleather/fleather.dart';

class DocumentPageData {
  final String type; // 'DigitalPage' or 'ImagePage'
  FleatherController? controller; // For DigitalPage
  String? imageUrl; // For ImagePage
  Uint8List? imageBytes; // For ImagePage (cached)
  bool isImageLoaded = false; // Track if image has been downloaded

  DocumentPageData.digital({FleatherController? controller})
      : type = 'DigitalPage',
        controller =
            controller ?? FleatherController(document: ParchmentDocument()),
        imageUrl = null,
        imageBytes = null;

  DocumentPageData.image({this.imageUrl, this.imageBytes})
      : type = 'ImagePage',
        controller = null,
        isImageLoaded = imageBytes != null;

  void dispose() {
    controller?.dispose();
  }
}
