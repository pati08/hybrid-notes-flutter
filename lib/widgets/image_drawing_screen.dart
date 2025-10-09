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
  final List<DrawingPath> _paths = [];
  final List<DrawingPath> _undoPaths = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;
  DrawingMode _mode = DrawingMode.draw;
  ui.Image? _backgroundImage;
  bool _isLoading = true;
  bool _isDrawing = false;
  final GlobalKey _repaintKey = GlobalKey();
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
        setState(() {
          _paths.clear();
          _paths.addAll(loadedPaths);
        });
      }
    } catch (e) {
    }
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _undoPaths.add(_paths.removeLast());
      });
    }
  }

  void _redo() {
    if (_undoPaths.isNotEmpty) {
      setState(() {
        _paths.add(_undoPaths.removeLast());
      });
    }
  }

  void _clear() {
    setState(() {
      _paths.clear();
      _undoPaths.clear();
    });
  }

  Future<bool> _savePaths() async {
    // Only save paths if we have documentId and pageIndex
    if (widget.documentId == null || widget.pageIndex == null) {
      return true; // Not an error, just nothing to save
    }

    try {
      final authService = AuthService();
      final pathsJson = _paths.map((path) => path.toJson()).toList();
      
      final success = await authService.saveDrawingList(
        widget.documentId!,
        widget.pageIndex!,
        pathsJson,
      );

      return success;
    } catch (e, stackTrace) {
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
                    onPressed: _paths.isNotEmpty ? _undo : null,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: _undoPaths.isNotEmpty ? _redo : null,
                    tooltip: 'Redo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _paths.isNotEmpty ? _clear : null,
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
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _buildDrawingCanvas(),
                  ),
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
            child: Stack(
              children: [
                // Non-interactive layer showing the digital content
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: const Color(0xfffafafa),
                      padding: const EdgeInsets.all(16.0),
                      child: widget.page.controller != null
                          ? FleatherEditor(controller: widget.page.controller!)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Interactive drawing layer on top
                Positioned.fill(
                  child: _buildInteractiveDrawingLayer(
                    Size(constraints.maxWidth, constraints.maxHeight),
                    null,
                    imageDisplayRect: null,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // For image pages, allow drawing beyond image bounds while showing image centered with shadow
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
          
          // Use a stack to layer the shadow box and the full-size drawing canvas
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Centered shadow box showing the image bounds (non-interactive)
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: displayWidth,
                      height: displayHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Full-size interactive drawing layer
                _buildInteractiveDrawingLayer(
                  Size(constraints.maxWidth, constraints.maxHeight),
                  _backgroundImage,
                  imageDisplayRect: Rect.fromCenter(
                    center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
                    width: displayWidth,
                    height: displayHeight,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildInteractiveDrawingLayer(Size size, ui.Image? image, {Rect? imageDisplayRect}) {
    return Listener(
      onPointerDown: (details) {
        setState(() {
          _isDrawing = true;
          _undoPaths.clear();
          if (_mode == DrawingMode.erase) {
            return;
          }
          final newPath = DrawingPath(
            points: [details.localPosition],
            color: _mode == DrawingMode.erase
                ? Colors.transparent
                : _selectedColor,
            strokeWidth: _strokeWidth,
          );
          _paths.add(newPath);
        });
      },
      onPointerMove: (details) {
        if (_isDrawing) {
          setState(() {
            if (_mode == DrawingMode.erase) {
              // In erase mode, remove paths that are touched
              _paths.removeWhere((path) {
                // Check if eraser point is near any point in this path
                for (final point in path.points) {
                  final distance =
                      (point - details.localPosition).distance;
                  if (distance < path.strokeWidth * 2) {
                    return true; // Remove this path
                  }
                }
                return false; // Keep this path
              });
            } else if (_paths.isNotEmpty) {
              // In draw mode, add points to current path
              final currentPath = _paths.last;
              final updatedPoints =
                  List<Offset>.from(currentPath.points)
                    ..add(details.localPosition);
              _paths[_paths.length - 1] = DrawingPath(
                points: updatedPoints,
                color: currentPath.color,
                strokeWidth: currentPath.strokeWidth,
              );
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
        painter: DrawingPainter(
          backgroundImage: image,
          paths: List<DrawingPath>.from(_paths),
          imageDisplayRect: imageDisplayRect,
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
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

class DrawingPainter extends CustomPainter {
  final ui.Image? backgroundImage;
  final List<DrawingPath> paths;
  final Rect? imageDisplayRect;

  DrawingPainter({
    this.backgroundImage,
    required this.paths,
    this.imageDisplayRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background image in the specified display rect (or fill canvas if no rect specified)
    if (backgroundImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        backgroundImage!.width.toDouble(),
        backgroundImage!.height.toDouble(),
      );
      
      final dstRect = imageDisplayRect ?? Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(backgroundImage!, srcRect, dstRect, Paint());
    }

    // Create a separate layer for drawings so eraser doesn't affect background
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw all paths
    for (int pathIndex = 0; pathIndex < paths.length; pathIndex++) {
      final path = paths[pathIndex];

      if (path.points.isEmpty) {
        continue;
      }

      final paint = Paint()
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      paint.color = path.color;

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }

    // Restore the layer
    canvas.restore();
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    // Always repaint when paths or background changes
    // We need to check the actual content, not just reference equality
    if (oldDelegate.backgroundImage != backgroundImage) return true;
    if (oldDelegate.paths.length != paths.length) return true;

    // Check if any path has changed
    for (int i = 0; i < paths.length; i++) {
      if (oldDelegate.paths[i].points.length != paths[i].points.length) {
        return true;
      }
    }

    return false;
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
