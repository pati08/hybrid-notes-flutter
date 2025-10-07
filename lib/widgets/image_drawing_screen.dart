import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ImageDrawingScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String? currentAttachmentId;

  const ImageDrawingScreen({
    super.key,
    required this.imageBytes,
    this.currentAttachmentId,
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
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _backgroundImage = frame.image;
      _isLoading = false;
    });
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

  Future<Uint8List?> _saveDrawing() async {
    try {
      debugPrint('💾 Starting save drawing...');
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      debugPrint('💾 RepaintBoundary found: ${boundary != null}');
      
      if (boundary == null) {
        debugPrint('❌ RepaintBoundary is null!');
        return null;
      }
      
      debugPrint('💾 Converting to image...');
      final image = await boundary.toImage(pixelRatio: 1.0);
      debugPrint('💾 Image created: ${image.width}x${image.height}');
      
      debugPrint('💾 Converting to PNG bytes...');
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      debugPrint('💾 ByteData created: ${byteData != null}');
      
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        debugPrint('💾 ✅ Success! Bytes length: ${bytes.length}');
        return bytes;
      }
    } catch (e) {
      debugPrint('❌ Error saving drawing: $e');
    }
    debugPrint('❌ Returning null');
    return null;
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
              final imageData = await _saveDrawing();
              if (imageData != null && context.mounted) {
                Navigator.pop(context, imageData);
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
                      debugPrint('🖱️ POINTER DOWN at ${details.localPosition}');
                      debugPrint('   Current mode: $_mode, Color: $_selectedColor, Stroke: $_strokeWidth');
                      setState(() {
                        _isDrawing = true;
                        _undoPaths.clear();
                        final newPath = DrawingPath(
                          points: [details.localPosition],
                          color: _mode == DrawingMode.erase ? Colors.transparent : _selectedColor,
                          strokeWidth: _strokeWidth,
                          mode: _mode,
                        );
                        _paths.add(newPath);
                        debugPrint('   ✅ Added new path. Total paths: ${_paths.length}');
                      });
                    },
                    onPointerMove: (details) {
                      if (_isDrawing) {
                        debugPrint('🖱️ POINTER MOVE at ${details.localPosition} (drawing: $_isDrawing)');
                        setState(() {
                          if (_mode == DrawingMode.erase) {
                            // In erase mode, remove paths that are touched
                            _paths.removeWhere((path) {
                              if (path.mode == DrawingMode.erase) return false; // Don't remove eraser paths
                              
                              // Check if eraser point is near any point in this path
                              for (final point in path.points) {
                                final distance = (point - details.localPosition).distance;
                                if (distance < path.strokeWidth * 2) {
                                  debugPrint('   🗑️ Erased path with ${path.points.length} points');
                                  return true; // Remove this path
                                }
                              }
                              return false; // Keep this path
                            });
                            // Remove the eraser path we started (we don't need to draw it)
                            if (_paths.isNotEmpty && _paths.last.mode == DrawingMode.erase) {
                              _paths.removeLast();
                            }
                          } else if (_paths.isNotEmpty) {
                            // In draw mode, add points to current path
                            final currentPath = _paths.last;
                            final updatedPoints = List<Offset>.from(currentPath.points)..add(details.localPosition);
                            _paths[_paths.length - 1] = DrawingPath(
                              points: updatedPoints,
                              color: currentPath.color,
                              strokeWidth: currentPath.strokeWidth,
                              mode: currentPath.mode,
                            );
                            debugPrint('   ✅ Added point. Current path has ${_paths.last.points.length} points');
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
                        // Remove eraser path if it exists
                        if (_paths.isNotEmpty && _paths.last.mode == DrawingMode.erase) {
                          _paths.removeLast();
                        }
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
                        paths: List<DrawingPath>.from(_paths), // Create a new list each time
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
  final DrawingMode mode;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.mode,
  });
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
      debugPrint('   ✅ Drew background image: ${backgroundImage!.width}x${backgroundImage!.height}');
    }

    // Create a separate layer for drawings so eraser doesn't affect background
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw all paths
    for (int pathIndex = 0; pathIndex < paths.length; pathIndex++) {
      final path = paths[pathIndex];
      debugPrint('   Path $pathIndex: ${path.points.length} points, color: ${path.color}, width: ${path.strokeWidth}, mode: ${path.mode}');
      
      if (path.points.isEmpty) {
        debugPrint('   ⚠️ Skipping empty path');
        continue;
      }

      final paint = Paint()
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Skip eraser paths (they don't get drawn, they just remove other paths)
      if (path.mode == DrawingMode.erase) {
        debugPrint('   ⚠️ Skipping eraser path');
        continue;
      }
      
      paint.color = path.color;
      debugPrint('   Using DRAW mode with color: ${path.color}');

      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
        if (i == 0) {
          debugPrint('   Drawing line from ${path.points[i]} to ${path.points[i + 1]}');
        }
      }
      debugPrint('   ✅ Drew ${path.points.length - 1} lines for path $pathIndex');
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
