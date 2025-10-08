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
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        controller: widget.pageController,
        itemCount: widget.pages.length,
        onPageChanged: widget.onPageChanged,
        // Optimize scrolling physics for smoothness
        physics: const PageScrollPhysics(),
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
              isTransitioning: _isTransitioning,
              canInitializeEditor: _initializedPages.contains(index),
              currentPageIndex: _settledPageIndex,
              documentId: widget.documentId,
            ),
          );
        },
      ),
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

  const _PageContentWidget({
    required this.page,
    required this.index,
    required this.isTransitioning,
    required this.canInitializeEditor,
    required this.currentPageIndex,
    this.documentId,
  });

  @override
  State<_PageContentWidget> createState() => _PageContentWidgetState();
}

class _PageContentWidgetState extends State<_PageContentWidget> {
  bool _editorInitialized = false;
  bool _initializationScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitializeEditor();
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
      // Digital page with text editor
      // Only show the editor after initialization to prevent animation stutter
      pageContent = RepaintBoundary(
        child: Container(
          color: const Color(0xfffafafa),
          padding: const EdgeInsets.all(16.0),
          child: _editorInitialized
              ? FleatherEditor(controller: page.controller!)
              : const SizedBox.shrink(), // Empty widget while transitioning
        ),
      );
    } else if (page.type == 'ImagePage') {
      // Image page with drawing overlay
      pageContent = Container(
        color: Colors.black,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading image...',
                      style: TextStyle(color: Colors.white),
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

    // Wrap each page in a floating card
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 32.0,
      ),
      child: Card(
        elevation: 8,
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
      debugPrint('Error loading image: $e');
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
      debugPrint('Error loading paths for page ${widget.pageIndex}: $e');
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

    // Show image with paths overlay
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CustomPaint(
          painter: _ImageWithPathsPainter(
            image: _image!,
            paths: _paths,
          ),
          child: SizedBox(
            width: _image!.width.toDouble(),
            height: _image!.height.toDouble(),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws image with paths overlay
class _ImageWithPathsPainter extends CustomPainter {
  final ui.Image image;
  final List<DrawingPath> paths;

  _ImageWithPathsPainter({
    required this.image,
    required this.paths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw all paths on top
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
           oldDelegate.paths.length != paths.length;
  }
}
