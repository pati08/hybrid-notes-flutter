import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:fleather/fleather.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'models/document_page_data.dart';
import 'services/image_cache_service.dart';
import 'services/document_preview_service.dart';
import 'services/document_metadata_service.dart';
import 'widgets/continuous_canvas_viewer.dart';
import 'widgets/image_drawing_screen.dart';
import 'widgets/document_card.dart';
import 'widgets/document_transition_overlay.dart';

void main() {
  runApp(const MyApp());
}

// Global route observer for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AuthCheckScreen(),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
    );
  }
}

// ---------------- AUTH CHECK SCREEN ----------------
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = AuthService();
    final isAuthenticated = await authService.isAuthenticated();

    if (mounted) {
      if (isAuthenticated) {
        // User is logged in, get stored user info
        final phone = await authService.getPhone() ?? '';
        final countryCode = await authService.getCountryCode() ?? '';

        // User is logged in, go to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              phone: phone,
              countryCode: countryCode,
            ),
          ),
        );
      } else {
        // User is not logged in, go to PhoneAuthScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff102837)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xff102837),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- PHONE AUTH SCREEN ----------------
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController(
    text: '1',
  ); // Default country code

  final ScrollController _scrollController = ScrollController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _countryCodeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => _scrollToFocusedField(_phoneFocus));
    _countryCodeFocus
        .addListener(() => _scrollToFocusedField(_countryCodeFocus));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _phoneFocus.dispose();
    _countryCodeFocus.dispose();
    phoneController.dispose();
    countryCodeController.dispose();
    super.dispose();
  }

  void _scrollToFocusedField(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      // Small delay to ensure keyboard is fully shown
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent *
                0.8, // Scroll to ~80% of available scroll
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _handleContinue() async {
    final phoneNumber = phoneController.text.trim();
    final countryCode = countryCodeController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (countryCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your country code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Combine country code and phone number
    final fullPhoneNumber = '+$countryCode$phoneNumber';

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff102837)),
          ),
        ),
      );

      final authService = AuthService();
      final result = await authService.sendPhoneVerification(fullPhoneNumber);

      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        // Store phone info for later use
        await authService.storeUserInfo(phoneNumber, countryCode);

        // Navigate to verification screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CodeVerificationPage(phone: fullPhoneNumber),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to send verification code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Enter your phone number to get started',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff102837),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // PHONE input
              const Text(
                'PHONE NUMBER',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('+', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.zero,
                    ),
                    child: TextField(
                      controller: countryCodeController,
                      focusNode: _countryCodeFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 26),
                        border: InputBorder.none,
                      ),
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _phoneFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.zero,
                      ),
                      child: TextField(
                        controller: phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [PhoneNumberFormatter()],
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 26,
                            horizontal: 12,
                          ),
                          hintText: '##########',
                          border: InputBorder.none,
                        ),
                        textAlign: TextAlign.center,
                        onSubmitted: (_) => _handleContinue(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff102837),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- CODE VERIFICATION SCREEN ----------------
class CodeVerificationPage extends StatefulWidget {
  final String phone;

  const CodeVerificationPage({super.key, required this.phone});

