import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../auth_service.dart';

class ImageDrawingScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String? currentAttachmentId;
  final String? documentId;
  final int? pageIndex;

  const ImageDrawingScreen({
    super.key,
    required this.imageBytes,
    this.currentAttachmentId,
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

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadPaths();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _backgroundImage = frame.image;
      _isLoading = false;
    });
  }

  Future<void> _loadPaths() async {
    // Only load paths if we have documentId and pageIndex
    if (widget.documentId == null || widget.pageIndex == null) {
      debugPrint('No documentId or pageIndex, skipping path loading');
      return;
    }

    try {
      debugPrint('Loading paths for doc=${widget.documentId}, page=${widget.pageIndex}');
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
        debugPrint('✅ Loaded ${loadedPaths.length} paths');
      } else {
        debugPrint('Failed to load paths: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error loading paths: $e');
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
      debugPrint('⚠️ No documentId or pageIndex, skipping path saving');
      debugPrint('   documentId: ${widget.documentId}');
      debugPrint('   pageIndex: ${widget.pageIndex}');
      return true; // Not an error, just nothing to save
    }

    try {
      debugPrint('💾 Saving ${_paths.length} paths...');
      debugPrint('   documentId: ${widget.documentId}');
      debugPrint('   pageIndex: ${widget.pageIndex}');
      
      final authService = AuthService();
      final pathsJson = _paths.map((path) => path.toJson()).toList();
      
      debugPrint('   Serialized ${pathsJson.length} paths to JSON');
      
      final success = await authService.saveDrawingList(
        widget.documentId!,
        widget.pageIndex!,
        pathsJson,
      );

      if (success) {
        debugPrint('✅ Paths saved successfully');
      } else {
        debugPrint('❌ Failed to save paths (API returned false)');
      }
      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving paths: $e');
      debugPrint('   Stack trace: $stackTrace');
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
          // Drawing canvas
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Listener(
                    onPointerDown: (details) {
                      debugPrint(
                          '🖱️ POINTER DOWN at ${details.localPosition}');
                      debugPrint(
                          '   Current mode: $_mode, Color: $_selectedColor, Stroke: $_strokeWidth');
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
                        debugPrint(
                            '   ✅ Added new path. Total paths: ${_paths.length}');
                      });
                    },
                    onPointerMove: (details) {
                      if (_isDrawing) {
                        debugPrint(
                            '🖱️ POINTER MOVE at ${details.localPosition} (drawing: $_isDrawing)');
                        setState(() {
                          if (_mode == DrawingMode.erase) {
                            // In erase mode, remove paths that are touched
                            _paths.removeWhere((path) {
                              // Check if eraser point is near any point in this path
                              for (final point in path.points) {
                                final distance =
                                    (point - details.localPosition).distance;
                                if (distance < path.strokeWidth * 2) {
                                  debugPrint(
                                      '   🗑️ Erased path with ${path.points.length} points');
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
                            debugPrint(
                                '   ✅ Added point. Current path has ${_paths.last.points.length} points');
                          }
                        });
                      } else {
                        debugPrint('🖱️ POINTER MOVE ignored (not drawing)');
                      }
                    },
                    onPointerUp: (details) {
                      debugPrint('🖱️ POINTER UP at ${details.localPosition}');
                      setState(() {
                        _isDrawing = false;
                      });
                    },
                    onPointerCancel: (details) {
                      debugPrint('🖱️ POINTER CANCEL');
                      setState(() {
                        _isDrawing = false;
                      });
                    },
                    child: CustomPaint(
                      painter: DrawingPainter(
                        backgroundImage: _backgroundImage,
                        paths: List<DrawingPath>.from(
                            _paths), // Create a new list each time
                      ),
                      child: SizedBox(
                        width: _backgroundImage!.width.toDouble(),
                        height: _backgroundImage!.height.toDouble(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

  DrawingPainter({
    this.backgroundImage,
    required this.paths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('🎨 PAINTING - Canvas size: $size, Paths: ${paths.length}');

    // Draw background image
    if (backgroundImage != null) {
      canvas.drawImage(backgroundImage!, Offset.zero, Paint());
      debugPrint(
          '   ✅ Drew background image: ${backgroundImage!.width}x${backgroundImage!.height}');
    }

    // Create a separate layer for drawings so eraser doesn't affect background
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw all paths
    for (int pathIndex = 0; pathIndex < paths.length; pathIndex++) {
      final path = paths[pathIndex];
      debugPrint(
          '   Path $pathIndex: ${path.points.length} points, color: ${path.color}, width: ${path.strokeWidth}');

      if (path.points.isEmpty) {
        debugPrint('   ⚠️ Skipping empty path');
        continue;
      }

      final paint = Paint()
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      paint.color = path.color;
      debugPrint('   Using DRAW mode with color: ${path.color}');

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
        if (i == 0) {
          debugPrint(
              '   Drawing line from ${path.points[i]} to ${path.points[i + 1]}');
        }
      }
      debugPrint(
          '   ✅ Drew ${path.points.length - 1} lines for path $pathIndex');
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
