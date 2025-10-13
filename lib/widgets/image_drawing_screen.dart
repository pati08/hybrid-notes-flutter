import 'dart:math' as math;
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
  double _strokeWidth = 5.0;
  DrawingMode _mode = DrawingMode.draw;
  ui.Image? _backgroundImage;
  bool _isLoading = true;
  late final TransformationController _transformationController;

  // Drawing state
  final List<DrawingPath> _paths = [];
  DrawingPath? _currentPath;

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
          const scale = 0.9;
          final offsetX = (size.width * (1 - scale)) / 2;
          final offsetY = (size.height * (1 - scale)) / 2;
          _transformationController.value = Matrix4.identity()
            ..translateByDouble(offsetX, offsetY, 0.0, 0.0)
            ..scaleByDouble(scale, 1.0, 1.0, 1.0);
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
        if (mounted) {
          setState(() {
            _paths
              ..clear()
              ..addAll(loadedPaths);
          });
        }
      }
    } catch (e) {
      // Error loading paths
    }
  }

  void _undo() {
    debugPrint('UNDO: Undo button pressed');
    debugPrint('UNDO: Current paths count: ${_paths.length}');
  }

  void _redo() {
    debugPrint('REDO: Redo button pressed');
    debugPrint('REDO: Current paths count: ${_paths.length}');
  }

  void _clear() {
    if (_paths.isEmpty) {
      return;
    }

    setState(() {
      _paths.clear();
      _currentPath = null;
    });
  }

  void _erasePaths(DrawingPath eraserPath) {
    final eraserPoints = eraserPath.points;
    
    // Remove paths that intersect with the eraser
    _paths.removeWhere((path) {
      if (path.points.isEmpty || eraserPoints.isEmpty) {
        return false;
      }

      final tolerance = math.max(path.strokeWidth, eraserPath.strokeWidth);

      // Quick point proximity check (covers dots and very short segments)
      for (final pathPoint in path.points) {
        for (final eraserPoint in eraserPoints) {
          if ((pathPoint - eraserPoint).distance <= tolerance) {
            return true;
          }
        }
      }

      // Handle single-point eraser paths against drawn segments
      if (eraserPoints.length == 1 && path.points.length > 1) {
        final eraserPoint = eraserPoints.first;
        for (int i = 0; i < path.points.length - 1; i++) {
          final segmentStart = path.points[i];
          final segmentEnd = path.points[i + 1];
          if (_distancePointToSegment(eraserPoint, segmentStart, segmentEnd) <= tolerance) {
            return true;
          }
        }
      }

      // Handle single-point drawing paths against eraser segments
      if (path.points.length == 1 && eraserPoints.length > 1) {
        final pathPoint = path.points.first;
        for (int i = 0; i < eraserPoints.length - 1; i++) {
          final eraserStart = eraserPoints[i];
          final eraserEnd = eraserPoints[i + 1];
          if (_distancePointToSegment(pathPoint, eraserStart, eraserEnd) <= tolerance) {
            return true;
          }
        }
      }

      // Check for segment proximity/intersection between the drawing and eraser paths
      if (path.points.length > 1 && eraserPoints.length > 1) {
        for (int i = 0; i < path.points.length - 1; i++) {
          final pathStart = path.points[i];
          final pathEnd = path.points[i + 1];
          for (int j = 0; j < eraserPoints.length - 1; j++) {
            final eraserStart = eraserPoints[j];
            final eraserEnd = eraserPoints[j + 1];
            if (_distanceBetweenSegments(pathStart, pathEnd, eraserStart, eraserEnd) <= tolerance) {
              return true;
            }
          }
        }
      }

      return false;
    });
  }

  double _distancePointToSegment(Offset point, Offset segmentStart, Offset segmentEnd) {
    final segment = segmentEnd - segmentStart;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;

    if (lengthSquared == 0.0) {
      return (point - segmentStart).distance;
    }

    final t = ((point.dx - segmentStart.dx) * segment.dx +
            (point.dy - segmentStart.dy) * segment.dy) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0) as double;
    final projection = Offset(
      segmentStart.dx + clampedT * segment.dx,
      segmentStart.dy + clampedT * segment.dy,
    );

    return (point - projection).distance;
  }

  double _distanceBetweenSegments(
    Offset p1,
    Offset p2,
    Offset q1,
    Offset q2,
  ) {
    if (_segmentsIntersect(p1, p2, q1, q2)) {
      return 0.0;
    }

    final distances = [
      _distancePointToSegment(p1, q1, q2),
      _distancePointToSegment(p2, q1, q2),
      _distancePointToSegment(q1, p1, p2),
      _distancePointToSegment(q2, p1, p2),
    ];

    return distances.reduce(math.min);
  }

  bool _segmentsIntersect(Offset p1, Offset p2, Offset q1, Offset q2) {
    const double epsilon = 1e-6;

    final o1 = _orientation(p1, p2, q1);
    final o2 = _orientation(p1, p2, q2);
    final o3 = _orientation(q1, q2, p1);
    final o4 = _orientation(q1, q2, p2);

    if ((o1 * o2) < 0 && (o3 * o4) < 0) {
      return true;
    }

    if (o1.abs() < epsilon && _onSegment(p1, q1, p2)) return true;
    if (o2.abs() < epsilon && _onSegment(p1, q2, p2)) return true;
    if (o3.abs() < epsilon && _onSegment(q1, p1, q2)) return true;
    if (o4.abs() < epsilon && _onSegment(q1, p2, q2)) return true;

    return false;
  }

  double _orientation(Offset a, Offset b, Offset c) {
    final cross = (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    return cross;
  }

  bool _onSegment(Offset a, Offset b, Offset c) {
    return b.dx <= math.max(a.dx, c.dx) + 1e-6 &&
        b.dx >= math.min(a.dx, c.dx) - 1e-6 &&
        b.dy <= math.max(a.dy, c.dy) + 1e-6 &&
        b.dy >= math.min(a.dy, c.dy) - 1e-6;
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
    } catch (e) {
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
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                final localPosition = renderBox.globalToLocal(details.globalPosition);
                setState(() {
                  _currentPath = DrawingPath(
                    points: [localPosition],
                    color: _mode == DrawingMode.erase ? Colors.transparent : _selectedColor,
                    strokeWidth: _strokeWidth,
                    mode: _mode,
                  );
                });
              },
              onPanUpdate: (details) {
                if (_currentPath == null) return;

                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                final localPosition = renderBox.globalToLocal(details.globalPosition);
                setState(() {
                  // Add adaptive point sampling to reduce segmentation
                  final currentPoints = _currentPath!.points;
                  if (currentPoints.isNotEmpty) {
                    final lastPoint = currentPoints.last;
                    final distance = (localPosition - lastPoint).distance;
                    
                    // Only add point if it's far enough from the last point
                    // This reduces segmentation during fast strokes
                    if (distance > 2.0) {
                      _currentPath = _currentPath!.copyWith(
                        points: [...currentPoints, localPosition],
                      );
                    }
                  } else {
                    // First point - always add it
                    _currentPath = _currentPath!.copyWith(
                      points: [localPosition],
                    );
                  }
                });
              },
              onPanEnd: (details) {
                if (_currentPath == null) return;

                setState(() {
                  if (_currentPath!.mode == DrawingMode.erase) {
                    _erasePaths(_currentPath!);
                  } else {
                    _paths.add(_currentPath!);
                  }
                  _currentPath = null;
                });
              },
              child: Container(
                color: widget.page.type == 'DigitalPage'
                    ? const Color(0xfffafafa)
                    : const Color(0xffe8e8e8),
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
                  ? Stack(
                      children: [
                        AbsorbPointer(
                          child: FleatherEditor(
                            controller: widget.page.controller!,
                          ),
                        ),
                        if (_paths.isNotEmpty || _currentPath != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PathPainter(
                                paths: _paths,
                                inProgressPath: _currentPath,
                              ),
                            ),
                          ),
                      ],
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
          final imageAspect =
              _backgroundImage!.width / _backgroundImage!.height;
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
            foregroundPainter: (_paths.isNotEmpty || _currentPath != null)
                ? _PathPainter(
                    paths: _paths,
                    inProgressPath: _currentPath,
                  )
                : null,
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
  final DrawingMode mode;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.mode,
  });

  DrawingPath copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    DrawingMode? mode,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      mode: mode ?? this.mode,
    );
  }

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
      mode: DrawingMode.draw, // Default to draw mode for loaded paths
    );
  }
}