  @override
  _CodeVerificationPageState createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  final TextEditingController codeController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final FocusNode _codeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(() => _scrollToFocusedField(_codeFocus));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _codeFocus.dispose();
    codeController.dispose();
    super.dispose();
  }

  void _scrollToFocusedField(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      // Small delay to ensure keyboard is fully shown
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent *
                0.8, // Scroll to ~80% of available scroll
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _handleVerifyCode() async {
    if (codeController.text.length == 6) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Call API to verify code
      final authService = AuthService();
      final result = await authService.verifyCode(
        widget.phone,
        codeController.text,
      );

      // Hide loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      if (result.success) {
        // Token is already stored by AuthService
        // Extract country code from phone number
        // For "+1234567890", we want "1" (everything after + except last 10 digits)
        String countryCode =
            widget.phone.substring(1, widget.phone.length - 10);

        // Store user info for future app launches
        await authService.storeUserInfo(widget.phone, countryCode);

        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                phone: widget.phone,
                countryCode: countryCode,
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Verification failed'),
              backgroundColor: const Color(0xffbd6051),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Color(0xffbd6051),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title: const Text('Verify Code',
            style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: const Color(0xfff0f0f0),
        iconTheme: const IconThemeData(color: Color(0xff1c1c1c)),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Color(0xff102837)),
              const SizedBox(height: 24),
              const Text(
                'Verification Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff102837),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ve sent a 6-digit code to',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.phone,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff102837),
                ),
              ),
              const SizedBox(height: 48),

              // Code input
              const Text(
                '6-DIGIT CODE',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: codeController,
                  focusNode: _codeFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    hintStyle: const TextStyle(fontSize: 32, letterSpacing: 8),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  obscureText: false,
                  onSubmitted: (_) => _handleVerifyCode(),
                ),
              ),

              const SizedBox(height: 32),

              // Resend code option
              TextButton(
                onPressed: () async {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  // Call API to resend verification code
                  final authService = AuthService();
                  final result =
                      await authService.sendPhoneVerification(widget.phone);

                  // Hide loading indicator
                  Navigator.pop(context);

                  if (result.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verification code sent!'),
                        backgroundColor: Color(0xffc7ffbf),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.error ?? 'Failed to resend code'),
                        backgroundColor: const Color(0xffbd6051),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Didn\'t receive the code? Resend',
                  style: TextStyle(
                    color: Color(0xffc3e3ea),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleVerifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff102837),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'Verify & Log in',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

http.Response returnJSON() {
  final fakeBody = jsonEncode({
    "documents": [
      {"title": "Sample Doc 1"},
      {"title": "Sample Doc 2"},
    ],
  });

  return http.Response(fakeBody, 200); // Mimics a real HTTP response
}

// ---------------- HOME SCREEN ----------------
class HomeScreen extends StatefulWidget {
  final String phone;
  final String countryCode;

  const HomeScreen({
    super.key,
    required this.phone,
    required this.countryCode,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<Map<String, dynamic>> documents = []; // user-created documents
  bool isLoadingDocuments = true;
  String? apiError;
  List<dynamic>? apiDocumentsList;
  int _previewRefreshKey = 0; // Key to force preview refresh
  Set<String> _modifiedDocumentIds = {}; // Track which documents were modified

  @override
  void initState() {
    super.initState();
    // Send HTTP request as soon as user navigates to HomeScreen
    sendRequestWithCookie();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes using the global routeObserver
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when user returns to this screen from another screen
    // Only invalidate previews for modified documents
    final modifiedDocuments = DocumentPreviewService().getModifiedDocuments();
    DocumentPreviewService().invalidateModifiedPreviews();

    // Track which documents were modified for selective rebuilding
    if (modifiedDocuments.isNotEmpty) {
      setState(() {
        _modifiedDocumentIds = modifiedDocuments;
        _previewRefreshKey++;
      });
    }

    // Refresh the documents list with a small delay to ensure server changes are reflected
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        sendRequestWithCookie();
      }
    });
  }

  Future<void> sendRequestWithCookie() async {
    if (!mounted) return;

    try {
      // Single setState call for loading state
      setState(() {
        isLoadingDocuments = true;
        apiError = null;
      });

      // Use AuthService to list documents
      final authService = AuthService();
      final result = await authService.listDocuments();

      if (!mounted) return;

      if (result.success && result.documents != null) {
        // Initialize metadata for documents that don't have it
        final metadataService = DocumentMetadataService();
        await metadataService.initializeMissingMetadata(
            result.documents!.cast<Map<String, dynamic>>());

        // Get documents sorted by last modified time
        final sortedDocuments =
            await metadataService.getDocumentsSortedByLastModified(
                result.documents!.cast<Map<String, dynamic>>());

        if (!mounted) return;

        // Single setState call for success state
        setState(() {
          apiDocumentsList = sortedDocuments;
          // Populate the documents list from sorted API data
          documents = sortedDocuments
              .map((doc) {
                return {
                  'id': doc['id']?.toString() ?? '',
                  'title': doc['localTitle']?.toString() ??
                      doc['name']?.toString() ??
                      'Untitled',
                  'lastModified': doc['lastModified'],
                };
              })
              .toList()
              .cast<Map<String, dynamic>>();
          isLoadingDocuments = false;
        });
      } else {
        if (!mounted) return;

        // Single setState call for error state
        setState(() {
          apiError = result.error ?? 'Failed to load documents';
          isLoadingDocuments = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      // Single setState call for exception state
      setState(() {
        apiError = 'Error occurred: $e';
        isLoadingDocuments = false;
      });
    }
  }

  Future<void> addDocument(String title) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final authService = AuthService();
      final result = await authService.createDocument(title);

      // Hide loading indicator
      Navigator.pop(context);

      if (result.success && result.document != null) {
        // Initialize metadata for the new document
        final metadataService = DocumentMetadataService();
        final documentId = result.document!['id']?.toString() ?? '';
        await metadataService.updateLastModified(documentId, title: title);

        if (mounted) {
          setState(() {
            documents.add({
              'id': documentId,
              'title': title,
              'lastModified': DateTime.now().millisecondsSinceEpoch,
            });
          });
        }

        // Navigate to the new document
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentPage(
                documentId: result.document!['id']?.toString() ?? '',
                title: result.document!['name']?.toString() ?? title,
              ),
            ),
          ).then((wasModified) async {
            // Refresh document list when returning from editing
            if (wasModified == true) {
              await sendRequestWithCookie();
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to create document'),
              backgroundColor: const Color(0xffbd6051),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating document: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(
      BuildContext context, String documentId, String documentTitle) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete Document',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    'Are you sure you want to delete "$documentTitle"? This action cannot be undone.'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final authService = AuthService();
      final result = await authService.deleteDocument(documentId);

      // Hide loading indicator
      Navigator.pop(context);

      if (result.success) {
        if (mounted) {
          // Remove document from local list
          setState(() {
            documents.removeWhere((doc) => doc['id'] == documentId);
          });

          // Clear preview cache for deleted document
          DocumentPreviewService().removeFromCache(documentId);

          // Remove metadata for deleted document
          final metadataService = DocumentMetadataService();
          await metadataService.removeDocumentMetadata(documentId);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document "$documentTitle" deleted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to delete document'),
              backgroundColor: const Color(0xffbd6051),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Example method to upload an attachment
  Future<void> uploadFileExample(List<int> fileBytes, String fileName) async {
    try {
      final authService = AuthService();
      final result = await authService.uploadAttachment(fileName, fileBytes);

      if (result.success) {
        // Store attachmentId for later use
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: const Color(0xffbd6051),
        ),
      );
    }
  }

  // Example method to download an attachment
  Future<void> downloadFileExample(String attachmentId) async {
    try {
      final authService = AuthService();
      final result = await authService.downloadAttachment(attachmentId);

      if (result.success) {
        // Use result.fileBytes for the downloaded file
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${result.error}'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: const Color(0xffbd6051),
        ),
      );
    }
  }

  Future<void> _startScanning() async {
    try {
      final List<String>? images = await CunningDocumentScanner.getPictures();
      if (images == null || images.isEmpty)
        return; // user cancelled or no images

      // Collect image bytes
      final List<Uint8List> scannedImages = [];
      for (final path in images) {
        final f = File(path);
        if (await f.exists()) {
          scannedImages.add(await f.readAsBytes());
        }
      }

      if (scannedImages.isEmpty) return;

      // Navigate to options page with scanned images
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScannedDocumentOptionsPage(
              scannedImages: scannedImages,
              existingDocuments: documents,
            ),
          ),
        ).then((_) {
          // Refresh documents list when returning
          sendRequestWithCookie();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanner error: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedDocuments = [
      {"title": "Create New"},
      ...documents,
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        centerTitle: true,
        backgroundColor: const Color(0xfff0f0f0),
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: const Color(0xfff0f0f0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Home',
              style: TextStyle(
                color: Color(0xff133223),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Show loading indicator or status in app bar
            if (isLoadingDocuments)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff133223)),
                ),
              )
            else if (apiError != null)
              const Icon(Icons.error_outline,
                  size: 16, color: Color(0xffbd6051))
            else
              const Icon(Icons.check_circle_outline,
                  size: 16, color: Color(0xffc7ffbf)),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 40, color: Color(0xff133223)),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffc3e3ea),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.document_scanner,
                    size: 40,
                    color: Color(0xff102837),
                  ),
                  onPressed: () => _startScanning(),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xfffafafa),
      drawer: Align(
        alignment: Alignment.center,
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.zero, // Sharp edges
          child: Container(
            height: MediaQuery.of(context).size.height * 0.45,
            width: 300,
            decoration: BoxDecoration(
              color: const Color(0xffdfdfdf),
              borderRadius: BorderRadius.zero, // Sharp edges
            ),
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const DrawerHeader(
                      decoration: BoxDecoration(
                        color: Color(0xffdcdcdc),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text(
                            'Menu',
                            style: TextStyle(
                              fontFamily: 'LibreBaskerville',
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1c1c1c),
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.person, color: Color(0xff1c1c1c)),
                      title: const Text(
                        'Profile',
                        style: TextStyle(color: Color(0xff1c1c1c)),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (mounted) {
                          // Check before navigation
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfilePage(
                                phone: widget.phone,
                                countryCode: widget.countryCode,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Color(0xff1c1c1c)),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(color: Color(0xff1c1c1c)),
                      ),
                      onTap: () async {
                        // Clear authentication token
                        final authService = AuthService();
                        await authService.clearToken();

                        if (mounted) {
                          // Check before navigation
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const PhoneAuthScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
                // Close button positioned in top-right corner
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Color(0xff133233), size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Show API status or error message
              if (apiError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xffbd6051).withOpacity(0.1),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                        color: const Color(0xffbd6051).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Color(0xffbd6051)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          apiError!,
                          style: const TextStyle(color: Color(0xffbd6051)),
                        ),
                      ),
                      TextButton(
                        onPressed: sendRequestWithCookie,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: displayedDocuments.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 25,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final docTitle = displayedDocuments[index]['title']!;
                    final docId = displayedDocuments[index]['id'] ?? '';
                    final isCreateNew = docTitle == 'Create New';

                    return DocumentCard(
                      documentId: docId,
                      title: docTitle,
                      isCreateNew: isCreateNew,
                      refreshKey: _previewRefreshKey,
                      wasModified: _modifiedDocumentIds.contains(docId),
                      lastModified: displayedDocuments[index]['lastModified'],
                      onTap: (Rect previewRect, Uint8List? previewImage) async {
                        if (isCreateNew) {
                          String? newTitle = await showDialog(
                            context: context,
                            builder: (_) => NewDocumentDialog(),
                          );
                          if (newTitle != null &&
                              newTitle.isNotEmpty &&
                              mounted) {
                            await addDocument(newTitle);
                          }
                        } else {
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentTransitionOverlay(
                                  sourceRect: previewRect,
                                  previewImage: previewImage,
                                  documentTitle: docTitle,
                                  onTransitionComplete: () {
                                    // Transition completed, overlay will be removed
                                  },
                                  child: DocumentPage(
                                    documentId: docId,
                                    title: docTitle,
                                  ),
                                ),
                              ),
                            ).then((wasModified) async {
                              // Refresh document list when returning from editing
                              if (wasModified == true) {
                                await sendRequestWithCookie();
                              }
                            });
                          }
                        }
                      },
                      onDelete: isCreateNew
                          ? null
                          : () async {
                              await _deleteDocument(context, docId, docTitle);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onReturnToSignUp;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    required this.onReturnToSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xffbd6051), size: 80),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xffbd6051),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Clear authentication token on error return
                  final authService = AuthService();
                  await authService.clearToken();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Return to Sign Up',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- RESPONSIVE TOOLBAR ----------------
class ResponsiveFleatherToolbar extends StatelessWidget {
  final FleatherController controller;

  const ResponsiveFleatherToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should show compact toolbar based on screen width
        // Use a more conservative breakpoint for better mobile experience
        final isCompact = constraints.maxWidth < 800;

        if (isCompact) {
          return CompactToolbar(controller: controller);
        } else {
          return FleatherToolbar.basic(controller: controller);
        }
      },
    );
  }
}

class CompactToolbar extends StatefulWidget {
  final FleatherController controller;

  const CompactToolbar({
    super.key,
    required this.controller,
  });

  @override
  State<CompactToolbar> createState() => _CompactToolbarState();
}

class _CompactToolbarState extends State<CompactToolbar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        border: const Border(
          bottom: BorderSide(color: Color(0xffc3e3ea), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row - Text formatting
          SizedBox(
            height: 44,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToolbarButton(
                      icon: Icons.format_bold,
                      tooltip: 'Bold',
                      onPressed: () => _toggleFormat(ParchmentAttribute.bold),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_italic,
                      tooltip: 'Italic',
                      onPressed: () => _toggleFormat(ParchmentAttribute.italic),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_underlined,
                      tooltip: 'Underline',
                      onPressed: () =>
                          _toggleFormat(ParchmentAttribute.underline),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_strikethrough,
                      tooltip: 'Strikethrough',
                      onPressed: () =>
                          _toggleFormat(ParchmentAttribute.strikethrough),
                    ),
                    _buildToolbarButton(
                      icon: Icons.integration_instructions,
                      tooltip: 'Inline Code',
                      onPressed: () =>
                          _toggleFormat(ParchmentAttribute.inlineCode),
                    ),
                    _buildToolbarButton(
                      icon: Icons.link,
                      tooltip: 'Add Link',
                      onPressed: () => _showLinkDialog(),
                    ),
                    _buildToolbarButton(
                      icon: Icons.image,
                      tooltip: 'Upload Image',
                      onPressed: () => _uploadImage(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Second row - Lists, blocks, and alignment
          Container(
            height: 44,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xffc3e3ea), width: 1),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToolbarButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Bullet List',
                      onPressed: () => _toggleFormat(ParchmentAttribute.ul),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_list_numbered,
                      tooltip: 'Numbered List',
                      onPressed: () => _toggleFormat(ParchmentAttribute.ol),
                    ),
                    _buildToolbarButton(
                      icon: Icons.checklist,
                      tooltip: 'Check List',
                      onPressed: () => _toggleFormat(ParchmentAttribute.cl),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_quote,
                      tooltip: 'Quote Block',
                      onPressed: () => _toggleFormat(ParchmentAttribute.bq),
                    ),
                    _buildToolbarButton(
                      icon: Icons.code,
                      tooltip: 'Code Block',
                      onPressed: () => _toggleFormat(ParchmentAttribute.code),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_align_left,
                      tooltip: 'Align Left',
                      onPressed: () => _toggleFormat(ParchmentAttribute.left),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_align_center,
                      tooltip: 'Align Center',
                      onPressed: () => _toggleFormat(ParchmentAttribute.center),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_align_right,
                      tooltip: 'Align Right',
                      onPressed: () => _toggleFormat(ParchmentAttribute.right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xff102837),
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }

  void _toggleFormat(ParchmentAttribute attribute) {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) {
      // Apply format to the current selection or insert at cursor
      widget.controller.formatSelection(attribute);
    } else {
      // Toggle format for selected text
      widget.controller.formatSelection(attribute);
    }
  }

  void _showLinkDialog() {
    final TextEditingController linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        title: const Text('Add Link'),
        content: TextField(
          controller: linkController,
          decoration: const InputDecoration(
            hintText: 'Enter URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (linkController.text.isNotEmpty) {
                widget.controller.formatSelection(
                  ParchmentAttribute.link.fromString(linkController.text),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _uploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Read image bytes
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();

        // Upload image
        final authService = AuthService();
        final result =
            await authService.uploadAttachment(image.name, imageBytes);

        // Hide loading dialog
        Navigator.pop(context);

        if (result.success) {
          // Store the attachment ID for this document
          await _storeImageAttachmentId(result.attachmentId!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${result.error}'),
              backgroundColor: const Color(0xffbd6051),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: const Color(0xffbd6051),
        ),
      );
    }
  }

  Future<void> _storeImageAttachmentId(String attachmentId) async {
    // Store attachment ID in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final List<String> imageIds = prefs.getStringList('document_images') ?? [];
    imageIds.add(attachmentId);
    await prefs.setStringList('document_images', imageIds);
  }
}

// ---------------- DOCUMENT PAGE DATA MODEL ----------------
// ---------------- DOCUMENT & SCAN PAGES ----------------
class DocumentPage extends StatefulWidget {
  final String documentId;
  final String title;
  final List<String>? initialImagePages;

  const DocumentPage({
    super.key,
    required this.documentId,
    required this.title,
    this.initialImagePages,
  });

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  late TextEditingController _titleController;
  bool _isEditingTitle = false;
  bool _isLoading = true;
  String? _loadError;

  // List of pages (each can be DigitalPage or ImagePage)
  List<DocumentPageData> _pages = [];
  int _currentPageIndex = 0;
  late ValueNotifier<int>
      _pageIndexNotifier; // For instant UI updates without setState

  // Auto-save timer
  Timer? _autoSaveTimer;
  DateTime? _lastSaveTime;
  bool _isSaving = false; // Prevent concurrent saves

  // Track when to refresh image paths (increment to force reload)
  int _imageRefreshCounter = 0;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.title);
    _pageIndexNotifier = ValueNotifier<int>(0);

    // Listen to page index changes
    _pageIndexNotifier.addListener(() {
      if (mounted && _pageIndexNotifier.value != _currentPageIndex) {
        setState(() {
          _currentPageIndex = _pageIndexNotifier.value;
        });
      }
    });

    // Start periodic auto-save (every 30 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDocument(showFeedback: false);
    });

    // Load document from API
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });

      final authService = AuthService();
      final result = await authService.getDocument(widget.documentId);

      if (result.success && result.document != null) {
        // Parse pages and load them
        final pages = result.document!['pages'] as List<dynamic>?;

        List<DocumentPageData> loadedPages = [];
        List<String> imageAttachmentIds = [];

        if (pages != null && pages.isNotEmpty) {
          // Debug: Log all page IDs and their order
          final pageIds =
              pages.map((p) => p['id']?.toString() ?? 'null').toList();
          debugPrint(
              'Main: Document ${widget.documentId} has ${pages.length} pages with IDs: $pageIds');
          // First pass: collect all image attachment IDs
          for (var page in pages) {
            final pageType = page['page_type'];
            if (pageType != null && pageType['type'] == 'ImagePage') {
              final imageUrl = pageType['image_url'] as String?;
              if (imageUrl != null) {
                imageAttachmentIds.add(imageUrl);
              }
            }
          }

          // Add initial image pages to preload list
          if (widget.initialImagePages != null) {
            imageAttachmentIds.addAll(widget.initialImagePages!);
          }

          // Preload ALL images concurrently before building UI
          if (imageAttachmentIds.isNotEmpty) {
            final imageCacheService = ImageCacheService();
            await imageCacheService.preloadImages(imageAttachmentIds);
          }

          // Second pass: build page data with cached images
          for (var page in pages) {
            final pageType = page['page_type'];

            if (pageType != null) {
              if (pageType['type'] == 'DigitalPage') {
                // Load the digital page content
                final pageId = page['id']?.toString();
                final quillJson = pageType['quill_json'];

                if (quillJson != null && quillJson.isNotEmpty) {
                  try {
                    // Parse the Quill JSON and create controller
                    final deltaJson = jsonDecode(quillJson);
                    final delta = Delta.fromJson(deltaJson);

                    final doc = ParchmentDocument.fromDelta(delta);
                    final controller = FleatherController(document: doc);

                    loadedPages.add(DocumentPageData.digital(
                        id: pageId, controller: controller));
                  } catch (e) {
                    // Add empty page if parsing fails
                    loadedPages.add(DocumentPageData.digital(id: pageId));
                  }
                } else {
                  // Empty digital page
                  loadedPages.add(DocumentPageData.digital(id: pageId));
                }
              } else if (pageType['type'] == 'ImagePage') {
                // Load the image page with cached data
                final pageId = page['id']?.toString();
                final imageUrl = pageType['image_url'] as String?;

                final imageCacheService = ImageCacheService();
                final cachedImage = imageUrl != null
                    ? imageCacheService.getCachedImage(imageUrl)
                    : null;

                loadedPages.add(DocumentPageData.image(
                  id: pageId,
                  imageUrl: imageUrl,
                  imageBytes: cachedImage,
                ));
              }
            }
          }
        }

        // If no pages loaded, add an empty digital page
        if (loadedPages.isEmpty) {
          loadedPages.add(DocumentPageData.digital());
        }

        // Add initial image pages if provided (from scanning)
        if (widget.initialImagePages != null &&
            widget.initialImagePages!.isNotEmpty) {
          final imageCacheService = ImageCacheService();
          // Preload scanned images before creating pages
          await imageCacheService.preloadImages(widget.initialImagePages!);

          for (final imageId in widget.initialImagePages!) {
            final cachedImage = imageCacheService.getCachedImage(imageId);
            loadedPages.add(DocumentPageData.image(
              imageUrl: imageId,
              imageBytes: cachedImage,
            ));
          }
        }

        setState(() {
          _pages = loadedPages;
          _isLoading = false;
          // If we added initial image pages, jump to the first one
          if (widget.initialImagePages != null &&
              widget.initialImagePages!.isNotEmpty) {
            _currentPageIndex =
                _pages.length - widget.initialImagePages!.length;
          }
        });

        // Auto-save after adding initial images
        if (widget.initialImagePages != null &&
            widget.initialImagePages!.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _saveDocument(showFeedback: false);
          });

          // Page index will be updated automatically by the notifier
        }
      } else {
        setState(() {
          _isLoading = false;
          _loadError = result.error ?? 'Failed to load document';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = 'Error loading document: $e';
      });
    }
  }

  @override
  void dispose() {
    // Save on exit
    _saveDocument(showFeedback: false);

    // Cancel auto-save timer
    _autoSaveTimer?.cancel();

    // Dispose controllers
    _titleController.dispose();
    _pageIndexNotifier.dispose();
    for (var page in _pages) {
      page.dispose();
    }

    super.dispose();
  }

  void _startEditingTitle() {
    setState(() {
      _isEditingTitle = true;
    });
    // Select all text for easy editing
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
  }

  Future<void> _saveTitle() async {
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty || newTitle == widget.title) {
      setState(() {
        _isEditingTitle = false;
      });
      return;
    }

    try {
      final authService = AuthService();
      final success =
          await authService.renameDocument(widget.documentId, newTitle);

      if (success) {
        setState(() {
          _isEditingTitle = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to rename document'),
              backgroundColor: Color(0xffbd6051),
            ),
          );
        }
        _cancelEditingTitle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming document: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _cancelEditingTitle();
    }
  }

  void _cancelEditingTitle() {
    setState(() {
      _isEditingTitle = false;
      _titleController.text = widget.title; // Reset to original title
    });
  }

  Future<void> _saveDocument({bool showFeedback = true}) async {
    // Prevent concurrent saves
    if (_isSaving) {
      debugPrint('Save: Already saving, skipping concurrent save');
      return;
    }

    _isSaving = true;

    try {
      debugPrint('Save: Starting save for document ${widget.documentId}');

      // Convert all pages to API format
      final pages = _pages.map((page) {
        if (page.type == 'DigitalPage' && page.controller != null) {
          final result = <String, dynamic>{
            'page_type': {
              'type': 'DigitalPage',
              'quill_json':
                  jsonEncode(page.controller!.document.toDelta().toJson()),
            }
          };
          if (page.id != null) {
            result['id'] = page.id;
          }
          return result;
        } else if (page.type == 'ImagePage' && page.imageUrl != null) {
          final result = <String, dynamic>{
            'page_type': {
              'type': 'ImagePage',
              'image_url': page.imageUrl,
            }
          };
          if (page.id != null) {
            result['id'] = page.id;
          }
          return result;
        } else {
          // Empty digital page fallback
          final result = <String, dynamic>{
            'page_type': {
              'type': 'DigitalPage',
              'quill_json': jsonEncode([
                {'insert': '\n'}
              ]),
            }
          };
          if (page.id != null) {
            result['id'] = page.id;
          }
          return result;
        }
      }).toList();

      final authService = AuthService();
      final success = await authService.saveDocument(widget.documentId, pages);

      if (success) {
        _lastSaveTime = DateTime.now();
        debugPrint('Save: Successfully saved document ${widget.documentId}');

        // Mark document as modified and invalidate its preview cache
        DocumentPreviewService().markDocumentAsModified(widget.documentId);
        DocumentPreviewService().invalidatePreview(widget.documentId);

        // Update last modified time in metadata
        final metadataService = DocumentMetadataService();
        await metadataService.updateLastModified(widget.documentId,
            title: widget.title);
      } else {
        debugPrint('Save: Failed to save document ${widget.documentId}');
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save document'),
              backgroundColor: Color(0xffbd6051),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Save: Error saving document ${widget.documentId}: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isSaving = false;
      debugPrint('Save: Finished save for document ${widget.documentId}');
    }
  }

  Future<void> _addDigitalPage() async {
    setState(() {
      _pages.add(DocumentPageData.digital());
      _currentPageIndex = _pages.length - 1;
      _pageIndexNotifier.value = _currentPageIndex;
    });

    // Auto-save after adding page
    await _saveDocument(showFeedback: false);
  }

  Future<void> _addImagePage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Read image bytes
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();

        // Upload image
        final authService = AuthService();
        final result =
            await authService.uploadAttachment(image.name, imageBytes);

        // Hide loading dialog
        Navigator.pop(context);

        if (result.success && result.attachmentId != null) {
          setState(() {
            _pages.add(DocumentPageData.image(
              imageUrl: result.attachmentId,
              imageBytes: Uint8List.fromList(imageBytes),
            ));
            _currentPageIndex = _pages.length - 1;
            _pageIndexNotifier.value = _currentPageIndex;
          });

          // Auto-save after adding image
          await _saveDocument(showFeedback: false);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${result.error}'),
                backgroundColor: const Color(0xffbd6051),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding image: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deletePage(int index) async {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last page'),
          backgroundColor: Color(0xffbd6051),
        ),
      );
      return;
    }

    setState(() {
      _pages[index].dispose();
      _pages.removeAt(index);

      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
      _pageIndexNotifier.value = _currentPageIndex;
    });

    // Auto-save after deleting
    await _saveDocument(showFeedback: false);
  }

  Future<void> _drawOnImage(int index) async {
    final page = _pages[index];

    // Check if we can draw on this page
    // For ImagePage, we need imageBytes to be loaded
    // For DigitalPage, we need a controller
    if (page.type == 'ImagePage' && page.imageBytes == null) {
      return;
    }
    if (page.type == 'DigitalPage' && page.controller == null) {
      return;
    }

    // Navigate to drawing screen with documentId and page index
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDrawingScreen(
          page: page,
          documentId: widget.documentId,
          pageIndex: index,
        ),
      ),
    );

    // If user saved the drawing, the paths are already saved via API
    if (result == true) {
      // Force refresh the page to reload the drawing paths
      if (mounted) {
        final currentPage = _currentPageIndex;

        setState(() {
          _imageRefreshCounter++;
        });

        // Restore the page position after rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _pageIndexNotifier.value = currentPage;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xfff0f0f0),
        appBar: AppBar(
          backgroundColor: const Color(0xfff0f0f0),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xfff0f0f0),
        appBar: AppBar(
          backgroundColor: const Color(0xfff0f0f0),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xffbd6051)),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                style: const TextStyle(color: Color(0xffbd6051)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDocument,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final currentPage = _pages.isNotEmpty ? _pages[_currentPageIndex] : null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        backgroundColor: const Color(0xfff0f0f0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            // Save before navigating back
            _saveDocument(showFeedback: false);
            Navigator.pop(
                context, true); // Return true to indicate document was modified
          },
        ),
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Document title',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
                autofocus: true,
                onSubmitted: (_) => _saveTitle(),
                onEditingComplete: _saveTitle,
              )
            : Text(
                _titleController.text.isEmpty
                    ? widget.title
                    : _titleController.text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
        actions: _isEditingTitle
            ? [
                IconButton(
                  icon: const Icon(Icons.check, color: Color(0xffc7ffbf)),
                  onPressed: _saveTitle,
                  tooltip: 'Save title',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xffbd6051)),
                  onPressed: _cancelEditingTitle,
                  tooltip: 'Cancel',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey[700]),
                  onPressed: _startEditingTitle,
                  tooltip: 'Edit title',
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.add, color: Colors.grey[700]),
                  tooltip: 'Add Page',
                  onSelected: (value) async {
                    if (value == 'digital') {
                      await _addDigitalPage();
                    } else if (value == 'image') {
                      await _addImagePage();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'digital',
                      child: Row(
                        children: [
                          Icon(Icons.article, color: Color(0xff102837)),
                          SizedBox(width: 8),
                          Text('Digital Page'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'image',
                      child: Row(
                        children: [
                          Icon(Icons.image, color: Color(0xff102837)),
                          SizedBox(width: 8),
                          Text('Image Page'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          // Continuous canvas view - zoom and pan around all pages
          Expanded(
            child: ContinuousCanvasViewer(
              key: ValueKey(_imageRefreshCounter),
              pages: _pages,
              documentId: widget.documentId,
              currentPageNotifier: _pageIndexNotifier,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSaveTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

// ---------------- SCANNED DOCUMENT OPTIONS PAGE ----------------
class ScannedDocumentOptionsPage extends StatefulWidget {
  final List<Uint8List> scannedImages;
  final List<Map<String, dynamic>> existingDocuments;

  const ScannedDocumentOptionsPage({
    super.key,
    required this.scannedImages,
    required this.existingDocuments,
  });

  @override
  State<ScannedDocumentOptionsPage> createState() =>
      _ScannedDocumentOptionsPageState();
}

class _ScannedDocumentOptionsPageState
    extends State<ScannedDocumentOptionsPage> {
  String _selectedOption = 'new'; // 'new' or 'existing'
  String? _selectedDocumentId;
  final TextEditingController _titleController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      setState(() {
        // Trigger rebuild when text changes to update button state
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title: const Text("Scanned Document"),
        backgroundColor: const Color(0xfff0f0f0),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xff102837)),
                  SizedBox(height: 16),
                  Text('Processing scanned images...',
                      style: TextStyle(color: Color(0xff102837))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview of scanned images
                  Text(
                    '${widget.scannedImages.length} page(s) scanned',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff102837),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.scannedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: Image.memory(
                            widget.scannedImages[index],
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Options
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff102837),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Create new document
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 'new';
                        _selectedDocumentId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'new'
                            ? const Color(0xffc3e3ea)
                            : const Color(0xfffafafa),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: _selectedOption == 'new'
                              ? const Color(0xff102837)
                              : const Color(0xffc3e3ea),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xff102837),
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create New Document',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff102837),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Start a fresh document with these pages',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xff102837)
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Title field for new document
                  if (_selectedOption == 'new') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Document Title',
                        hintText: 'Enter a title for your document',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        filled: true,
                        fillColor: const Color(0xfffafafa),
                      ),
                      onSubmitted: (_) {
                        if (_canProceed()) {
                          _handleProceed();
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Option 2: Add to existing document
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 'existing';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'existing'
                            ? const Color(0xffc3e3ea)
                            : const Color(0xfffafafa),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: _selectedOption == 'existing'
                              ? const Color(0xff102837)
                              : const Color(0xffc3e3ea),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.library_add,
                            color: Color(0xff102837),
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add to Existing Document',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff102837),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Append pages to one of your documents',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xff102837)
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Document selector for existing documents
                  if (_selectedOption == 'existing') ...[
                    const SizedBox(height: 12),
                    if (widget.existingDocuments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xfffafafa),
                          borderRadius: BorderRadius.zero,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'No existing documents found. Create a new document instead.',
                          style: TextStyle(
                              color: const Color(0xff102837).withOpacity(0.7)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xfffafafa),
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: const Color(0xffc3e3ea)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButton<String>(
                          value: _selectedDocumentId,
                          hint: const Text('Select a document'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: widget.existingDocuments.map((doc) {
                            return DropdownMenuItem<String>(
                              value: doc['id'],
                              child: Text(doc['title'] ?? 'Untitled'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDocumentId = value;
                            });
                          },
                        ),
                      ),
                  ],

                  const SizedBox(height: 32),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _handleProceed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffc3e3ea),
                        foregroundColor: const Color(0xff102837),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        disabledBackgroundColor:
                            const Color(0xffc3e3ea).withOpacity(0.5),
                      ),
                      child: Text(
                        _selectedOption == 'new'
                            ? 'Create Document'
                            : 'Add to Document',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _canProceed() {
    if (_selectedOption == 'new') {
      return _titleController.text.trim().isNotEmpty;
    } else {
      return _selectedDocumentId != null;
    }
  }

  Future<void> _handleProceed() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = AuthService();

      // Upload all scanned images first
      List<String> uploadedImageIds = [];
      for (int i = 0; i < widget.scannedImages.length; i++) {
        final imageBytes = widget.scannedImages[i];
        final filename = 'scan_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final result =
            await authService.uploadAttachment(filename, imageBytes.toList());

        if (result.success && result.attachmentId != null) {
          uploadedImageIds.add(result.attachmentId!);
        } else {
          throw Exception('Failed to upload image ${i + 1}: ${result.error}');
        }
      }

      if (_selectedOption == 'new') {
        // Create new document
        await _createNewDocumentWithImages(uploadedImageIds);
      } else {
        // Add to existing document
        await _addImagesToExistingDocument(uploadedImageIds);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xffbd6051),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _createNewDocumentWithImages(List<String> imageIds) async {
    final authService = AuthService();
    final title = _titleController.text.trim();

    // Create document
    final result = await authService.createDocument(title);

    if (!result.success || result.document == null) {
      throw Exception(result.error ?? 'Failed to create document');
    }

    final documentId = result.document!['id']?.toString();
    if (documentId == null) {
      throw Exception('Document ID not returned');
    }

    // Initialize metadata for the new document
    final metadataService = DocumentMetadataService();
    await metadataService.updateLastModified(documentId, title: title);

    // Navigate to the new document with the image pages
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPage(
            documentId: documentId,
            title: title,
            initialImagePages: imageIds,
          ),
        ),
      );
    }
  }

  Future<void> _addImagesToExistingDocument(List<String> imageIds) async {
    if (_selectedDocumentId == null) return;

    final selectedDoc = widget.existingDocuments.firstWhere(
      (doc) => doc['id'] == _selectedDocumentId,
    );

    // Navigate to the document with the image pages to add
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPage(
            documentId: _selectedDocumentId!,
            title: selectedDoc['title'] ?? 'Untitled',
            initialImagePages: imageIds,
          ),
        ),
      );
    }
  }
}

// ---------------- PROFILE PAGE ----------------
class ProfilePage extends StatelessWidget {
  final String phone;
  final String countryCode;

  ProfilePage({
    super.key,
    required this.countryCode,
    required this.phone,
  });

  String getCensoredPhone(String phone, String code) {
    // Extract the last 4 digits from the phone number
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    String lastFour = '';

    if (digits.length >= 4) {
      lastFour = digits.substring(digits.length - 4);
    } else {
      lastFour = digits; // Show whatever digits we have if less than 4
    }

    return '+$code (***) ***-$lastFour';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title:
            const Text('Profile', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: const Color(0xfffafafa),
        iconTheme: const IconThemeData(color: Color(0xff1c1c1c)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'User Profile',
              style: TextStyle(
                color: Color(0xff133223),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Phone
            const Text(
              'PHONE NUMBER',
              style: TextStyle(
                color: Color(0xff133223),
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffc7ffbf),
                borderRadius: BorderRadius.zero,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                getCensoredPhone(phone, countryCode),
                style: const TextStyle(fontSize: 26, color: Color(0xff133223)),
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Clear authentication token
                  final authService = AuthService();
                  await authService.clearToken();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xff102837)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffc3e3ea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- IMAGES PAGE ----------------
class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  _ImagesPageState createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  List<String> imageAttachmentIds = [];
  Map<String, Uint8List> cachedImages = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImageAttachmentIds();
  }

  Future<void> _loadImageAttachmentIds() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids = prefs.getStringList('document_images') ?? [];

      setState(() {
        imageAttachmentIds = ids;
      });

      // Load images
      await _loadImages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading images: $e'),
          backgroundColor: const Color(0xffbd6051),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadImages() async {
    final authService = AuthService();

    for (String attachmentId in imageAttachmentIds) {
      if (!cachedImages.containsKey(attachmentId)) {
        try {
          final result = await authService.downloadAttachment(attachmentId);
          if (result.success && result.fileBytes != null) {
            setState(() {
              cachedImages[attachmentId] =
                  Uint8List.fromList(result.fileBytes!);
            });
          }
        } catch (e) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title: const Text('Uploaded Images',
            style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: const Color(0xfff0f0f0),
        iconTheme: const IconThemeData(color: Color(0xff1c1c1c)),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : imageAttachmentIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No images uploaded yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the image button in the toolbar to upload images',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemCount: imageAttachmentIds.length,
                    itemBuilder: (context, index) {
                      final attachmentId = imageAttachmentIds[index];
                      final imageBytes = cachedImages[attachmentId];

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: imageBytes != null
                              ? Image.memory(
                                  imageBytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error, color: Colors.red),
                                          Text('Error loading image'),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ---------------- NEW DOCUMENT DIALOG ----------------
class NewDocumentDialog extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();

  NewDocumentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("New Document"),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(hintText: "Enter document title"),
        autofocus: true, // auto-focus the field
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, titleController.text.trim()),
          child: const Text("Create"),
        ),
      ],
    );
  }
}

// ---------------- PHONE FORMATTER ----------------
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 10; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
