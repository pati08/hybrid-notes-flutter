import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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
import 'widgets/page_viewer_widget.dart';

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
        // User is logged in, go to HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(
              name:
                  '', // Name is not needed for display, can be fetched from profile
              phone: '', // Phone is not needed for display
              countryCode: '',
            ),
          ),
        );
      } else {
        // User is not logged in, go to SignUpScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
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

// ---------------- SIGN UP SCREEN ----------------
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController(
    text: '1',
  ); // Default country code

  final ScrollController _scrollController = ScrollController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => _scrollToFocusedField(_nameFocus));
    _phoneFocus.addListener(() => _scrollToFocusedField(_phoneFocus));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    nameController.dispose();
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
                      'Create New Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff102837),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'Already Registered? ',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                        children: [
                          TextSpan(
                            text: 'Log in here.',
                            style: const TextStyle(
                              color: Color(0xffc3e3ea),
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // NAME input
              const Text(
                'NAME',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                focusNode: _nameFocus,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  filled: true,
                  fillColor: Colors.grey[300],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 26,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 54),

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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: countryCodeController,
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
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
                  onPressed: () async {
                    String name = nameController.text.trim();
                    String rawPhone = phoneController.text;
                    String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

                    if (digitsOnly.length == 10) {
                      String fullPhone =
                          '+${countryCodeController.text}$digitsOnly';

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      // Call API to send verification code
                      final authService = AuthService();
                      final result =
                          await authService.sendPhoneVerification(fullPhone);

                      // Hide loading indicator
                      Navigator.pop(context);

                      if (result.success) {
                        // Navigate to code verification page
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodeVerificationPage(
                              name: name,
                              phone: fullPhone,
                            ),
                          ),
                        );
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.error ?? 'An error occurred'),
                            backgroundColor: const Color(0xffbd6051),
                          ),
                        );
                      }
                    } else {
                      // Show an error message (e.g., using a SnackBar)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid 10-digit phone number.',
                          ),
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff102837),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Sign up',
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

