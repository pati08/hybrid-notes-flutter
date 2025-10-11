import 'dart:async';
import 'dart:math' as math;
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
  final TransformationController _transformationController =
      TransformationController();
  final double _pageWidth = 800.0; // Standard page width
  final double _pageSpacing = 40.0; // Spacing between pages
  final Map<int, double> _pageHeights = {}; // Cache calculated page heights
  int _refreshKey = 0; // Key to force rebuild of preview widgets

  // Drawing mode state
  bool _isDrawingMode = false;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;
  DrawingMode _drawMode = DrawingMode.draw;
  
  // Drawing data storage
  final Map<int, List<DrawingPath>> _pageDrawings = {}; // Map of page index to list of paths
  final Map<int, List<DrawingPath>> _undonePaths = {}; // Map of page index to undone paths
  DrawingPath? _currentPath; // Currently drawing path
  int? _currentDrawingPage; // Which page we're currently drawing on
  
  // Track number of pointers for two-finger gestures
  int _pointerCount = 0;
  
  // Track potential drawing start to prevent unwanted dots during zoom/pan
  Timer? _drawingStartTimer;
  bool _isPotentialMultiTouch = false;

  @override
  void initState() {
    super.initState();

    // Pre-calculate page heights
    _calculatePageHeights();

    // Load existing drawings for all pages
    _loadAllDrawings();

    // Set initial view to show first page centered and scaled to fit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnPage(0);
    });
  }
  
  Future<void> _loadAllDrawings() async {
    if (widget.documentId == null) return;
    
    for (int i = 0; i < widget.pages.length; i++) {
      await _loadDrawingsForPage(i);
    }
  }
  
  Future<void> _loadDrawingsForPage(int pageIndex) async {
    if (widget.documentId == null) return;
    
    try {
      final authService = AuthService();
      final result = await authService.getDrawingList(
        widget.documentId!,
        pageIndex,
      );
      
      if (result.success && result.drawingList != null && mounted) {
        final paths = result.drawingList!
            .map((json) => DrawingPath.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('Loaded ${paths.length} paths for page $pageIndex');
        if (paths.isNotEmpty) {
          debugPrint('First path has ${paths[0].points.length} points');
        }
        setState(() {
          _pageDrawings[pageIndex] = paths;
        });
      } else {
        debugPrint('No drawings found for page $pageIndex (success: ${result.success})');
      }
    } catch (e) {
      debugPrint('Error loading drawings for page $pageIndex: $e');
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _drawingStartTimer?.cancel();
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
    final offsetY = (size.height / 2) -
        (pageY * scale) -
        (_getPageHeight(pageIndex) * scale / 2);

    // ignore: deprecated_member_use
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
  
  // Detect which page a point is on, returns null if not on any page
  int? _getPageAtPosition(Offset position) {
    // Account for transformation
    final matrix = _transformationController.value;
    final inverse = Matrix4.inverted(matrix);
    final transformedPoint = MatrixUtils.transformPoint(inverse, position);
    
    double currentY = _pageSpacing;
    for (int i = 0; i < widget.pages.length; i++) {
      final pageHeight = _getPageHeight(i);
      
      // Check if point is within this page's bounds
      if (transformedPoint.dx >= _pageSpacing &&
          transformedPoint.dx <= _pageSpacing + _pageWidth &&
          transformedPoint.dy >= currentY &&
          transformedPoint.dy <= currentY + pageHeight) {
        return i;
      }
      
      currentY += pageHeight + _pageSpacing;
    }
    
    return null; // Not on any page
  }
  
  // Convert screen coordinates to page-local coordinates
  Offset _screenToPageCoordinates(Offset screenPoint, int pageIndex) {
    final matrix = _transformationController.value;
    final inverse = Matrix4.inverted(matrix);
    final transformedPoint = MatrixUtils.transformPoint(inverse, screenPoint);
    
    // Calculate page top-left position
    double pageY = _pageSpacing;
    for (int i = 0; i < pageIndex; i++) {
      pageY += _getPageHeight(i) + _pageSpacing;
    }
    
    // Convert to page-local coordinates
    return Offset(
      transformedPoint.dx - _pageSpacing,
      transformedPoint.dy - pageY,
    );
  }
  
  void _handleDrawingStart(Offset screenPosition) {
    // Only draw with exactly one finger
    if (!_isDrawingMode || _pointerCount != 1) return;
    
    final pageIndex = _getPageAtPosition(screenPosition);
    if (pageIndex == null) {
      return; // Not on a page
    }
    
    final localPoint = _screenToPageCoordinates(screenPosition, pageIndex);
    final newPath = DrawingPath(
      points: [localPoint],
      color: _selectedColor,
      strokeWidth: _strokeWidth,
      mode: _drawMode,
    );
    
    setState(() {
      _currentDrawingPage = pageIndex;
      _currentPath = newPath;
      if (_drawMode == DrawingMode.erase) {
        _erasePaths(pageIndex, newPath);
      }
    });
  }
  
  void _handleDrawingUpdate(Offset screenPosition) {
    // Stop drawing if a second finger touches
    if (!_isDrawingMode || _currentPath == null || _currentDrawingPage == null || _pointerCount != 1) {
      // If we were drawing and a second finger touched, end the current path
      if (_currentPath != null && _pointerCount > 1) {
        _handleDrawingEnd();
      }
      return;
    }
    
    final pageIndex = _getPageAtPosition(screenPosition);
    final currentPage = _currentDrawingPage!;
    if (pageIndex != currentPage) return; // Moved off the page
    
    final localPoint = _screenToPageCoordinates(screenPosition, currentPage);
    
    setState(() {
      // Add adaptive point sampling to reduce segmentation
      final currentPoints = _currentPath!.points;
      if (currentPoints.isNotEmpty) {
        final lastPoint = currentPoints.last;
        final distance = (localPoint - lastPoint).distance;
        
        // Only add point if it's far enough from the last point
        // This reduces segmentation during fast strokes
        if (distance > 2.0) {
          final updatedPath = DrawingPath(
            points: [...currentPoints, localPoint],
            color: _currentPath!.color,
            strokeWidth: _currentPath!.strokeWidth,
            mode: _currentPath!.mode,
          );
          _currentPath = updatedPath;
          if (_drawMode == DrawingMode.erase) {
            _erasePaths(currentPage, updatedPath);
          }
        }
      } else {
        // First point - always add it
        final updatedPath = DrawingPath(
          points: [localPoint],
          color: _currentPath!.color,
          strokeWidth: _currentPath!.strokeWidth,
          mode: _currentPath!.mode,
        );
        _currentPath = updatedPath;
        if (_drawMode == DrawingMode.erase) {
          _erasePaths(currentPage, updatedPath);
        }
      }
    });
  }
  
  void _handleDrawingEnd() {
    if (!_isDrawingMode || _currentPath == null || _currentDrawingPage == null) return;
    
    setState(() {
      // Add the completed path to the page's drawing list
      if (_drawMode == DrawingMode.draw) {
        if (!_pageDrawings.containsKey(_currentDrawingPage)) {
          _pageDrawings[_currentDrawingPage!] = [];
        }
        _pageDrawings[_currentDrawingPage!]!.add(_currentPath!);
        debugPrint('Added path with ${_currentPath!.points.length} points to page $_currentDrawingPage. Total paths: ${_pageDrawings[_currentDrawingPage!]!.length}');
      } else if (_drawMode == DrawingMode.erase) {
        // Erase mode: remove paths that intersect with the eraser
        _erasePaths(_currentDrawingPage!, _currentPath!);
      }
      
      // Clear undone paths for this page when a new action is performed
      _undonePaths[_currentDrawingPage!]?.clear();
      
      _currentPath = null;
      _currentDrawingPage = null;
    });
  }
  
  void _erasePaths(int pageIndex, DrawingPath eraserPath) {
    if (!_pageDrawings.containsKey(pageIndex)) return;
    
    final paths = _pageDrawings[pageIndex]!;
    final eraserPoints = eraserPath.points;
    
    // Remove paths that intersect with the eraser
    paths.removeWhere((path) {
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
  
  void _undo() {
    // Find the most recently modified page with paths to undo
    int? pageToUndo;
    for (int i = widget.pages.length - 1; i >= 0; i--) {
      if (_pageDrawings.containsKey(i) && _pageDrawings[i]!.isNotEmpty) {
        pageToUndo = i;
        break;
      }
    }
    
    if (pageToUndo == null) return;
    
    setState(() {
      final removedPath = _pageDrawings[pageToUndo!]!.removeLast();
      if (!_undonePaths.containsKey(pageToUndo)) {
        _undonePaths[pageToUndo] = [];
      }
      _undonePaths[pageToUndo]!.add(removedPath);
    });
  }

  void _redo() {
    // Find the most recently modified page with undone paths to redo
    int? pageToRedo;
    for (int i = widget.pages.length - 1; i >= 0; i--) {
      if (_undonePaths.containsKey(i) && _undonePaths[i]!.isNotEmpty) {
        pageToRedo = i;
        break;
      }
    }
    
    if (pageToRedo == null) return;
    
    setState(() {
      final restoredPath = _undonePaths[pageToRedo!]!.removeLast();
      if (!_pageDrawings.containsKey(pageToRedo)) {
        _pageDrawings[pageToRedo] = [];
      }
      _pageDrawings[pageToRedo]!.add(restoredPath);
    });
  }

  void _clear() {
    bool hasAnyPaths = false;
    for (final paths in _pageDrawings.values) {
      if (paths.isNotEmpty) {
        hasAnyPaths = true;
        break;
      }
    }
    
    if (!hasAnyPaths) return;
    
    setState(() {
      _pageDrawings.clear();
      _undonePaths.clear();
      _currentPath = null;
      _currentDrawingPage = null;
    });
  }

  bool _canUndo() {
    for (final paths in _pageDrawings.values) {
      if (paths.isNotEmpty) return true;
    }
    return false;
  }

  bool _canRedo() {
    for (final paths in _undonePaths.values) {
      if (paths.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _saveAllModifiedPages() async {
    if (widget.documentId == null) return;
    
    final authService = AuthService();
    
    // Save all pages that have drawings
    for (final entry in _pageDrawings.entries) {
      final pageIndex = entry.key;
      final paths = entry.value;
      
      try {
        final pathsJson = paths.map((p) => p.toJson()).toList();
        await authService.saveDrawingList(
          widget.documentId!,
          pageIndex,
          pathsJson,
        );
      } catch (e) {
        debugPrint('Error saving drawings for page $pageIndex: $e');
      }
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
            child: _isDrawingMode
                ? Listener(
                    onPointerDown: (event) {
                      _pointerCount++;
                      
                      // Cancel any pending drawing start timer
                      _drawingStartTimer?.cancel();
                      
                      if (_pointerCount == 1) {
                        // Set a flag to indicate we might be starting a multi-touch gesture
                        _isPotentialMultiTouch = true;
                        
                        // Delay drawing start to see if a second finger touches quickly
                        _drawingStartTimer = Timer(const Duration(milliseconds: 100), () {
                          // Only start drawing if we still have exactly one finger
                          // and no second finger touched during the delay
                          if (_pointerCount == 1 && _isPotentialMultiTouch && mounted) {
                            _isPotentialMultiTouch = false;
                            _handleDrawingStart(event.localPosition);
                          }
                        });
                      } else {
                        // Second finger touched - cancel any potential drawing
                        _isPotentialMultiTouch = false;
                        _drawingStartTimer?.cancel();
                        
                        if (_currentPath != null) {
                          // End current drawing if second finger touches
                          _handleDrawingEnd();
                        }
                      }
                    },
                    onPointerMove: (event) {
                      // Only draw with exactly one finger and if we're not in potential multi-touch mode
                      if (_pointerCount == 1 && !_isPotentialMultiTouch && _currentPath != null) {
                        _handleDrawingUpdate(event.localPosition);
                      }
                    },
                    onPointerUp: (event) {
                      if (_pointerCount == 1 && _currentPath != null && !_isPotentialMultiTouch) {
                        _handleDrawingEnd();
                      }
                      _pointerCount--;
                      if (_pointerCount < 0) _pointerCount = 0;
                      
                      // Reset multi-touch flag when all fingers are lifted
                      if (_pointerCount == 0) {
                        _isPotentialMultiTouch = false;
                        _drawingStartTimer?.cancel();
                      }
                    },
                    onPointerCancel: (event) {
                      if (_currentPath != null) {
                        _handleDrawingEnd();
                      }
                      _pointerCount--;
                      if (_pointerCount < 0) _pointerCount = 0;
                      
                      // Reset multi-touch flag when all fingers are lifted
                      if (_pointerCount == 0) {
                        _isPotentialMultiTouch = false;
                        _drawingStartTimer?.cancel();
                      }
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.1,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(200),
                      constrained: false,
                      panEnabled: false, // Disable single-finger pan
                      scaleEnabled: true, // Enable two-finger zoom/pan
                      child: _buildCanvas(),
                    ),
                  )
                : InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.1,
                    maxScale: 4.0,
                    boundaryMargin: const EdgeInsets.all(200),
                    constrained: false,
                    panEnabled: true,
                    scaleEnabled: true,
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
                  await _saveAllModifiedPages();
                }
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
              },
              backgroundColor: _isDrawingMode
                  ? const Color(0xffbd6051)
                  : const Color(0xff102837),
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
              icon: const Icon(Icons.undo),
              onPressed: _canUndo() ? _undo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _canRedo() ? _redo : null,
              tooltip: 'Redo',
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _canUndo() ? _clear : null,
              tooltip: 'Clear All',
            ),
            const VerticalDivider(),
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
          for (int i = 0; i < widget.pages.length; i++) _buildPage(i),
        ],
      ),
    );
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              // Tap indicator overlay (only when not in drawing mode)
              if (!_isDrawingMode)
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
    // Get drawings for this page (including current drawing if it's this page)
    // Don't show the eraser path while erasing (it should be invisible)
    final drawings = _pageDrawings[index] ?? [];
    final allDrawings = _currentDrawingPage == index && 
                       _currentPath != null && 
                       _drawMode != DrawingMode.erase
        ? [...drawings, _currentPath!]
        : drawings;
    
    if (allDrawings.isNotEmpty) {
      debugPrint('Building page $index content with ${allDrawings.length} drawings');
    }
    
    if (page.type == 'DigitalPage' && page.controller != null) {
      return _DigitalPagePreview(
        key: ValueKey('digital_$index\_$_refreshKey'),
        controller: page.controller!,
        drawings: allDrawings,
      );
    } else if (page.type == 'ImagePage' && page.imageBytes != null) {
      return _ImagePagePreview(
        key: ValueKey('image_$index\_$_refreshKey'),
        imageBytes: page.imageBytes!,
        drawings: allDrawings,
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
  final List<DrawingPath> drawings;

  const _DigitalPagePreview({
    super.key,
    required this.controller,
    required this.drawings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfffafafa),
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FleatherEditor(controller: controller),
              ),
            ),
          ),
          // Drawing overlay
          if (drawings.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: _DrawingPainter(paths: drawings),
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
  final List<DrawingPath> drawings;
  final Function(double aspectRatio)? onImageLoaded;

  const _ImagePagePreview({
    super.key,
    required this.imageBytes,
    required this.drawings,
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

  @override
  void didUpdateWidget(_ImagePagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If drawings changed, trigger a rebuild
    if (widget.drawings.length != oldWidget.drawings.length) {
      debugPrint('_ImagePagePreview: Drawings changed from ${oldWidget.drawings.length} to ${widget.drawings.length}');
      setState(() {
        // Force rebuild with new drawings
      });
    }
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
              containerSize: Size(fullWidth, fullHeight),
              padding: 16.0,
              paths: widget.drawings,
            ),
            size: Size(fullWidth, fullHeight),
          );
        },
      ),
    );
  }
}

/// Custom painter for image with drawings
class _ImageWithPathsPainter extends CustomPainter {
  final ui.Image image;
  final Size containerSize;
  final double padding;
  final List<DrawingPath> paths;

  _ImageWithPathsPainter({
    required this.image,
    required this.containerSize,
    this.padding = 0.0,
    this.paths = const [],
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
    
    // Draw paths on top of image
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
  bool shouldRepaint(_ImageWithPathsPainter oldDelegate) {
    // Check if paths changed by comparing list contents
    bool pathsChanged = oldDelegate.paths.length != paths.length;
    if (!pathsChanged && paths.isNotEmpty) {
      // Quick check: compare references (if they're different objects, repaint)
      pathsChanged = !identical(oldDelegate.paths, paths);
    }
    
    return oldDelegate.image != image ||
        oldDelegate.containerSize != containerSize ||
        oldDelegate.padding != padding ||
        pathsChanged;
  }
}

/// Custom painter for drawing paths
class _DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  _DrawingPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    if (paths.isNotEmpty) {
      debugPrint('_DrawingPainter painting ${paths.length} paths on canvas size: $size');
    }
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
  bool shouldRepaint(_DrawingPainter oldDelegate) {
    // Repaint if path count changed or if it's a different list instance
    return oldDelegate.paths.length != paths.length || !identical(oldDelegate.paths, paths);
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
      mode: DrawingMode.draw, // Default to draw mode for loaded paths
    );
  }
}
