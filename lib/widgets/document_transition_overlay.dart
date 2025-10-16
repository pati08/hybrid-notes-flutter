import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that creates a smooth transition animation from a document preview
/// to the full document view by duplicating the preview and animating it
class DocumentTransitionOverlay extends StatefulWidget {
  final Rect sourceRect;
  final Uint8List? previewImage;
  final String documentTitle;
  final VoidCallback onTransitionComplete;
  final Widget child;

  const DocumentTransitionOverlay({
    super.key,
    required this.sourceRect,
    required this.previewImage,
    required this.documentTitle,
    required this.onTransitionComplete,
    required this.child,
  });

  @override
  State<DocumentTransitionOverlay> createState() => _DocumentTransitionOverlayState();
}

class _DocumentTransitionOverlayState extends State<DocumentTransitionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  bool _showOverlay = true;
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    
    // Create animation controller with a reasonable duration
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Initialize animations with default values - will be updated in didChangeDependencies
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _positionAnimation = Tween<Offset>(
      begin: Offset(widget.sourceRect.left, widget.sourceRect.top),
      end: Offset(widget.sourceRect.left, widget.sourceRect.top),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.7, 1.0), // Start fading out at 70% of animation
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Calculate target position and scale now that context is available
    final screenSize = MediaQuery.of(context).size;
    final targetScale = screenSize.width / widget.sourceRect.width;
    final targetOffset = Offset(
      screenSize.width / 2 - widget.sourceRect.width / 2,
      screenSize.height / 2 - widget.sourceRect.height / 2,
    );

    // Update animations with correct target values
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: targetScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _positionAnimation = Tween<Offset>(
      begin: Offset(widget.sourceRect.left, widget.sourceRect.top),
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start the animation after dependencies are set
    _startAnimation();
  }

  void _startAnimation() async {
    // Wait a frame to ensure the overlay is rendered
    await Future.delayed(const Duration(milliseconds: 16));
    
    if (mounted) {
      _animationController.forward().then((_) {
        if (mounted) {
          setState(() {
            _showOverlay = false;
            _showChild = true;
          });
          widget.onTransitionComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // The actual document view
          if (_showChild) widget.child,
          
          // The animated overlay
          if (_showOverlay && widget.previewImage != null)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Positioned(
                  left: _positionAnimation.value.dx,
                  top: _positionAnimation.value.dy,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: widget.sourceRect.width,
                        height: widget.sourceRect.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            widget.previewImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}