// ---------------- LOGIN SCREEN ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryCodeController = TextEditingController(
    text: '1',
  );

  final ScrollController _scrollController = ScrollController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => _scrollToFocusedField(_nameFocus));
    _phoneFocus.addListener(() => _scrollToFocusedField(_phoneFocus));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    nameController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: const Color(0xfff0f0f0),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff102837),
                ),
              ),
              const SizedBox(height: 48),

              // NAME input
              const Text(
                'NAME',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                focusNode: _nameFocus,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  filled: true,
                  fillColor: Colors.grey[300],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Phone input
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
                children: [
                  const Text('+'),
                  const SizedBox(width: 8),
                  Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: countryCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [PhoneNumberFormatter()],
                        decoration: const InputDecoration(
                          hintText: '##########',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                        ),
                        textAlign: TextAlign.center,
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
                  onPressed: () async {
                    String name = nameController.text.trim();
                    String rawPhone = phoneController.text;
                    String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

                    if (digitsOnly.length == 10) {
                      String fullPhone =
                          '+${countryCodeController.text}$digitsOnly';

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      // Call API to send verification code
                      final authService = AuthService();
                      final result =
                          await authService.sendPhoneVerification(fullPhone);

                      // Hide loading indicator
                      Navigator.pop(context);

                      if (result.success) {
                        // Navigate to code verification page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodeVerificationPage(
                              name: name,
                              phone: fullPhone,
                            ),
                          ),
                        );
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.error ?? 'An error occurred'),
                            backgroundColor: const Color(0xffbd6051),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please enter a valid 10-digit phone number.'),
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff102837),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(color: Colors.white)),
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
  final String name;
  final String phone;

  const CodeVerificationPage(
      {super.key, required this.name, required this.phone});

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
                  borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                  onPressed: () async {
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
                      Navigator.pop(context);

                      if (result.success) {
                        // Token is already stored by AuthService
                        // Extract country code from phone number
                        String countryCode =
                            widget.phone.substring(1, widget.phone.length - 10);

                        // Navigate to home screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(
                              name: widget.name,
                              phone: widget.phone,
                              countryCode: countryCode,
                            ),
                          ),
                        );
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(result.error ?? 'Verification failed'),
                            backgroundColor: const Color(0xffbd6051),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid 6-digit code'),
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff102837),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
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
  final String name;
  final String phone;
  final String countryCode;

  const HomeScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.countryCode,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<Map<String, String>> documents = []; // user-created documents
  bool isLoadingDocuments = true;
  String? apiError;
  List<dynamic>? apiDocumentsList;

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
    // Refresh the documents list
    sendRequestWithCookie();
  }

  Future<void> sendRequestWithCookie() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingDocuments = true;
          apiError = null;
        });
      }

      // Use AuthService to list documents
      final authService = AuthService();
      final result = await authService.listDocuments();

      if (result.success && result.documents != null) {
        if (mounted) {
          setState(() {
            apiDocumentsList = result.documents;
            // Populate the documents list from API data
            documents = result.documents!
                .map((doc) {
                  return {
                    'id': doc['id']?.toString() ?? '',
                    'title': doc['name']?.toString() ?? 'Untitled',
                  };
                })
                .toList()
                .cast<Map<String, String>>();
            isLoadingDocuments = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            apiError = result.error ?? 'Failed to load documents';
            isLoadingDocuments = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          apiError = 'Error occurred: $e';
          isLoadingDocuments = false;
        });
      }
      print('Error: $e');
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
        if (mounted) {
          setState(() {
            documents.add({
              'id': result.document!['id']?.toString() ?? '',
              'title': result.document!['name']?.toString() ?? title,
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
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'File uploaded successfully! Attachment ID: ${result.attachmentId}'),
            backgroundColor: const Color(0xffc7ffbf),
          ),
        );
        // Store attachmentId for later use
        print('Attachment ID: ${result.attachmentId}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            backgroundColor: const Color(0xffbd6051),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'File downloaded successfully! Size: ${result.fileBytes?.length} bytes'),
            backgroundColor: const Color(0xffc7ffbf),
          ),
        );
        // Use result.fileBytes for the downloaded file
        print('Downloaded file size: ${result.fileBytes?.length} bytes');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${result.error}'),
            backgroundColor: const Color(0xffbd6051),
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
                    borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(16), // Rounded edges
          child: Container(
            height: MediaQuery.of(context).size.height * 0.45,
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xffc8c8c8),
              borderRadius: BorderRadius.circular(
                16,
              ), // Match Material borderRadius
            ),
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const DrawerHeader(
                      decoration: BoxDecoration(
                        color: Color(0xffcccccc),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
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
                                name: widget.name,
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
                        debugPrint('Logging out...');
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
                                builder: (_) => const SignUpScreen()),
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
                    borderRadius: BorderRadius.circular(8),
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
                    bool isHovered = false;
                    final docTitle = displayedDocuments[index]['title']!;

                    return StatefulBuilder(
                      builder: (context, setState) {
                        return MouseRegion(
                          onEnter: (_) => setState(() => isHovered = true),
                          onExit: (_) => setState(() => isHovered = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () async {
                              if (docTitle == 'Create New') {
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
                                  // Get the document ID
                                  final docId =
                                      displayedDocuments[index]['id'] ?? '';

                                  // Check before navigation
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DocumentPage(
                                        documentId: docId,
                                        title: docTitle,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              transform: Matrix4.identity()
                                ..scale(isHovered ? 1.05 : 1.0),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? const Color(0xffc3e3ea)
                                    : const Color(0xfff0f0f0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    docTitle == 'Create New'
                                        ? Icons.add_outlined
                                        : Icons.description,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 12),
                                  if (docTitle == 'Create New') ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      docTitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ] else ...[
                                    Text(
                                      docTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Preview of $docTitle',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
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
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Color(0xffc7ffbf),
            ),
          );
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
  late PageController _pageController;
  late TextEditingController _titleController;
  bool _isEditingTitle = false;
  bool _isLoading = true;
  String? _loadError;

  // List of pages (each can be DigitalPage or ImagePage)
  List<DocumentPageData> _pages = [];
  int _currentPageIndex = 0;
  late ValueNotifier<int> _pageIndexNotifier; // For instant UI updates without setState

  // Auto-save timer
  Timer? _autoSaveTimer;
  DateTime? _lastSaveTime;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _titleController = TextEditingController(text: widget.title);
    _pageIndexNotifier = ValueNotifier<int>(0);

    // Listen to page controller to update index only when animation completes
    _pageController.addListener(_onPageScrolled);

    // Start periodic auto-save (every 30 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDocument(showFeedback: false);
    });

    // Load document from API
    _loadDocument();
  }

  void _onPageScrolled() {
    // Update page index when scrolling passes the halfway point
    if (_pageController.page != null) {
      final page = _pageController.page!;
      final newIndex = page.round();
      
      // Track scrolling state
      final isAtPageBoundary = (page - page.roundToDouble()).abs() < 0.01;
      final wasScrolling = _isScrolling;
      _isScrolling = !isAtPageBoundary;
      
      // Update notifier immediately for toolbar (no rebuild of entire widget)
      if (newIndex != _pageIndexNotifier.value && 
          newIndex >= 0 && 
          newIndex < _pages.length) {
        _pageIndexNotifier.value = newIndex;
      }
      
      // Only trigger setState when scroll animation completes for page counter
      if (!_isScrolling && wasScrolling && newIndex != _currentPageIndex) {
        if (mounted) {
          setState(() {
            _currentPageIndex = newIndex;
          });
        }
      }
    }
  }

  Future<void> _loadDocument() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });

      final authService = AuthService();
      final result = await authService.getDocument(widget.documentId);

      print('Document load result: success=${result.success}');
      print('Document data: ${result.document}');

      if (result.success && result.document != null) {
        // Parse pages and load them
        final pages = result.document!['pages'] as List<dynamic>?;

        print('Pages found: ${pages?.length ?? 0}');

        List<DocumentPageData> loadedPages = [];
        List<String> imageAttachmentIds = [];

        if (pages != null && pages.isNotEmpty) {
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
            print('⚡ Preloading ${imageAttachmentIds.length} images...');
            final imageCacheService = ImageCacheService();
            await imageCacheService.preloadImages(imageAttachmentIds);
            print('✓ All images preloaded');
          }

          // Second pass: build page data with cached images
          for (var page in pages) {
            print('Processing page: $page');
            final pageType = page['page_type'];

            if (pageType != null) {
              print('Page type: ${pageType['type']}');

              if (pageType['type'] == 'DigitalPage') {
                // Load the digital page content
                final quillJson = pageType['quill_json'];

                print('Quill JSON: $quillJson');

                if (quillJson != null && quillJson.isNotEmpty) {
                  try {
                    // Parse the Quill JSON and create controller
                    final deltaJson = jsonDecode(quillJson);
                    print('Parsed delta JSON: $deltaJson');

                    final delta = Delta.fromJson(deltaJson);
                    print('Created delta with ${delta.length} operations');

                    final doc = ParchmentDocument.fromDelta(delta);
                    final controller = FleatherController(document: doc);

                    loadedPages
                        .add(DocumentPageData.digital(controller: controller));
                    print('Added DigitalPage');
                  } catch (e) {
                    print('Error parsing Quill JSON: $e');
                    // Add empty page if parsing fails
                    loadedPages.add(DocumentPageData.digital());
                  }
                } else {
                  // Empty digital page
                  loadedPages.add(DocumentPageData.digital());
                }
              } else if (pageType['type'] == 'ImagePage') {
                // Load the image page with cached data
                final imageUrl = pageType['image_url'] as String?;
                print('Image URL: $imageUrl');

                final imageCacheService = ImageCacheService();
                final cachedImage = imageUrl != null 
                    ? imageCacheService.getCachedImage(imageUrl)
                    : null;

                loadedPages.add(DocumentPageData.image(
                  imageUrl: imageUrl,
                  imageBytes: cachedImage,
                ));
                print('Added ImagePage with cached data: ${cachedImage != null}');
              }
            }
          }
        }

        // If no pages loaded, add an empty digital page
        if (loadedPages.isEmpty) {
          print('No pages loaded, adding empty digital page');
          loadedPages.add(DocumentPageData.digital());
        }

        // Add initial image pages if provided (from scanning)
        if (widget.initialImagePages != null &&
            widget.initialImagePages!.isNotEmpty) {
          final imageCacheService = ImageCacheService();
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

          // Navigate to the first added image page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _pageController.jumpToPage(_currentPageIndex);
            }
          });
        }

        print('Document loaded with ${_pages.length} pages');
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
      print('Error in _loadDocument: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }


  @override
  void dispose() {
    // Save on exit
    _saveDocument(showFeedback: false);

    // Cancel auto-save timer
    _autoSaveTimer?.cancel();

    // Remove listener before disposing
    _pageController.removeListener(_onPageScrolled);

    // Dispose controllers
    _titleController.dispose();
    _pageController.dispose();
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document renamed successfully'),
              backgroundColor: Color(0xffc7ffbf),
            ),
          );
        }
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
    try {
      // Convert all pages to API format
      final pages = _pages.map((page) {
        if (page.type == 'DigitalPage' && page.controller != null) {
          return {
            'page_type': {
              'type': 'DigitalPage',
              'quill_json':
                  jsonEncode(page.controller!.document.toDelta().toJson()),
            }
          };
        } else if (page.type == 'ImagePage' && page.imageUrl != null) {
          return {
            'page_type': {
              'type': 'ImagePage',
              'image_url': page.imageUrl,
            }
          };
        } else {
          // Empty digital page fallback
          return {
            'page_type': {
              'type': 'DigitalPage',
              'quill_json': jsonEncode([
                {'insert': '\n'}
              ]),
            }
          };
        }
      }).toList();

      final authService = AuthService();
      final success = await authService.saveDocument(widget.documentId, pages);

      if (success) {
        _lastSaveTime = DateTime.now();

        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document saved successfully'),
              backgroundColor: Color(0xffc7ffbf),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
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
      print('Error saving document: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: const Color(0xffbd6051),
          ),
        );
      }
    }
  }

  void _addDigitalPage() {
    setState(() {
      _pages.add(DocumentPageData.digital());
      _currentPageIndex = _pages.length - 1;
      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
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
            _pageController.animateToPage(
              _currentPageIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });

          // Auto-save after adding image
          _saveDocument(showFeedback: false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image added successfully'),
                backgroundColor: Color(0xffc7ffbf),
              ),
            );
          }
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
          ),
        );
      }
    }
  }

  void _deletePage(int index) {
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

      _pageController.jumpToPage(_currentPageIndex);
    });

    // Auto-save after deleting
    _saveDocument(showFeedback: false);
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
            onPressed: () => Navigator.pop(context),
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
            onPressed: () => Navigator.pop(context),
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
          onPressed: () => Navigator.pop(context),
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
                  onSelected: (value) {
                    if (value == 'digital') {
                      _addDigitalPage();
                    } else if (value == 'image') {
                      _addImagePage();
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
          // Show toolbar only for digital pages with fade animation
          // Uses ValueListenableBuilder to avoid rebuilding entire page
          ValueListenableBuilder<int>(
            valueListenable: _pageIndexNotifier,
            builder: (context, pageIndex, child) {
              final currentPageForToolbar = pageIndex >= 0 && pageIndex < _pages.length 
                  ? _pages[pageIndex] 
                  : null;
              
              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: currentPageForToolbar?.type == 'DigitalPage' &&
                          currentPageForToolbar?.controller != null
                      ? 1.0
                      : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: currentPageForToolbar?.type == 'DigitalPage' &&
                          currentPageForToolbar?.controller != null
                      ? ResponsiveFleatherToolbar(controller: currentPageForToolbar!.controller!)
                      : SizedBox(
                          height: currentPageForToolbar?.type == 'DigitalPage' &&
                                  currentPageForToolbar?.controller != null
                              ? 88
                              : 0,
                        ),
                ),
              );
            },
          ),

          // Page view with horizontal scrolling - optimized with RepaintBoundary
          // Note: onPageChanged removed to prevent setState during animation
          Expanded(
            child: PageViewerWidget(
              pages: _pages,
              pageController: _pageController,
              onPageChanged: (index) {
                // Do nothing - page index updates via listener when animation completes
              },
            ),
          ),

          // Page counter and navigation at bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xfffafafa),
              border: Border(
                top: BorderSide(color: Color(0xffc3e3ea), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPageIndex > 0
                      ? () {
                          setState(() {
                            _currentPageIndex--;
                            _pageController.animateToPage(
                              _currentPageIndex,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          });
                        }
                      : null,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page ${_currentPageIndex + 1} of ${_pages.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_lastSaveTime != null)
                      Text(
                        'Last saved: ${_formatSaveTime(_lastSaveTime!)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (_pages.length > 1)
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Color(0xffbd6051)),
                        onPressed: () => _deletePage(_currentPageIndex),
                        tooltip: 'Delete Page',
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPageIndex < _pages.length - 1
                          ? () {
                              setState(() {
                                _currentPageIndex++;
                                _pageController.animateToPage(
                                  _currentPageIndex,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ],
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
  final List<Map<String, String>> existingDocuments;

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
                          borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedOption == 'new'
                              ? const Color(0xff102837)
                              : const Color(0xffc3e3ea),
                          width: 2,
                        ),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xfffafafa),
                      ),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedOption == 'existing'
                              ? const Color(0xff102837)
                              : const Color(0xffc3e3ea),
                          width: 2,
                        ),
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
                          borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffc3e3ea)),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
  final String name;
  final String phone;
  String countryCode;

  ProfilePage({
    super.key,
    required this.name,
    required this.countryCode,
    required this.phone,
  });

  String getCensoredPhone(String phone, String code) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    countryCode = code;
    String areaCode = '***';
    String mid = '***';
    String end = '';
    if (digits.length == 11) {
      end = digits.substring(7);
    } else if (digits.length == 12) {
      end = digits.substring(8);
    } else if (digits.length == 13) {
      end = digits.substring(9);
    }
    return '+$countryCode ($areaCode) $mid-$end';
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

            // Name
            const Text(
              'NAME',
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(fontSize: 18, color: Color(0xff133223)),
              ),
            ),

            const SizedBox(height: 54),

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
                borderRadius: BorderRadius.circular(4),
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
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
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
                    borderRadius: BorderRadius.circular(4),
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
        } catch (e) {
          print('Error loading image $attachmentId: $e');
        }
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
                          borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
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

