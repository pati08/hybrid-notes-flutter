import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../models/document_page_data.dart';
import '../auth_service.dart';
import 'image_drawing_screen.dart';

/// Optimized page viewer widget with RepaintBoundary for smooth scrolling
class PageViewerWidget extends StatefulWidget {
  final List<DocumentPageData> pages;
  final PageController pageController;
  final Function(int) onPageChanged;
  final String? documentId;

  const PageViewerWidget({
    super.key,
    required this.pages,
    required this.pageController,
    required this.onPageChanged,
    this.documentId,
  });

  @override
  State<PageViewerWidget> createState() => _PageViewerWidgetState();
}

class _PageViewerWidgetState extends State<PageViewerWidget> {
  bool _isTransitioning = false;
  int _settledPageIndex = 0;
  final Set<int> _initializedPages = {
    0
  }; // Track which pages have been fully navigated to

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPageScroll);
    // Initialize with the current page if controller is already attached
    if (widget.pageController.hasClients &&
        widget.pageController.page != null) {
      _settledPageIndex = widget.pageController.page!.round();
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageScroll);
    super.dispose();
  }

  void _onPageScroll() {
    if (!widget.pageController.hasClients) return;

    final page = widget.pageController.page;
    if (page == null) return;

    // Check if we're in the middle of a transition (not at a page boundary)
    final isAtPageBoundary = (page - page.roundToDouble()).abs() < 0.01;
    final newTransitioning = !isAtPageBoundary;

    // Track which page we've settled on
    if (isAtPageBoundary) {
      final settledIndex = page.round();
      if (settledIndex != _settledPageIndex) {
        setState(() {
          _settledPageIndex = settledIndex;
          _initializedPages.add(settledIndex);
        });
      }
    }

    if (newTransitioning != _isTransitioning) {
      setState(() {
        _isTransitioning = newTransitioning;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffe8e8e8),
      child: _PageViewWithZoomControl(
        pageController: widget.pageController,
        pages: widget.pages,
        onPageChanged: widget.onPageChanged,
        isTransitioning: _isTransitioning,
        initializedPages: _initializedPages,
        settledPageIndex: _settledPageIndex,
        documentId: widget.documentId,
      ),
    );
  }
}

/// Wrapper widget that manages PageView scrolling and zoom state coordination
class _PageViewWithZoomControl extends StatefulWidget {
  final PageController pageController;
  final List<DocumentPageData> pages;
  final Function(int) onPageChanged;
  final bool isTransitioning;
  final Set<int> initializedPages;
  final int settledPageIndex;
  final String? documentId;

  const _PageViewWithZoomControl({
    required this.pageController,
    required this.pages,
    required this.onPageChanged,
    required this.isTransitioning,
    required this.initializedPages,
    required this.settledPageIndex,
    required this.documentId,
  });

  @override
  State<_PageViewWithZoomControl> createState() => _PageViewWithZoomControlState();
}

class _PageViewWithZoomControlState extends State<_PageViewWithZoomControl> {
  final Map<int, bool> _pageZoomStates = {};

  void _onPageZoomChanged(int pageIndex, bool isZoomed) {
    setState(() {
      _pageZoomStates[pageIndex] = isZoomed;
    });
  }

  bool get _anyPageZoomed => _pageZoomStates.values.any((zoomed) => zoomed);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      controller: widget.pageController,
      itemCount: widget.pages.length,
      onPageChanged: widget.onPageChanged,
      // Disable page scrolling when any page is zoomed
      physics: _anyPageZoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      // Add page snapping for better UX
      pageSnapping: true,
      // Don't allow overscroll on edges
      clipBehavior: Clip.hardEdge,
      itemBuilder: (context, index) {
        final page = widget.pages[index];

        // Wrap each page in RepaintBoundary to prevent unnecessary repaints
        // and AutomaticKeepAlive to maintain state
        return RepaintBoundary(
          child: _PageContentWidget(
            page: page,
            index: index,
            isTransitioning: widget.isTransitioning,
            canInitializeEditor: widget.initializedPages.contains(index),
            currentPageIndex: widget.settledPageIndex,
            documentId: widget.documentId,
            onZoomChanged: (isZoomed) => _onPageZoomChanged(index, isZoomed),
          ),
        );
      },
    );
  }
}