/// Custom painter for drawing paths
class _PathPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? inProgressPath;

  _PathPainter({
    required this.paths,
    this.inProgressPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths
    for (final path in paths) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (path.points.isNotEmpty) {
        final drawPath = _createSmoothPath(path.points);
        canvas.drawPath(drawPath, paint);
      }
    }

    // Draw in-progress path
    if (inProgressPath != null) {
      final paint = Paint()
        ..color = inProgressPath!.color
        ..strokeWidth = inProgressPath!.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (inProgressPath!.points.isNotEmpty) {
        final drawPath = _createSmoothPath(inProgressPath!.points);
        canvas.drawPath(drawPath, paint);
      }
    }
  }

  /// Creates a smooth path using quadratic Bezier curves
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    
    if (points.isEmpty) return path;
    
    if (points.length == 1) {
      // Single point - draw a small circle
      path.addOval(Rect.fromCircle(center: points[0], radius: 1.0));
      return path;
    }
    
    if (points.length == 2) {
      // Two points - draw a straight line
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }
    
    // Three or more points - use quadratic Bezier curves for smoothness
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      
      // Calculate control point for smooth curve
      final controlPoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      
      path.quadraticBezierTo(
        current.dx, current.dy,
        controlPoint.dx, controlPoint.dy,
      );
    }
    
    // Draw to the last point
    final lastPoint = points.last;
    path.lineTo(lastPoint.dx, lastPoint.dy);
    
    return path;
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) {
    return oldDelegate.paths.length != paths.length ||
        oldDelegate.inProgressPath != inProgressPath ||
        !identical(oldDelegate.paths, paths);
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
  State<_TwoFingerInteractiveViewer> createState() =>
      _TwoFingerInteractiveViewerState();
}

class _TwoFingerInteractiveViewerState
    extends State<_TwoFingerInteractiveViewer> {
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
      final currentScale =
          widget.transformationController.value.getMaxScaleOnAxis();
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
