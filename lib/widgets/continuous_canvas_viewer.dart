import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../models/document_page_data.dart';
import '../auth_service.dart';
import 'page_edit_screen.dart';

/// A continuous canvas viewer that displays all pages in a scrollable, zoomable canvas
/// Pages can be tapped to enter edit mode
class ContinuousCanvasViewer extends StatefulWidget {
  final List<DocumentPageData> pages;
  final String? documentId;
  final ValueNotifier<int> currentPageNotifier;

  const ContinuousCanvasViewer({
    super.key,
    required this.pages,
    this.documentId,
    required this.currentPageNotifier,
  });

  @override
  State<ContinuousCanvasViewer> createState() => _ContinuousCanvasViewerState();
}

class _ContinuousCanvasViewerState extends State<ContinuousCanvasViewer> {
  final TransformationController _transformationController = TransformationController();
  final double _pageWidth = 800.0; // Standard page width
  final double _pageSpacing = 40.0; // Spacing between pages
  final Map<int, double> _pageHeights = {}; // Cache calculated page heights
  int _refreshKey = 0; // Key to force rebuild of preview widgets
  
  // Drawing mode state
  bool _isDrawingMode = false;
  final Map<int, List<DrawingPath>> _pageDrawings = {}; // Drawings per page
  bool _isDrawing = false;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;
  DrawingMode _drawMode = DrawingMode.draw;
  