/// Separate widget for page content to isolate rebuilds
class _PageContentWidget extends StatefulWidget {
  final DocumentPageData page;
  final int index;
  final bool isTransitioning;
  final bool canInitializeEditor;
  final int currentPageIndex;
  final String? documentId;
  final Function(bool) onZoomChanged;

  const _PageContentWidget({
    required this.page,
    required this.index,
    required this.isTransitioning,
    required this.canInitializeEditor,
    required this.currentPageIndex,
    this.documentId,
    required this.onZoomChanged,
  });

  @override
  State<_PageContentWidget> createState() => _PageContentWidgetState();
}

class _PageContentWidgetState extends State<_PageContentWidget> {
  bool _editorInitialized = false;
  bool _initializationScheduled = false;
  late final TransformationController _transformationController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformChanged);
    _checkAndInitializeEditor();
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final newIsZoomed = scale > 0.95; // Consider zoomed if scale > 95%
    if (newIsZoomed != _isZoomed) {
      setState(() {
        _isZoomed = newIsZoomed;
      });
      widget.onZoomChanged(newIsZoomed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial scale to 90% centered after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = context.size;
        if (size != null) {
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
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PageContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only trigger a new check if the transition state or permission changed
    if (oldWidget.isTransitioning != widget.isTransitioning ||
        oldWidget.canInitializeEditor != widget.canInitializeEditor) {
      _checkAndInitializeEditor();
    }
  }

  void _checkAndInitializeEditor() {
    // Only initialize the editor if:
    // 1. This page has been explicitly navigated to (canInitializeEditor)
    // 2. We're not currently transitioning
    // 3. The editor hasn't been initialized yet
    // 4. This is a digital page with a controller
    // 5. We haven't already scheduled an initialization
    if (_editorInitialized ||
        _initializationScheduled ||
        !widget.canInitializeEditor ||
        widget.isTransitioning ||
        widget.page.type != 'DigitalPage' ||
        widget.page.controller == null) {
      return; // Don't initialize
    }

    _initializationScheduled = true;

    // Delay initialization to ensure the page transition is fully complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isTransitioning) {
        _initializationScheduled = false;
        return;
      }

      Future.microtask(() {
        if (mounted && !widget.isTransitioning && widget.canInitializeEditor) {
          setState(() {
            _editorInitialized = true;
          });
        } else {
          _initializationScheduled = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildPageContent(widget.page, widget.index);
  }

  Widget _buildPageContent(DocumentPageData page, int index) {
    Widget pageContent;

    if (page.type == 'DigitalPage' && page.controller != null) {
      // Digital page with text editor and drawing overlay
      // Only show the editor after initialization to prevent animation stutter
      pageContent = RepaintBoundary(
        child: _DigitalPageWithPathsWidget(
          controller: page.controller!,
          editorInitialized: _editorInitialized,
          documentId: widget.documentId,
          pageIndex: widget.index,
        ),
      );
    } else if (page.type == 'ImagePage') {
      // Image page with drawing overlay
      pageContent = Container(
        color: const Color(0xffe8e8e8), // Page background color
        child: page.imageBytes != null
            ? _ImageWithPathsWidget(
                imageBytes: page.imageBytes!,
                documentId: widget.documentId,
                pageIndex: widget.index,
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading image...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
      );
    } else {
      pageContent = const Center(
        child: Text('Unknown page type'),
      );
    }

    // Wrap each page in a card with zoom capability
    // Use custom gesture handling for two-finger pan only
    return _TwoFingerInteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Card(
        elevation: 8,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: pageContent,
        ),
      ),
    );
  }
}

/// Widget that displays an image with drawing paths overlaid
class _ImageWithPathsWidget extends StatefulWidget {
  final Uint8List imageBytes;
  final String? documentId;
  final int pageIndex;

  const _ImageWithPathsWidget({
    required this.imageBytes,
    required this.documentId,
    required this.pageIndex,
  });

  @override
  State<_ImageWithPathsWidget> createState() => _ImageWithPathsWidgetState();
}

class _ImageWithPathsWidgetState extends State<_ImageWithPathsWidget> {
  List<DrawingPath> _paths = [];
  ui.Image? _image;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadPaths();
  }

  Future<void> _loadImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frame.image;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  Future<void> _loadPaths() async {
    // Only load paths if we have documentId
    if (widget.documentId == null) {
      return;
    }

    try {
      final authService = AuthService();
      final result = await authService.getDrawingList(
        widget.documentId!,
        widget.pageIndex,
      );

      if (result.success && result.drawingList != null && mounted) {
        final loadedPaths = result.drawingList!
            .map((json) => DrawingPath.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _paths = loadedPaths;
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingImage) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_image == null) {
      return const Center(
        child: Text(
          'Failed to load image',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Show image with paths overlay, centered with proper aspect ratio
    // Allow drawing paths to extend beyond image bounds
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate display size to preserve aspect ratio
        final imageAspect = _image!.width / _image!.height;
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
        
        // Calculate where the image should be displayed (centered)
        final imageRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: displayWidth,
          height: displayHeight,
        );
        
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              // Centered shadow box (non-interactive)
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
              // Image and paths (no InteractiveViewer here - it's at the page level)
              CustomPaint(
                painter: _ImageWithPathsPainter(
                  image: _image!,
                  paths: _paths,
                  imageDisplayRect: imageRect,
                ),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter that draws image with paths overlay
class _ImageWithPathsPainter extends CustomPainter {
  final ui.Image image;
  final List<DrawingPath> paths;
  final Rect imageDisplayRect;

  _ImageWithPathsPainter({
    required this.image,
    required this.paths,
    required this.imageDisplayRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image in the specified display rect
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, srcRect, imageDisplayRect, Paint());

    // Draw all paths - they're stored in display coordinates, so draw them directly
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
           oldDelegate.imageDisplayRect != imageDisplayRect;
  }
}

/// Widget that displays a digital page (FleatherEditor) with drawing paths overlaid
class _DigitalPageWithPathsWidget extends StatefulWidget {
  final FleatherController controller;
  final bool editorInitialized;
  final String? documentId;
  final int pageIndex;

  const _DigitalPageWithPathsWidget({
    required this.controller,
    required this.editorInitialized,
    required this.documentId,
    required this.pageIndex,
  });

  @override
  State<_DigitalPageWithPathsWidget> createState() => _DigitalPageWithPathsWidgetState();
}

class _DigitalPageWithPathsWidgetState extends State<_DigitalPageWithPathsWidget> {
  List<DrawingPath> _paths = [];

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    // Only load paths if we have documentId
    if (widget.documentId == null) {
      return;
    }

    try {
      final authService = AuthService();
      final result = await authService.getDrawingList(
        widget.documentId!,
        widget.pageIndex,
      );

      if (result.success && result.drawingList != null && mounted) {
        final loadedPaths = result.drawingList!
            .map((json) => DrawingPath.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _paths = loadedPaths;
        });
      }
    } catch (e) {
      // Silently fail - no paths to display
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfffafafa),
      child: Stack(
        children: [
          // Base layer: Fleather editor
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: widget.editorInitialized
                  ? FleatherEditor(controller: widget.controller)
                  : const SizedBox.shrink(),
            ),
          ),
          // Overlay layer: Drawing paths (non-interactive)
          if (_paths.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DigitalPagePathsPainter(paths: _paths),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter that draws only the paths (for digital pages)
class _DigitalPagePathsPainter extends CustomPainter {
  final List<DrawingPath> paths;

  _DigitalPagePathsPainter({
    required this.paths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all paths
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
  bool shouldRepaint(_DigitalPagePathsPainter oldDelegate) {
    return oldDelegate.paths.length != paths.length;
  }
}

/// Custom InteractiveViewer that only responds to two-finger gestures
/// This prevents conflicts with one-finger page swiping in PageView
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
    // Only respond to 2+ finger gestures (scale != 1.0 means pinch, or pointerCount >= 2 means pan)
    if (_pointerCount < 2) {
      return; // Ignore one-finger gestures
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
