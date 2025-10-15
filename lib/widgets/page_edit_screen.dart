import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import '../models/document_page_data.dart';

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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // For image pages, don't show any interface
    if (widget.page.type == 'ImagePage') {
      return Container();
    }

    // For digital pages, show typing interface with optional drawing overlay
    return _DigitalPageEditScreen(
      page: widget.page,
      documentId: widget.documentId,
      pageIndex: widget.pageIndex,
    );
  }
}

/// Edit screen for digital pages with typing and optional drawing
class _DigitalPageEditScreen extends StatefulWidget {
  final DocumentPageData page;
  final String? documentId;
  final int? pageIndex;

  const _DigitalPageEditScreen({
    required this.page,
    required this.documentId,
    required this.pageIndex,
  });

  @override
  State<_DigitalPageEditScreen> createState() => _DigitalPageEditScreenState();
}

class _DigitalPageEditScreenState extends State<_DigitalPageEditScreen> {
  @override
  void initState() {
    super.initState();
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
        title: Text('Edit Page'),
        backgroundColor: const Color(0xff102837),
        foregroundColor: Colors.white,
        actions: [
          // Save button
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xffc7ffbf)),
            onPressed: () async {
              Navigator.pop(context, true);
            },
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          // Show text toolbar only in typing mode
          ResponsiveFleatherToolbar(controller: widget.page.controller!),
          // Editor/Canvas
          Expanded(
            child: Container(
              color: const Color(0xfffafafa),
              child: Stack(
                children: [
                  // Text editor (always present, but disabled in drawing mode)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          FleatherEditor(controller: widget.page.controller!),
                    ),
                  ),
                  // Drawing layer (only interactive in drawing mode)
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: FleatherToolbar.basic(controller: controller),
      ),
    );
  }
}
