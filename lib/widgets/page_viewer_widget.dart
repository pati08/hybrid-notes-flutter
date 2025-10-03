import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../models/document_page_data.dart';

/// Optimized page viewer widget with RepaintBoundary for smooth scrolling
class PageViewerWidget extends StatefulWidget {
  final List<DocumentPageData> pages;
  final PageController pageController;
  final Function(int) onPageChanged;

  const PageViewerWidget({
    super.key,
    required this.pages,
    required this.pageController,
    required this.onPageChanged,
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

  const _PageContentWidget({
    required this.page,
    required this.index,
    required this.isTransitioning,
    required this.canInitializeEditor,
    required this.currentPageIndex,
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
      // Image page
      pageContent = Container(
        color: Colors.black,
        child: page.imageBytes != null
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.memory(
                    page.imageBytes!,
                    fit: BoxFit.contain,
                    // Prevent image from being rebuilt unnecessarily
                    gaplessPlayback: true,
                    // Use cacheWidth to reduce memory usage for large images
                    cacheWidth: 2048,
                    // Prevent unnecessary decoder rebuilds
                    isAntiAlias: false,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: pageContent,
        ),
      ),
    );
  }
}
