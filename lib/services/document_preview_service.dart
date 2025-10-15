import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'image_cache_service.dart';

/// Enhanced service for generating document previews with improved performance and reliability
class DocumentPreviewService {
  static final DocumentPreviewService _instance = DocumentPreviewService._internal();
  factory DocumentPreviewService() => _instance;
  DocumentPreviewService._internal();

  // Cache for generated previews
  final Map<String, Uint8List> _previewCache = {};
  
  // Track modified documents for selective cache invalidation
  final Set<String> _modifiedDocuments = {};
  
  // Configuration constants
  static const double _previewWidth = 400.0;
  static const double _previewHeight = 300.0; // Fixed height for consistent card layout
  static const double _padding = 16.0; // Match FleatherEditor padding
  static const double _textFontSize = 14.0;
  static const double _lineHeight = 1.4;
  
  // Document dimensions (standard A4-like proportions)
  static const double _documentWidth = 800.0;
  static const double _documentHeight = 1035.2;

  /// Generate a preview for a document
  /// Returns null if preview cannot be generated
  Future<Uint8List?> generatePreview(String documentId) async {
    if (documentId.isEmpty) return null;

    // Check cache first
    if (_previewCache.containsKey(documentId)) {
      return _previewCache[documentId];
    }

    // Simple approach - no complex async coordination
    try {
      final preview = await _createDocumentPreview(documentId);
      if (preview != null) {
        _previewCache[documentId] = preview;
      }
      return preview;
    } catch (e) {
      debugPrint('Error generating preview for document $documentId: $e');
      return null;
    }
  }

  /// Create a preview for a specific document
  Future<Uint8List?> _createDocumentPreview(String documentId) async {
    try {
      // Load document data
      final authService = AuthService();
      final result = await authService.getDocument(documentId);

      if (!result.success || result.document == null) {
        return _createEmptyPreview();
      }

      final document = result.document!;
      final pages = document['pages'] as List<dynamic>?;

      if (pages == null || pages.isEmpty) {
        return _createEmptyPreview();
      }

      // Get the first page for preview
      final firstPage = pages.first;
      final pageType = firstPage['page_type'];

      if (pageType == null) {
        return _createEmptyPreview();
      }

      final pageTypeString = pageType['type'] as String?;
      
      switch (pageTypeString) {
        case 'ImagePage':
          return await _createImagePagePreview(pageType);
        case 'DigitalPage':
          return await _createDigitalPagePreview(pageType, documentId);
        default:
          return _createEmptyPreview();
      }
    } catch (e) {
      debugPrint('Error creating document preview: $e');
      return _createEmptyPreview();
    }
  }

  /// Create preview for image pages
  Future<Uint8List?> _createImagePagePreview(Map<String, dynamic> pageType) async {
    final imageUrl = pageType['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _createEmptyPreview();
    }

    try {
      final imageCacheService = ImageCacheService();
      Uint8List? imageBytes = imageCacheService.getCachedImage(imageUrl);
      
      if (imageBytes == null) {
        await imageCacheService.preloadImages([imageUrl]);
        imageBytes = imageCacheService.getCachedImage(imageUrl);
      }

      if (imageBytes != null) {
        return _resizeImageForPreview(imageBytes);
      }
    } catch (e) {
      debugPrint('Error loading image for preview: $e');
    }

    return _createEmptyPreview();
  }