  @override
  void initState() {
    super.initState();
    
    // Pre-calculate page heights
    _calculatePageHeights();
    
    // Load all drawings
    _loadAllDrawings();
    
    // Set initial view to show first page centered and scaled to fit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnPage(0);
    });
  }
  
  Future<void> _loadAllDrawings() async {
    if (widget.documentId == null) return;
    
    for (int i = 0; i < widget.pages.length; i++) {
      try {
        final authService = AuthService();
        final result = await authService.getDrawingList(
          widget.documentId!,
          i,
        );

        if (result.success && result.drawingList != null) {
          final loadedPaths = result.drawingList!
              .map((json) => DrawingPath.fromJson(json as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _pageDrawings[i] = loadedPaths;
            });
          }
        }
      } catch (e) {
        // Silently fail
      }
    }
  }
  
  Future<void> _saveDrawingsForPage(int pageIndex) async {
    if (widget.documentId == null) return;
    
    try {
      final authService = AuthService();
      final paths = _pageDrawings[pageIndex] ?? [];
      final pathsJson = paths.map((path) => path.toJson()).toList();
      
      await authService.saveDrawingList(
        widget.documentId!,
        pageIndex,
        pathsJson,
      );
    } catch (e) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _calculatePageHeights() {
    for (int i = 0; i < widget.pages.length; i++) {
      _pageHeights[i] = _calculatePageHeight(i);
    }
  }

  double _calculatePageHeight(int index) {
    if (index >= widget.pages.length) return 1000.0;
    
    final page = widget.pages[index];
    if (page.type == 'ImagePage' && page.imageBytes != null) {
      // For image pages, we need to decode the image to get its aspect ratio
      // This is done asynchronously in the preview widget
      // For now, return a reasonable default
      return _pageWidth * 1.4;
    } else {
      // Digital pages: use a standard height similar to A4
      return _pageWidth * 1.294; // A4 aspect ratio (210mm x 297mm)
    }
  }

  double _getPageHeight(int index) {
    return _pageHeights[index] ?? _calculatePageHeight(index);
  }

  void updatePageHeight(int index, double height) {
    if (mounted) {
      setState(() {
        _pageHeights[index] = height;
      });
    }
  }

  void _centerOnPage(int pageIndex) {
    if (!mounted) return;
    
    final context = this.context;
    final size = MediaQuery.of(context).size;
    
    // Calculate page position
    double pageY = _pageSpacing;
    for (int i = 0; i < pageIndex; i++) {
      pageY += _getPageHeight(i) + _pageSpacing;
    }
    
    // Calculate scale to fit page width
    final scale = (size.width * 0.9) / _pageWidth;
    
    // Center the page
    final offsetX = (size.width - _pageWidth * scale) / 2;
    final offsetY = (size.height / 2) - (pageY * scale) - (_getPageHeight(pageIndex) * scale / 2);
    
    _transformationController.value = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale);
  }

  void _handlePageTap(int pageIndex) async {
    // Don't navigate when in drawing mode
    if (_isDrawingMode) return;
    
    // Navigate to edit screen for the page (for typing on digital pages)
    widget.currentPageNotifier.value = pageIndex;
    
    final page = widget.pages[pageIndex];
    
    // Only allow editing digital pages (for typing)
    if (page.type != 'DigitalPage' || page.controller == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageEditScreen(
          page: page,
          documentId: widget.documentId,
          pageIndex: pageIndex,
        ),
      ),
    );
    
    // Refresh the page preview after editing
    if (result == true && mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffa0a0a0),
      body: Stack(
        children: [
          // Canvas with InteractiveViewer
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(200),
              constrained: false,
              panEnabled: !_isDrawingMode, // Disable panning in drawing mode
              scaleEnabled: !_isDrawingMode, // Disable zooming in drawing mode
              child: _buildCanvas(),
            ),
          ),
          
          // Drawing toolbar (when in drawing mode)
          if (_isDrawingMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildDrawingToolbar(),
            ),
            
          // Drawing mode toggle button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                if (_isDrawingMode) {
                  // Save all modified pages before exiting drawing mode
                  for (var pageIndex in _pageDrawings.keys) {
                    await _saveDrawingsForPage(pageIndex);
                  }
                }
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
              },
              backgroundColor: _isDrawingMode ? const Color(0xffbd6051) : const Color(0xff102837),
              child: Icon(
                _isDrawingMode ? Icons.check : Icons.draw,
                color: _isDrawingMode ? Colors.white : const Color(0xffc7ffbf),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.edit,
                color: _drawMode == DrawingMode.draw ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() {
                  _drawMode = DrawingMode.draw;
                });
              },
              tooltip: 'Draw',
            ),
            IconButton(
              icon: Icon(
                Icons.cleaning_services,
                color: _drawMode == DrawingMode.erase ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() {
                  _drawMode = DrawingMode.erase;
                });
              },
              tooltip: 'Eraser',
            ),
            const VerticalDivider(),
            // Color picker
            _buildColorButton(Colors.red),
            _buildColorButton(Colors.blue),
            _buildColorButton(Colors.green),
            _buildColorButton(Colors.yellow),
            _buildColorButton(Colors.orange),
            _buildColorButton(Colors.purple),
            _buildColorButton(Colors.black),
            const VerticalDivider(),
            // Stroke width
            PopupMenuButton<double>(
              icon: const Icon(Icons.line_weight),
              tooltip: 'Stroke Width',
              onSelected: (value) {
                setState(() {
                  _strokeWidth = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 2.0, child: Text('Thin')),
                const PopupMenuItem(value: 5.0, child: Text('Medium')),
                const PopupMenuItem(value: 10.0, child: Text('Thick')),
                const PopupMenuItem(value: 20.0, child: Text('Very Thick')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedColor = color;
          });
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[400]!,
              width: isSelected ? 3 : 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    // Calculate total canvas size
    double totalHeight = 0;
    for (int i = 0; i < widget.pages.length; i++) {
      totalHeight += _getPageHeight(i) + _pageSpacing;
    }
    totalHeight += _pageSpacing; // Extra spacing at the end
    
    final canvasWidth = _pageWidth + _pageSpacing * 2;
    
    return SizedBox(
      width: canvasWidth,
      height: totalHeight,
      child: Stack(
        children: [
          // Render each page
          for (int i = 0; i < widget.pages.length; i++)
            _buildPage(i),
            
          // Drawing layer (when in drawing mode)
          if (_isDrawingMode)
            Positioned.fill(
              child: _buildDrawingLayer(Size(canvasWidth, totalHeight)),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDrawingLayer(Size canvasSize) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (details) {
        setState(() {
          _isDrawing = true;
          if (_drawMode == DrawingMode.erase) {
            return;
          }
          
          // Determine which page this point belongs to
          final pageIndex = _getPageIndexAtPoint(details.localPosition);
          if (pageIndex != null) {
            _pageDrawings[pageIndex] ??= [];
            _pageDrawings[pageIndex]!.add(DrawingPath(
              points: [details.localPosition],
              color: _selectedColor,
              strokeWidth: _strokeWidth,
            ));
          }
        });
      },
      onPointerMove: (details) {
        if (_isDrawing) {
          setState(() {
            if (_drawMode == DrawingMode.erase) {
              // Erase paths that are touched
              for (var pageIndex in _pageDrawings.keys) {
                _pageDrawings[pageIndex]!.removeWhere((path) {
                  for (final point in path.points) {
                    if ((point - details.localPosition).distance < path.strokeWidth * 2) {
                      return true;
                    }
                  }
                  return false;
                });
              }
            } else {
              // Add point to current path
              final pageIndex = _getPageIndexAtPoint(details.localPosition);
              if (pageIndex != null && _pageDrawings[pageIndex] != null && _pageDrawings[pageIndex]!.isNotEmpty) {
                final currentPath = _pageDrawings[pageIndex]!.last;
                final updatedPoints = List<Offset>.from(currentPath.points)
                  ..add(details.localPosition);
                _pageDrawings[pageIndex]![_pageDrawings[pageIndex]!.length - 1] = DrawingPath(
                  points: updatedPoints,
                  color: currentPath.color,
                  strokeWidth: currentPath.strokeWidth,
                );
              }
            }
          });
        }
      },
      onPointerUp: (details) {
        setState(() {
          _isDrawing = false;
        });
      },
      onPointerCancel: (details) {
        setState(() {
          _isDrawing = false;
        });
      },
      child: CustomPaint(
        painter: _AllDrawingsPainter(
          pageDrawings: _pageDrawings,
        ),
        size: canvasSize,
      ),
    );
  }
  
  int? _getPageIndexAtPoint(Offset point) {
    double currentY = _pageSpacing;
    
    for (int i = 0; i < widget.pages.length; i++) {
      final pageHeight = _getPageHeight(i);
      final pageTop = currentY;
      final pageBottom = currentY + pageHeight;
      
      final pageLeft = _pageSpacing;
      final pageRight = _pageSpacing + _pageWidth;
      
      // Check if point is within this page's bounds (both X and Y)
      if (point.dy >= pageTop && point.dy <= pageBottom &&
          point.dx >= pageLeft && point.dx <= pageRight) {
        return i;
      }
      
      currentY += pageHeight + _pageSpacing;
    }
    
    // Point is outside all pages - don't allow drawing
    return null;
  }

  Widget _buildPage(int index) {
    double yOffset = _pageSpacing;
    for (int i = 0; i < index; i++) {
      yOffset += _getPageHeight(i) + _pageSpacing;
    }
    
    final page = widget.pages[index];
    final pageHeight = _getPageHeight(index);
    
    return Positioned(
      left: _pageSpacing,
      top: yOffset,
      width: _pageWidth,
      height: pageHeight,
      child: GestureDetector(
        onTap: () => _handlePageTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Page content with padding for image pages
              Positioned.fill(
                child: page.type == 'ImagePage'
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildPageContent(page, index),
                      )
                    : _buildPageContent(page, index),
              ),
              // Page number indicator
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Page ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // Tap indicator overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handlePageTap(index),
                    splashColor: const Color(0xffc7ffbf).withOpacity(0.3),
                    highlightColor: const Color(0xffc7ffbf).withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(DocumentPageData page, int index) {
    if (page.type == 'DigitalPage' && page.controller != null) {
      return _DigitalPagePreview(
        key: ValueKey('digital_$index\_$_refreshKey'),
        controller: page.controller!,
        paths: _pageDrawings[index] ?? [],
      );
    } else if (page.type == 'ImagePage' && page.imageBytes != null) {
      return _ImagePagePreview(
        key: ValueKey('image_$index\_$_refreshKey'),
        imageBytes: page.imageBytes!,
        paths: _pageDrawings[index] ?? [],
        onImageLoaded: (aspectRatio) {
          // Update page height based on actual image aspect ratio
          final newHeight = _pageWidth / aspectRatio;
          if (_pageHeights[index] != newHeight) {
            updatePageHeight(index, newHeight);
          }
        },
      );
    } else {
      return const Center(
        child: Text('Unknown page type'),
      );
    }
  }
}

/// Preview of a digital page (non-interactive)
class _DigitalPagePreview extends StatelessWidget {
  final FleatherController controller;
  final List<DrawingPath> paths;

  const _DigitalPagePreview({
    super.key,
    required this.controller,
    required this.paths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfffafafa),
      child: Stack(
        children: [
          // Text editor (non-interactive)
          Positioned.fill(
            child: AbsorbPointer(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FleatherEditor(controller: controller),
              ),
            ),
          ),
          // Drawing paths overlay (non-interactive)
          if (paths.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PathsPainter(paths: paths),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Preview of an image page (non-interactive)
class _ImagePagePreview extends StatefulWidget {
  final List<int> imageBytes;
  final List<DrawingPath> paths;
  final Function(double aspectRatio)? onImageLoaded;

  const _ImagePagePreview({
    super.key,
    required this.imageBytes,
    required this.paths,
    this.onImageLoaded,
  });

  @override
  State<_ImagePagePreview> createState() => _ImagePagePreviewState();
}

class _ImagePagePreviewState extends State<_ImagePagePreview> {
  ui.Image? _image;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final Uint8List bytes = widget.imageBytes is Uint8List 
          ? widget.imageBytes as Uint8List
          : Uint8List.fromList(widget.imageBytes);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frame.image;
          _isLoading = false;
        });
        
        // Notify parent of the image aspect ratio
        if (widget.onImageLoaded != null && _image != null) {
          final aspectRatio = _image!.width / _image!.height;
          widget.onImageLoaded!(aspectRatio);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_image == null) {
      return const Center(
        child: Text('Failed to load image'),
      );
    }

    // The parent adds 16px padding, but we need the FULL size for coordinate matching
    // Use a negative margin to expand back to full size
    return Transform.translate(
      offset: const Offset(-16, -16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Add back the padding we negated to get the full canvas size
          final fullWidth = constraints.maxWidth + 32; // 16px on each side
          final fullHeight = constraints.maxHeight + 32;
          
          return CustomPaint(
            painter: _ImageWithPathsPainter(
              image: _image!,
              paths: widget.paths,
              containerSize: Size(fullWidth, fullHeight),
              padding: 16.0,
            ),
            size: Size(fullWidth, fullHeight),
          );
        },
      ),
    );
  }
}

/// Custom painter for drawing paths only
class _PathsPainter extends CustomPainter {
  final List<DrawingPath> paths;

  _PathsPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PathsPainter oldDelegate) {
    return oldDelegate.paths.length != paths.length;
  }
}

/// Custom painter for image with paths overlay
class _ImageWithPathsPainter extends CustomPainter {
  final ui.Image image;
  final List<DrawingPath> paths;
  final Size containerSize;
  final double padding;

  _ImageWithPathsPainter({
    required this.image,
    required this.paths,
    required this.containerSize,
    this.padding = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate available space for image (accounting for padding)
    final availableWidth = containerSize.width - (padding * 2);
    final availableHeight = containerSize.height - (padding * 2);
    
    final imageAspect = image.width / image.height;
    final availableAspect = availableWidth / availableHeight;
    
    // Calculate image display rect with padding
    Rect dstRect;
    if (availableAspect > imageAspect) {
      // Available space is wider - fit to height
      final scaledWidth = availableHeight * imageAspect;
      final offsetX = padding + (availableWidth - scaledWidth) / 2;
      dstRect = Rect.fromLTWH(offsetX, padding, scaledWidth, availableHeight);
    } else {
      // Available space is taller - fit to width
      final scaledHeight = availableWidth / imageAspect;
      final offsetY = padding + (availableHeight - scaledHeight) / 2;
      dstRect = Rect.fromLTWH(padding, offsetY, availableWidth, scaledHeight);
    }
    
    // Draw image with shadow effect
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(dstRect.shift(const Offset(0, 4)), shadowPaint);
    
    // Draw image maintaining aspect ratio
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, srcRect, dstRect, Paint());

    // Draw paths - they're stored in full canvas coordinates from the drawing screen
    // Just draw them directly
    for (final path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ImageWithPathsPainter oldDelegate) {
    return oldDelegate.image != image || 
           oldDelegate.paths.length != paths.length ||
           oldDelegate.containerSize != containerSize ||
           oldDelegate.padding != padding;
  }
}

/// Custom painter that draws all paths from all pages
class _AllDrawingsPainter extends CustomPainter {
  final Map<int, List<DrawingPath>> pageDrawings;

  _AllDrawingsPainter({
    required this.pageDrawings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all paths from all pages
    for (final paths in pageDrawings.values) {
      for (final path in paths) {
        if (path.points.isEmpty) continue;

        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < path.points.length - 1; i++) {
          canvas.drawLine(path.points[i], path.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AllDrawingsPainter oldDelegate) {
    // Simple check - repaint if any page has different number of paths
    if (oldDelegate.pageDrawings.length != pageDrawings.length) return true;
    for (var key in pageDrawings.keys) {
      if (!oldDelegate.pageDrawings.containsKey(key)) return true;
      if (oldDelegate.pageDrawings[key]!.length != pageDrawings[key]!.length) return true;
    }
    return false;
  }
}

enum DrawingMode {
  draw,
  erase,
}

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      'color': {
        'red': ((color.r * 255.0).round() & 0xff),
        'green': ((color.g * 255.0).round() & 0xff),
        'blue': ((color.b * 255.0).round() & 0xff),
      },
      'stroke_width': strokeWidth,
    };
  }

  factory DrawingPath.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'] as List<dynamic>;
    final points = pointsList.map((p) {
      final coords = p as List<dynamic>;
      return Offset(coords[0] as double, coords[1] as double);
    }).toList();

    final colorMap = json['color'] as Map<String, dynamic>;
    final color = Color.fromARGB(
      255,
      colorMap['red'] as int,
      colorMap['green'] as int,
      colorMap['blue'] as int,
    );

    return DrawingPath(
      points: points,
      color: color,
      strokeWidth: (json['stroke_width'] as num).toDouble(),
    );
  }
}
