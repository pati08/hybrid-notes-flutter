import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../auth_service.dart';
import '../models/document_page_data.dart';
import '../services/document_preview_service.dart';

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

  // Undo/redo stacks — each entry is a snapshot of _paths
  final List<List<DrawingPath>> _undoStack = [];
  final List<List<DrawingPath>> _redoStack = [];

  // Shape drawing state
  Offset? _shapeStartPoint;
  Offset? _shapeCurrentPoint;

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
      try {
        final codec = await ui.instantiateImageCodec(widget.page.imageBytes!);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _backgroundImage = frame.image;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (widget.page.type == 'DigitalPage') {
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
      debugPrint('Error loading drawing paths: $e');
    }
  }

  void _saveToHistory() {
    _undoStack.add(List.from(_paths));
    _redoStack.clear();
    // Cap history at 50 states to limit memory usage
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.from(_paths));
    setState(() {
      _paths
        ..clear()
        ..addAll(_undoStack.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.from(_paths));
    setState(() {
      _paths
        ..clear()
        ..addAll(_redoStack.removeLast());
    });
  }

  void _clear() {
    if (_paths.isEmpty) return;
    _saveToHistory();
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

      // Make erasing more forgiving by increasing tolerance
      final baseTolerance = math.max(path.strokeWidth, eraserPath.strokeWidth);
      // Adjust tolerance based on zoom level - smaller tolerance when zoomed in
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      final zoomFactor = math.max(0.5, 1.0 / currentScale); // Invert scale, clamp to reasonable range
      final tolerance = baseTolerance * 3.0 * zoomFactor; // Zoom-aware tolerance

      // For shapes (squares, circles, lines), use bounding box collision
      if (path.pathType == PathType.square || path.pathType == PathType.circle || path.pathType == PathType.line) {
        if (path.startPoint != null && path.endPoint != null) {
          // Create bounding box for the shape
          final shapeBounds = _getShapeBounds(path);
          if (shapeBounds != null) {
            // Check if any eraser point is within the shape's bounding box (with tolerance)
            for (final eraserPoint in eraserPoints) {
              if (_isPointInBounds(eraserPoint, shapeBounds, tolerance)) {
                return true;
              }
            }
          }
        }
      }

      // For freehand paths, use the improved point-based detection
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

  // Get bounding box for shapes
  Rect? _getShapeBounds(DrawingPath path) {
    if (path.startPoint == null || path.endPoint == null) return null;
    
    final start = path.startPoint!;
    final end = path.endPoint!;
    final strokeWidth = path.strokeWidth;
    
    // Add stroke width padding to the bounds
    final padding = strokeWidth / 2;
    
    switch (path.pathType) {
      case PathType.square:
        return Rect.fromPoints(
          Offset(math.min(start.dx, end.dx) - padding, math.min(start.dy, end.dy) - padding),
          Offset(math.max(start.dx, end.dx) + padding, math.max(start.dy, end.dy) + padding),
        );
      case PathType.circle:
        final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        final radius = (end - start).distance / 2 + padding;
        return Rect.fromCircle(center: center, radius: radius);
      case PathType.line:
        return Rect.fromPoints(
          Offset(math.min(start.dx, end.dx) - padding, math.min(start.dy, end.dy) - padding),
          Offset(math.max(start.dx, end.dx) + padding, math.max(start.dy, end.dy) + padding),
        );
      default:
        return null;
    }
  }

  // Check if a point is within bounds with tolerance
  bool _isPointInBounds(Offset point, Rect bounds, double tolerance) {
    final expandedBounds = Rect.fromLTRB(
      bounds.left - tolerance,
      bounds.top - tolerance,
      bounds.right + tolerance,
      bounds.bottom + tolerance,
    );
    return expandedBounds.contains(point);
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

      if (success) {
        // Mark document as modified since drawings were saved
        DocumentPreviewService().markDocumentAsModified(widget.documentId!);
      }

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
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Save',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: _mode == DrawingMode.erase ? Colors.red[50] : Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: _mode == DrawingMode.erase
                      ? Colors.red.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: _undoStack.isNotEmpty ? _undo : null,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: _redoStack.isNotEmpty ? _redo : null,
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
                      color: _mode == DrawingMode.erase ? Colors.red : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.erase;
                      });
                    },
                    tooltip: 'Eraser',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.highlight,
                      color: _mode == DrawingMode.highlight ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.highlight;
                      });
                    },
                    tooltip: 'Highlight',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.crop_square,
                      color: _mode == DrawingMode.square ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.square;
                      });
                    },
                    tooltip: 'Square',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.circle_outlined,
                      color: _mode == DrawingMode.circle ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.circle;
                      });
                    },
                    tooltip: 'Circle',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.show_chart,
                      color: _mode == DrawingMode.line ? Colors.blue : null,
                    ),
                    onPressed: () {
                      setState(() {
                        _mode = DrawingMode.line;
                      });
                    },
                    tooltip: 'Line',
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
                  if (_mode == DrawingMode.square || _mode == DrawingMode.circle || _mode == DrawingMode.line) {
                    // For shapes, we store the start point and current point
                    _shapeStartPoint = localPosition;
                    _shapeCurrentPoint = localPosition;
                    _currentPath = DrawingPath(
                      points: [localPosition],
                      color: _selectedColor,
                      strokeWidth: _strokeWidth,
                      mode: _mode,
                      pathType: _mode == DrawingMode.square ? PathType.square :
                               _mode == DrawingMode.circle ? PathType.circle : PathType.line,
                      shapeTool: _mode == DrawingMode.square ? ShapeTool.square :
                                _mode == DrawingMode.circle ? ShapeTool.circle : ShapeTool.line,
                      startPoint: localPosition,
                      endPoint: localPosition,
                    );
                  } else {
                    // For freehand drawing, erasing, and highlighting
                    _currentPath = DrawingPath(
                      points: [localPosition],
                      color: _mode == DrawingMode.erase 
                          ? Colors.transparent 
                          : _mode == DrawingMode.highlight 
                              ? Colors.yellow  // Use yellow for highlighting
                              : _selectedColor,
                      strokeWidth: _mode == DrawingMode.highlight 
                          ? _strokeWidth * 2 
                          : _mode == DrawingMode.erase 
                              ? _strokeWidth * 1.5  // Make eraser slightly thicker for better coverage
                              : _strokeWidth,
                      mode: _mode,
                      pathType: _mode == DrawingMode.draw ? PathType.draw : 
                               _mode == DrawingMode.erase ? PathType.erase : PathType.highlight,
                    );
                  }
                });
              },
              onPanUpdate: (details) {
                if (_currentPath == null) return;

                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                final localPosition = renderBox.globalToLocal(details.globalPosition);
                setState(() {
                  if (_mode == DrawingMode.square || _mode == DrawingMode.circle || _mode == DrawingMode.line) {
                    // For shapes, update the current point and end point
                    _shapeCurrentPoint = localPosition;
                    _currentPath = _currentPath!.copyWith(
                      endPoint: localPosition,
                    );
                  } else {
                    // For freehand drawing, erasing, and highlighting
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
                  }
                });
              },
              onPanEnd: (details) {
                if (_currentPath == null) return;

                _saveToHistory();
                setState(() {
                  if (_currentPath!.mode == DrawingMode.erase) {
                    _erasePaths(_currentPath!);
                  } else {
                    // Add draw, highlight, and shape paths
                    _paths.add(_currentPath!);
                  }
                  _currentPath = null;
                  _shapeStartPoint = null;
                  _shapeCurrentPoint = null;
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
          // Erase mode indicator — floats over the canvas via Stack
          if (_mode == DrawingMode.erase)
            Positioned(
              top: 100,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cleaning_services,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ERASE MODE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawingCanvas() {
    if (widget.page.type == 'DigitalPage') {
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
                              painter: _SimplePathPainter(
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
      // Simple image display
      return LayoutBuilder(
        builder: (context, constraints) {
          if (_backgroundImage == null) {
            return const SizedBox.shrink();
          }

          final imageAspect = _backgroundImage!.width / _backgroundImage!.height;
          final availableWidth = constraints.maxWidth - 16;
          final availableHeight = constraints.maxHeight - 16;

          double displayWidth, displayHeight;
          if (availableWidth / availableHeight > imageAspect) {
            displayHeight = availableHeight;
            displayWidth = displayHeight * imageAspect;
          } else {
            displayWidth = availableWidth;
            displayHeight = displayWidth / imageAspect;
          }

          final imageRect = Rect.fromCenter(
            center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
            width: displayWidth,
            height: displayHeight,
          );

          return CustomPaint(
            painter: _SimpleImagePainter(
              image: _backgroundImage!,
              imageDisplayRect: imageRect,
            ),
            foregroundPainter: (_paths.isNotEmpty || _currentPath != null)
                ? _SimplePathPainter(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum DrawingMode {
  draw,
  erase,
  highlight,
  square,
  circle,
  line,
}

enum PathType {
  draw,
  erase,
  highlight,
  square,
  circle,
  line,
}

enum ShapeTool {
  square,
  circle,
  line,
}

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingMode mode;
  final PathType pathType;
  final ShapeTool? shapeTool;
  final Offset? startPoint;
  final Offset? endPoint;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.mode,
    required this.pathType,
    this.shapeTool,
    this.startPoint,
    this.endPoint,
  });

  DrawingPath copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    DrawingMode? mode,
    PathType? pathType,
    ShapeTool? shapeTool,
    Offset? startPoint,
    Offset? endPoint,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      mode: mode ?? this.mode,
      pathType: pathType ?? this.pathType,
      shapeTool: shapeTool ?? this.shapeTool,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
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
      'path_type': pathType.name,
      'shape_tool': shapeTool?.name,
      'start_point': startPoint != null ? [startPoint!.dx, startPoint!.dy] : null,
      'end_point': endPoint != null ? [endPoint!.dx, endPoint!.dy] : null,
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

    // Parse path type from JSON, default to draw if not present
    final pathTypeString = json['path_type'] as String? ?? 'draw';
    final pathType = PathType.values.firstWhere(
      (type) => type.name == pathTypeString,
      orElse: () => PathType.draw,
    );

    // Parse shape tool from JSON
    final shapeToolString = json['shape_tool'] as String?;
    final shapeTool = shapeToolString != null 
        ? ShapeTool.values.firstWhere(
            (tool) => tool.name == shapeToolString,
            orElse: () => ShapeTool.square,
          )
        : null;

    // Parse start and end points for shapes
    Offset? startPoint;
    Offset? endPoint;
    if (json['start_point'] != null) {
      final startList = json['start_point'] as List<dynamic>;
      startPoint = Offset(startList[0] as double, startList[1] as double);
    }
    if (json['end_point'] != null) {
      final endList = json['end_point'] as List<dynamic>;
      endPoint = Offset(endList[0] as double, endList[1] as double);
    }

    return DrawingPath(
      points: points,
      color: color,
      strokeWidth: (json['stroke_width'] as num).toDouble(),
      mode: DrawingMode.draw, // Default to draw mode for loaded paths
      pathType: pathType,
      shapeTool: shapeTool,
      startPoint: startPoint,
      endPoint: endPoint,
    );
  }
}

/// Simple painter for drawing paths - rewritten from scratch
class _SimplePathPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? inProgressPath;

  _SimplePathPainter({
    required this.paths,
    this.inProgressPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths
    for (final path in paths) {
      final isHighlight = path.pathType == PathType.highlight;
      final paint = Paint()
        ..color = isHighlight
            ? path.color.withValues(alpha: 0.3)
            : path.color
        ..strokeWidth = isHighlight
            ? path.strokeWidth * 3
            : path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if ((path.pathType == PathType.square || path.pathType == PathType.circle || path.pathType == PathType.line) && path.startPoint != null && path.endPoint != null) {
        // Draw shapes
        _drawShape(canvas, paint, path);
      } else if (path.points.isNotEmpty) {
        // Draw freehand paths
        final drawPath = _createSimplePath(path.points);
        canvas.drawPath(drawPath, paint);
      }
    }

    // Draw in-progress path
    if (inProgressPath != null) {
      final paint = Paint()
        ..color = inProgressPath!.pathType == PathType.highlight
            ? inProgressPath!.color.withValues(alpha: 0.3)
            : inProgressPath!.color
        ..strokeWidth = inProgressPath!.pathType == PathType.highlight
            ? inProgressPath!.strokeWidth * 3
            : inProgressPath!.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if ((inProgressPath!.pathType == PathType.square || inProgressPath!.pathType == PathType.circle || inProgressPath!.pathType == PathType.line) && inProgressPath!.startPoint != null && inProgressPath!.endPoint != null) {
        // Draw in-progress shape
        _drawShape(canvas, paint, inProgressPath!);
      } else if (inProgressPath!.points.isNotEmpty) {
        // Draw in-progress freehand path
        final drawPath = _createSimplePath(inProgressPath!.points);
        canvas.drawPath(drawPath, paint);
      }
    }
  }

  /// Creates a simple path
  Path _createSimplePath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: points[0], radius: 1.0));
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  /// Draws a shape based on the shape tool
  void _drawShape(Canvas canvas, Paint paint, DrawingPath path) {
    if (path.startPoint == null || path.endPoint == null || path.shapeTool == null) return;

    final start = path.startPoint!;
    final end = path.endPoint!;

    switch (path.shapeTool!) {
      case ShapeTool.square:
        final rect = Rect.fromPoints(start, end);
        canvas.drawRect(rect, paint);
        break;
      case ShapeTool.circle:
        final center = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
        final radius = (end - start).distance / 2;
        canvas.drawCircle(center, radius, paint);
        break;
      case ShapeTool.line:
        canvas.drawLine(start, end, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_SimplePathPainter oldDelegate) {
    return oldDelegate.paths.length != paths.length ||
        oldDelegate.inProgressPath != inProgressPath ||
        !identical(oldDelegate.paths, paths);
  }
}

/// Simple painter that only draws the image - rewritten from scratch
class _SimpleImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect imageDisplayRect;

  _SimpleImagePainter({
    required this.image,
    required this.imageDisplayRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, imageDisplayRect, Paint());
  }

  @override
  bool shouldRepaint(_SimpleImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.imageDisplayRect != imageDisplayRect;
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
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
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
