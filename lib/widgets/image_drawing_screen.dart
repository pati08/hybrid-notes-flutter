import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../auth_service.dart';
import '../models/document_page_data.dart';

class ImageDrawingScreen extends StatefulWidget {
  final DocumentPageData page;
  final String? documentId;
  final int? pageIndex;

  const ImageDrawingScreen({
    super.key,
    required this.page,
    this.documentId,
    this.pageIndex,
  });

  @override
  State<ImageDrawingScreen> createState() => _ImageDrawingScreenState();
}

class _ImageDrawingScreenState extends State<ImageDrawingScreen> {
  Color _selectedColor = Colors.red;
  // ignore: unused_field
  double _strokeWidth = 5.0;
  DrawingMode _mode = DrawingMode.draw;
  ui.Image? _backgroundImage;
  bool _isLoading = true;
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadBackground();
    _loadPaths();
    
    // Set initial scale to 90% centered after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final size = box.size;
          final scale = 0.9;
          final offsetX = (size.width * (1 - scale)) / 2;
          final offsetY = (size.height * (1 - scale)) / 2;
          _transformationController.value = Matrix4.identity()
            ..translate(offsetX, offsetY)
            ..scale(scale);
        }
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadBackground() async {
    if (widget.page.type == 'ImagePage' && widget.page.imageBytes != null) {
      // Load physical page image
      final codec = await ui.instantiateImageCodec(widget.page.imageBytes!);
      final frame = await codec.getNextFrame();
      setState(() {
        _backgroundImage = frame.image;
        _isLoading = false;
      });
    } else if (widget.page.type == 'DigitalPage') {
      // For digital pages, we don't need to load an image
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPaths() async {
    // Only load paths if we have documentId and pageIndex
    if (widget.documentId == null || widget.pageIndex == null) {
      return;
    }

    try {
      final authService = AuthService();
      final result = await authService.getDrawingList(
        widget.documentId!,
        widget.pageIndex!,
      );

      if (result.success && result.drawingList != null) {
        final loadedPaths = result.drawingList!
            .map((json) => DrawingPath.fromJson(json as Map<String, dynamic>))
            .toList();
        // TODO: Store and display loaded paths
        debugPrint('Loaded ${loadedPaths.length} drawing paths');
      }
    } catch (e) {
      debugPrint('Error loading paths: $e');
    }
  }

  void _undo() {
    // TODO: Implement undo functionality
    debugPrint('Undo not implemented');
  }

  void _redo() {
    // TODO: Implement redo functionality
    debugPrint('Redo not implemented');
  }

  void _clear() {
    // TODO: Implement clear functionality
    debugPrint('Clear not implemented');
  }

  Future<bool> _savePaths() async {
    // Only save paths if we have documentId and pageIndex
    if (widget.documentId == null || widget.pageIndex == null) {
      return true; // Not an error, just nothing to save
    }

    try {
      final authService = AuthService();
      // TODO: Collect actual drawing paths
      final pathsJson = <Map<String, dynamic>>[];
      
      final success = await authService.saveDrawingList(
        widget.documentId!,
        widget.pageIndex!,
        pathsJson,
      );

      return success;
    } catch (e) {
      debugPrint('Error saving paths: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Draw on Image'),
          backgroundColor: const Color(0xff102837),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw on Image'),
        backgroundColor: const Color(0xff102837),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xffc7ffbf)),
            onPressed: () async {
              final success = await _savePaths();
              if (success && context.mounted) {
                Navigator.pop(context, true);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.documentId == null || widget.pageIndex == null
                          ? 'Cannot save: missing document info'
                          : 'Failed to save drawing (API error - check logs)',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: _undo,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: _redo,
                    tooltip: 'Redo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clear,
                    tooltip: 'Clear All',
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: _mode == DrawingMode.draw ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.draw;
                      });
                    },
                    tooltip: 'Draw',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.cleaning_services,
                      color: _mode == DrawingMode.erase ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.erase;
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
                  _buildColorButton(Colors.white),
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
                      const PopupMenuItem(
                        value: 2.0,
                        child: Text('Thin'),
                      ),
                      const PopupMenuItem(
                        value: 5.0,
                        child: Text('Medium'),
                      ),
                      const PopupMenuItem(
                        value: 10.0,
                        child: Text('Thick'),
                      ),
                      const PopupMenuItem(
                        value: 20.0,
                        child: Text('Very Thick'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Drawing canvas with zoom capability
          Expanded(
            child: Container(
              color: widget.page.type == 'DigitalPage' 
                  ? const Color(0xfffafafa) 
                  : const Color(0xffe8e8e8), // Page background color
              child: Center(
                child: _TwoFingerInteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildDrawingCanvas(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingCanvas() {
    if (widget.page.type == 'DigitalPage') {
      // For digital pages, show the text editor as a non-interactive background
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Container(
              color: const Color(0xfffafafa),
              padding: const EdgeInsets.all(16.0),
              child: widget.page.controller != null
                  ? AbsorbPointer(
                      child: FleatherEditor(controller: widget.page.controller!),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      );
    } else {
      // For image pages, show image centered with shadow
      return LayoutBuilder(
        builder: (context, constraints) {
          if (_backgroundImage == null) {
            return const SizedBox.shrink();
          }
          
          // Calculate the size to fit the image while preserving aspect ratio
          final imageAspect = _backgroundImage!.width / _backgroundImage!.height;
          final availableWidth = constraints.maxWidth - 16; // Small padding
          final availableHeight = constraints.maxHeight - 16;
          
          double displayWidth, displayHeight;
          if (availableWidth / availableHeight > imageAspect) {
            // Height is the limiting factor
            displayHeight = availableHeight;
            displayWidth = displayHeight * imageAspect;
          } else {
            // Width is the limiting factor
            displayWidth = availableWidth;
            displayHeight = displayWidth / imageAspect;
          }
          
          final imageRect = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: displayWidth,
            height: displayHeight,
          );
          
          return CustomPaint(
            painter: _ImagePainter(
              image: _backgroundImage!,
              imageDisplayRect: imageRect,
            ),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          );
        },
      );
    }
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

  // Convert to API format
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

  // Create from API format
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

/// Simple painter that only draws the image (no drawing paths)
class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect imageDisplayRect;

  _ImagePainter({
    required this.image,
    required this.imageDisplayRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, srcRect, imageDisplayRect, Paint());
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) {
    return oldDelegate.image != image || 
           oldDelegate.imageDisplayRect != imageDisplayRect;
  }
}

/// Custom InteractiveViewer that only responds to two-finger gestures
/// This prevents conflicts with one-finger drawing gestures
class _TwoFingerInteractiveViewer extends StatefulWidget {
  final TransformationController transformationController;
  final double minScale;
  final double maxScale;
  final Widget child;

  const _TwoFingerInteractiveViewer({
    required this.transformationController,
    required this.minScale,
    required this.maxScale,
    required this.child,
  });

  @override
  State<_TwoFingerInteractiveViewer> createState() => _TwoFingerInteractiveViewerState();
}

class _TwoFingerInteractiveViewerState extends State<_TwoFingerInteractiveViewer> {
  int _pointerCount = 0;
  Offset? _initialFocalPoint;
  Matrix4? _initialTransform;

  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onTransformChanged);
    super.dispose();
  }

  void _onTransformChanged() {
    // Rebuild when transformation changes
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _initialFocalPoint = details.focalPoint;
    _initialTransform = widget.transformationController.value.clone();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Only respond to 2+ finger gestures
    if (_pointerCount < 2) {
      return; // Ignore one-finger gestures (reserved for drawing)
    }

    final matrix = Matrix4.identity();
    
    // Handle pinch zoom
    if (details.scale != 1.0) {
      final currentScale = widget.transformationController.value.getMaxScaleOnAxis();
      var newScale = (_initialTransform!.getMaxScaleOnAxis() * details.scale)
          .clamp(widget.minScale, widget.maxScale);
      
      // Calculate the scale relative to current
      final scaleChange = newScale / currentScale;
      
      // Get the focal point in the transformed coordinate space
      final focalPoint = details.localFocalPoint;
      
      // Apply zoom around the focal point
      matrix.translate(focalPoint.dx, focalPoint.dy);
      matrix.scale(scaleChange);
      matrix.translate(-focalPoint.dx, -focalPoint.dy);
      
      widget.transformationController.value = 
          widget.transformationController.value.clone()..multiply(matrix);
    }
    
    // Handle two-finger pan (when not zooming)
    else if (_pointerCount >= 2 && _initialFocalPoint != null) {
      final delta = details.focalPoint - _initialFocalPoint!;
      _initialFocalPoint = details.focalPoint;
      
      final currentTransform = widget.transformationController.value.clone();
      currentTransform.translate(delta.dx, delta.dy);
      widget.transformationController.value = currentTransform;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _pointerCount++;
        });
      },
      onPointerUp: (event) {
        setState(() {
          _pointerCount--;
          if (_pointerCount < 0) _pointerCount = 0;
        });
      },
      onPointerCancel: (event) {
        setState(() {
          _pointerCount--;
          if (_pointerCount < 0) _pointerCount = 0;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        child: Transform(
          transform: widget.transformationController.value,
          child: widget.child,
        ),
      ),
    );
  }
}
