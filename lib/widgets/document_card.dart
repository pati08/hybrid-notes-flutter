import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/document_preview_service.dart';
import '../services/document_metadata_service.dart';

/// Simple document card widget without complex animations
class DocumentCard extends StatefulWidget {
  final String documentId;
  final String title;
  final bool isCreateNew;
  final Function(Rect previewRect, Uint8List? previewImage)? onTap;
  final VoidCallback? onDelete;
  final int refreshKey;
  final bool wasModified;
  final int? lastModified;

  const DocumentCard({
    super.key,
    required this.documentId,
    required this.title,
    this.isCreateNew = false,
    required this.onTap,
    this.onDelete,
    this.refreshKey = 0,
    this.wasModified = false,
    this.lastModified,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;
  bool _hasError = false;
  String? _currentDocumentId; // Track the document ID for the current preview
  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.isCreateNew) {
      _loadPreview();
    }
  }

  @override
  void didUpdateWidget(DocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Clear preview if document ID changed (document reordered)
    if (oldWidget.documentId != widget.documentId) {
      _currentDocumentId = null;
      _previewBytes = null;
      _hasError = false;
      _isLoadingPreview = false;
    }
    
    // Reload preview if this specific document was modified
    if (oldWidget.refreshKey != widget.refreshKey &&
        widget.wasModified &&
        !widget.isCreateNew) {
      _loadPreview();
    }
    
    // Load preview if we don't have one yet
    if (!widget.isCreateNew && _previewBytes == null && !_isLoadingPreview) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    if (widget.isCreateNew) return;

    if (!mounted) return;
    
    // Set the current document ID to track this preview request
    final currentDocumentId = widget.documentId;
    _currentDocumentId = currentDocumentId;
    
    setState(() {
      _isLoadingPreview = true;
      _hasError = false;
    });

    try {
      final previewService = DocumentPreviewService();
      final preview = await previewService.generatePreview(currentDocumentId);

      if (!mounted) return;
      
      // Only update if this is still the correct document (prevent race condition)
      if (_currentDocumentId == currentDocumentId) {
        setState(() {
          _previewBytes = preview;
          _isLoadingPreview = false;
          _hasError = preview == null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      // Only update if this is still the correct document (prevent race condition)
      if (_currentDocumentId == currentDocumentId) {
        setState(() {
          _isLoadingPreview = false;
          _hasError = true;
        });
      }
    }
  }

  void _handleTap() {
    if (_previewKey.currentContext != null) {
      final RenderBox renderBox = _previewKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final previewRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
      
      widget.onTap!(previewRect, _previewBytes);
    } else {
      // Fallback if we can't get the bounds
      widget.onTap!(Rect.zero, _previewBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.isCreateNew) {
          widget.onTap?.call(Rect.zero, null);
        } else {
          _handleTap();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xfff0f0f0),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              spreadRadius: 1,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.isCreateNew) ...[
                    _buildCreateNewContent(),
                  ] else ...[
                    _buildDocumentContent(),
                  ],
                ],
              ),
            ),
            // Delete button
            if (!widget.isCreateNew && widget.onDelete != null)
              _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.add_outlined,
          size: 50,
          color: Color(0xff133223),
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xff133223),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDocumentContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview area
        Flexible(
          child: Container(
            key: _previewKey,
            width: double.infinity,
            height: 120, // Fixed height for preview
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildPreviewContent(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Title
        Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xff133223),
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        const SizedBox(height: 4),
        // Last modified
        Text(
          _getLastModifiedText(),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    if (_isLoadingPreview) {
      return _buildLoadingIndicator();
    }

    if (_hasError) {
      return _buildErrorIcon();
    }

    if (_previewBytes != null) {
      return Image.memory(
        _previewBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorIcon();
        },
      );
    }

    return _buildFallbackIcon();
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xff133223)),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.red,
          ),
          SizedBox(height: 8),
          Text(
            'Preview Error',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 50,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'No Preview',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  String _getLastModifiedText() {
    if (widget.lastModified == null) {
      return 'Unknown';
    }
    
    try {
      final metadataService = DocumentMetadataService();
      final lastModified = DateTime.fromMillisecondsSinceEpoch(widget.lastModified!);
      return metadataService.formatLastModified(lastModified);
    } catch (e) {
      return 'Unknown';
    }
  }
}