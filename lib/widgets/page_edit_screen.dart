import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../auth_service.dart';
import '../models/document_page_data.dart';
import 'image_drawing_screen.dart';

/// Universal page editing screen that handles both digital and image pages
class PageEditScreen extends StatefulWidget {
  final DocumentPageData page;
  final String? documentId;
  final int? pageIndex;

  const PageEditScreen({
    super.key,
    required this.page,
    this.documentId,
    this.pageIndex,
  });

  @override
  State<PageEditScreen> createState() => _PageEditScreenState();
}

class _PageEditScreenState extends State<PageEditScreen> {
  bool _isDrawingMode = false;

  @override
  void initState() {
    super.initState();
    // Default to drawing mode for image pages, typing for digital pages
    _isDrawingMode = widget.page.type == 'ImagePage';
  }

  @override
  Widget build(BuildContext context) {
    // For image pages, always show drawing interface
    if (widget.page.type == 'ImagePage') {
      return ImageDrawingScreen(
        page: widget.page,
        documentId: widget.documentId,
        pageIndex: widget.pageIndex,
      );
    }

    // For digital pages, show typing interface with optional drawing overlay
    return _DigitalPageEditScreen(
      page: widget.page,
      documentId: widget.documentId,
      pageIndex: widget.pageIndex,
      isDrawingMode: _isDrawingMode,
      onToggleDrawingMode: (enabled) {
        setState(() {
          _isDrawingMode = enabled;
        });
      },
    );
  }
}

/// Edit screen for digital pages with typing and optional drawing
class _DigitalPageEditScreen extends StatefulWidget {
  final DocumentPageData page;
  final String? documentId;
  final int? pageIndex;
  final bool isDrawingMode;
  final Function(bool) onToggleDrawingMode;

  const _DigitalPageEditScreen({
    required this.page,
    required this.documentId,
    required this.pageIndex,
    required this.isDrawingMode,
    required this.onToggleDrawingMode,
  });

  @override
  State<_DigitalPageEditScreen> createState() => _DigitalPageEditScreenState();
}

class _DigitalPageEditScreenState extends State<_DigitalPageEditScreen> {
  final List<DrawingPath> _paths = [];
  final List<DrawingPath> _undoPaths = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;
  DrawingMode _mode = DrawingMode.draw;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    if (widget.documentId == null || widget.pageIndex == null) return;

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
      // Silently fail
    }
  }

  Future<bool> _savePaths() async {
    if (widget.documentId == null || widget.pageIndex == null) {
      return true;
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

  @override
  Widget build(BuildContext context) {
    if (widget.page.controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Page'),
          backgroundColor: const Color(0xff102837),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Error: No controller available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDrawingMode ? 'Draw on Page' : 'Edit Page'),
        backgroundColor: const Color(0xff102837),
        foregroundColor: Colors.white,
        actions: [
          // Toggle drawing mode button
          IconButton(
            icon: Icon(
              widget.isDrawingMode ? Icons.edit : Icons.draw,
              color: widget.isDrawingMode ? const Color(0xffc7ffbf) : Colors.white,
            ),
            onPressed: () {
              if (widget.isDrawingMode) {
                // Save drawings before switching to typing mode
                _savePaths();
              }
              widget.onToggleDrawingMode(!widget.isDrawingMode);
            },
            tooltip: widget.isDrawingMode ? 'Switch to typing' : 'Draw on page',
          ),
          // Save button
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xffc7ffbf)),
            onPressed: () async {
              if (widget.isDrawingMode) {
                final success = await _savePaths();
                if (success && context.mounted) {
                  Navigator.pop(context, true);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to save drawing'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                // Just close (text auto-saves)
                Navigator.pop(context, true);
              }
            },
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          // Show drawing toolbar only in drawing mode
          if (widget.isDrawingMode)
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
                    _buildColorButton(Colors.red),
                    _buildColorButton(Colors.blue),
                    _buildColorButton(Colors.green),
                    _buildColorButton(Colors.yellow),
                    _buildColorButton(Colors.orange),
                    _buildColorButton(Colors.purple),
                    _buildColorButton(Colors.black),
                    const VerticalDivider(),
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
            ),
          // Show text toolbar only in typing mode
          if (!widget.isDrawingMode)
            ResponsiveFleatherToolbar(controller: widget.page.controller!),
          // Editor/Canvas
          Expanded(
            child: Container(
              color: const Color(0xfffafafa),
              child: Stack(
                children: [
                  // Text editor (always present, but disabled in drawing mode)
                  Positioned.fill(
                    child: widget.isDrawingMode
                        ? AbsorbPointer(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: FleatherEditor(controller: widget.page.controller!),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: FleatherEditor(controller: widget.page.controller!),
                          ),
                  ),
                  // Drawing layer (only interactive in drawing mode)
                  if (widget.isDrawingMode)
                    Positioned.fill(
                      child: _buildDrawingLayer(),
                    )
                  else if (_paths.isNotEmpty)
                    // Show paths as overlay in typing mode
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _DrawingPainter(paths: _paths),
                        ),
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

  Widget _buildDrawingLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (details) {
            setState(() {
              _isDrawing = true;
              _undoPaths.clear();
              if (_mode == DrawingMode.erase) {
                return;
              }
              _paths.add(DrawingPath(
                points: [details.localPosition],
                color: _selectedColor,
                strokeWidth: _strokeWidth,
              ));
            });
          },
          onPointerMove: (details) {
            if (_isDrawing) {
              setState(() {
                if (_mode == DrawingMode.erase) {
                  _paths.removeWhere((path) {
                    for (final point in path.points) {
                      if ((point - details.localPosition).distance < path.strokeWidth * 2) {
                        return true;
                      }
                    }
                    return false;
                  });
                } else if (_paths.isNotEmpty) {
                  final currentPath = _paths.last;
                  final updatedPoints = List<Offset>.from(currentPath.points)
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
            painter: _DrawingPainter(paths: _paths),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
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

class _DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  _DrawingPainter({required this.paths});

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
  bool shouldRepaint(_DrawingPainter oldDelegate) {
    return oldDelegate.paths.length != paths.length;
  }
}

// Import ResponsiveFleatherToolbar from main.dart (or move it to a shared file)
class ResponsiveFleatherToolbar extends StatelessWidget {
  final FleatherController controller;

  const ResponsiveFleatherToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xfff0f0f0),
        border: Border(bottom: BorderSide(color: Color(0xffc3e3ea), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: FleatherToolbar.basic(controller: controller),
      ),
    );
  }
}