  /// Create preview for digital pages
  Future<Uint8List?> _createDigitalPagePreview(Map<String, dynamic> pageType, String documentId) async {
    try {
      // Extract text content from Quill JSON
      final textContent = _extractTextFromQuillJson(pageType['quill_json']);
      
      // Get drawings if available
      List<Map<String, dynamic>>? drawings;
      try {
        final authService = AuthService();
        final drawingResult = await authService.getDrawingList(documentId, 0);
        if (drawingResult.success && drawingResult.drawingList != null) {
          drawings = drawingResult.drawingList!.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('Error loading drawings for preview: $e');
      }

      return await _createTextPreviewImage(textContent, drawings);
    } catch (e) {
      debugPrint('Error creating digital page preview: $e');
      return _createEmptyPreview();
    }
  }

  /// Extract text content from Quill JSON
  String _extractTextFromQuillJson(dynamic quillJson) {
    if (quillJson == null) return '';

    try {
      String text = '';
      
      if (quillJson is String) {
        final parsed = jsonDecode(quillJson);
        text = _extractTextFromQuillOperations(parsed);
      } else if (quillJson is List) {
        text = _extractTextFromQuillOperations(quillJson);
      }

      return text.trim();
    } catch (e) {
      debugPrint('Error extracting text from Quill JSON: $e');
      return '';
    }
  }

  /// Extract text from Quill operations
  String _extractTextFromQuillOperations(dynamic operations) {
    if (operations is! List) return '';

    String text = '';
    
    for (final operation in operations) {
      if (operation is Map<String, dynamic>) {
        if (operation.containsKey('insert')) {
          final insert = operation['insert'];
          
          if (insert is String) {
            text += insert;
          } else if (insert is Map<String, dynamic>) {
            if (insert.containsKey('text')) {
              text += insert['text'] as String;
            } else if (insert.containsKey('image')) {
              text += '[Image]';
            } else if (insert.containsKey('formula')) {
              text += '[Formula]';
            }
          }
        }
      }
    }
    
    return text;
  }

  /// Create a preview image with text content and optional drawings
  Future<Uint8List> _createTextPreviewImage(String text, [List<Map<String, dynamic>>? drawings]) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Calculate scaling factors to fit document content in preview
    final scaleX = _previewWidth / _documentWidth;
    final scaleY = _previewHeight / _documentHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY; // Use smaller scale to fit both dimensions
    
    // Calculate actual content dimensions after scaling
    final scaledWidth = _documentWidth * scale;
    final scaledHeight = _documentHeight * scale;
    
    // Align left edge of document with left edge of preview
    final offsetX = 0.0; // No horizontal offset - align left edges
    final offsetY = (_previewHeight - scaledHeight) / 2; // Center vertically only
    
    // Draw background
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, _previewWidth, _previewHeight), backgroundPaint);
    
    // Apply scaling transformation
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);
    
    // Draw drawings first (behind text)
    if (drawings != null && drawings.isNotEmpty) {
      _drawDrawingPaths(canvas, drawings, _documentWidth, _documentHeight);
    }
    
    // Draw text content
    if (text.isNotEmpty) {
      // Scale font size to match the canvas scaling
      final scaledFontSize = _textFontSize / scale;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: scaledFontSize,
            color: Colors.black,
            height: _lineHeight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      
      textPainter.layout(maxWidth: _documentWidth - (_padding * 2));
      
      // Position text at the top-left with padding
      textPainter.paint(canvas, const Offset(_padding, _padding));
    } else if (drawings == null || drawings.isEmpty) {
      // Draw placeholder for empty document
      _drawEmptyDocumentPlaceholder(canvas, _documentWidth, _documentHeight);
    }
    
    canvas.restore();
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(_previewWidth.toInt(), _previewHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  /// Draw drawing paths on the canvas
  void _drawDrawingPaths(Canvas canvas, List<Map<String, dynamic>> drawings, double canvasWidth, double canvasHeight) {
    for (final drawingJson in drawings) {
      try {
        final pointsList = drawingJson['points'] as List<dynamic>?;
        if (pointsList == null || pointsList.isEmpty) continue;
        
        final points = pointsList.map((p) {
          final coords = p as List<dynamic>;
          // Use original coordinates since we're scaling the entire canvas
          final x = coords[0] as double;
          final y = coords[1] as double;
          return Offset(x, y);
        }).toList();
        
        // Filter out points that are outside the document bounds
        final visiblePoints = points.where((point) => 
          point.dx >= 0 && point.dx <= canvasWidth && 
          point.dy >= 0 && point.dy <= canvasHeight
        ).toList();
        
        if (visiblePoints.length < 2) continue;
        
        // Get color
        final colorMap = drawingJson['color'] as Map<String, dynamic>?;
        Color color = Colors.black;
        if (colorMap != null) {
          color = Color.fromARGB(
            255,
            colorMap['red'] as int? ?? 0,
            colorMap['green'] as int? ?? 0,
            colorMap['blue'] as int? ?? 0,
          );
        }
        
        // Get stroke width (use original size since canvas is scaled)
        final strokeWidth = (drawingJson['stroke_width'] as num?)?.toDouble() ?? 2.0;
        
        // Draw the path
        final paint = Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        
        for (int i = 0; i < visiblePoints.length - 1; i++) {
          canvas.drawLine(visiblePoints[i], visiblePoints[i + 1], paint);
        }
      } catch (e) {
        debugPrint('Error drawing path: $e');
      }
    }
  }

  /// Draw empty document placeholder
  void _drawEmptyDocumentPlaceholder(Canvas canvas, double width, double height) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Empty Document',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, height / 2));
  }

  /// Resize image for preview
  Future<Uint8List> _resizeImageForPreview(Uint8List imageBytes) async {
    try {
      // Decode the image to get its dimensions
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Calculate scaling to fit within preview bounds while maintaining aspect ratio
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();
      
      final scaleX = _previewWidth / imageWidth;
      final scaleY = _previewHeight / imageHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY; // Use smaller scale to fit both dimensions
      
      final targetWidth = (imageWidth * scale).round();
      final targetHeight = (imageHeight * scale).round();
      
      // Resize the image
      final resizedCodec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final resizedImage = resizedFrame.image;
      
      // Create a new image with the preview dimensions and center the resized image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw white background
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, _previewWidth, _previewHeight), backgroundPaint);
      
      // Center the resized image
      final offsetX = (_previewWidth - targetWidth) / 2;
      final offsetY = (_previewHeight - targetHeight) / 2;
      canvas.drawImage(resizedImage, Offset(offsetX, offsetY), Paint());
      
      // Convert to bytes
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(_previewWidth.toInt(), _previewHeight.toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return imageBytes;
    }
  }

  /// Create empty preview
  Future<Uint8List> _createEmptyPreview() async {
    return _createTextPreviewImage('');
  }

  /// Get cached preview
  Uint8List? getCachedPreview(String documentId) {
    return _previewCache[documentId];
  }

  /// Check if preview is cached
  bool isPreviewCached(String documentId) {
    return _previewCache.containsKey(documentId);
  }

  /// Mark a document as modified
  void markDocumentAsModified(String documentId) {
    _modifiedDocuments.add(documentId);
  }

  /// Get list of modified documents
  Set<String> getModifiedDocuments() {
    return Set.from(_modifiedDocuments);
  }

  /// Clear modified documents tracking
  void clearModifiedDocuments() {
    _modifiedDocuments.clear();
  }

  /// Invalidate preview for a specific document
  void invalidatePreview(String documentId) {
    _previewCache.remove(documentId);
  }

  /// Invalidate previews for modified documents only
  void invalidateModifiedPreviews() {
    for (final documentId in _modifiedDocuments) {
      _previewCache.remove(documentId);
    }
    _modifiedDocuments.clear();
  }

  /// Remove specific preview from cache
  void removeFromCache(String documentId) {
    _previewCache.remove(documentId);
  }

  /// Clear all cached previews
  void clearCache() {
    _previewCache.clear();
    _modifiedDocuments.clear();
  }
}