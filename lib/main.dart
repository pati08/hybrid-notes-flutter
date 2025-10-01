import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fleather/fleather.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SignUpScreen(), debugShowCheckedModeBanner: false);
  }
}

// ---------------- SIGN UP SCREEN ----------------
class SignUpScreen extends StatefulWidget {
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
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.8, // Scroll to ~80% of available scroll
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Text(
                    'Create New Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff102837),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'Already Registered? ',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      children: [
                        TextSpan(
                          text: 'Log in here.',
                          style: TextStyle(
                            color: Color(0xffc3e3ea),
                            decoration: TextDecoration.underline,
                          ),
                          recognizer:
                              TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LoginPage(),
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
            SizedBox(height: 48),

            // NAME input
            Text(
              'NAME',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: nameController,
              focusNode: _nameFocus,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: Colors.grey[300],
                contentPadding: EdgeInsets.symmetric(
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

            SizedBox(height: 54),

            // PHONE input
            Text(
              'PHONE NUMBER',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('+', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
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
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 26),
                      border: InputBorder.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 12),
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
                      decoration: InputDecoration(
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
            SizedBox(height: 48),

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
                      builder: (context) => Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    
                    // Call API to send verification code
                    final authService = AuthService();
                    final result = await authService.sendPhoneVerification(fullPhone);
                    
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
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  } else {
                    // Show an error message (e.g., using a SnackBar)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter a valid 10-digit phone number.',
                        ),
                        backgroundColor: Color(0xffbd6051),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff102837),
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
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.8, // Scroll to ~80% of available scroll
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      appBar: AppBar(
        title: Text('Login', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: Color(0xfff0f0f0),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xff102837),
              ),
            ),
            SizedBox(height: 48),

            // NAME input
            Text(
              'NAME',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: nameController,
              focusNode: _nameFocus,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: Colors.grey[300],
                contentPadding: EdgeInsets.symmetric(
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

            SizedBox(height: 24),

            // Phone input
            Text(
              'PHONE NUMBER',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('+'),
                SizedBox(width: 8),
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
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 12),
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
                      decoration: InputDecoration(
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

            SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  String name = nameController.text.trim();
                  String rawPhone = phoneController.text;
                  String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
                  
                  if (digitsOnly.length == 10) {
                    String fullPhone = '+${countryCodeController.text}$digitsOnly';
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    
                    // Call API to send verification code
                    final authService = AuthService();
                    final result = await authService.sendPhoneVerification(fullPhone);
                    
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
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid 10-digit phone number.'),
                        backgroundColor: Color(0xffbd6051),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff102837),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text('Continue', style: TextStyle(color: Colors.white)),
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

  CodeVerificationPage({required this.name, required this.phone});

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
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.8, // Scroll to ~80% of available scroll
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      appBar: AppBar(
        title: Text('Verify Code', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: Color(0xfff0f0f0),
        iconTheme: IconThemeData(color: Color(0xff1c1c1c)),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Icon(Icons.security, size: 80, color: Color(0xff102837)),
            SizedBox(height: 24),
            Text(
              'Verification Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xff102837),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'We\'ve sent a 6-digit code to',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              widget.phone,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff102837),
              ),
            ),
            SizedBox(height: 48),

            // Code input
            Text(
              '6-DIGIT CODE',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, 4),
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
                  hintStyle: TextStyle(fontSize: 32, letterSpacing: 8),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                obscureText: false,
              ),
            ),

            SizedBox(height: 32),

            // Resend code option
            TextButton(
              onPressed: () async {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                // Call API to resend verification code
                final authService = AuthService();
                final result = await authService.sendPhoneVerification(widget.phone);
                
                // Hide loading indicator
                Navigator.pop(context);
                
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Verification code sent!'),
                      backgroundColor: Color(0xffc7ffbf),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.error ?? 'Failed to resend code'),
                      backgroundColor: Color(0xffbd6051),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(
                'Didn\'t receive the code? Resend',
                style: TextStyle(
                  color: Color(0xffc3e3ea),
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            SizedBox(height: 48),

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
                      builder: (context) => Center(
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
                      String countryCode = widget.phone.substring(1, widget.phone.length - 10);
                      
                      // Navigate to home screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => HomeScreen(
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
                          content: Text(result.error ?? 'Verification failed'),
                          backgroundColor: Color(0xffbd6051),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid 6-digit code'),
                        backgroundColor: Color(0xffbd6051),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff102837),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
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
    Key? key,
    required this.name,
    required this.phone,
    required this.countryCode,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> sendRequestWithCookie() async {
    try {
      if (mounted) {
        setState(() {
          isLoadingDocuments = true;
          apiError = null;
        });
      }

      // Use AuthService to make authenticated request
      final authService = AuthService();
      final response = await authService.makeAuthenticatedRequest('/api/docs/list');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          // Check before setState
          setState(() {
            // API returns an array of DocumentMetadata
            if (data is List) {
              apiDocumentsList = data;
              // Optionally populate the documents list from API data
              documents = data.map((doc) {
                return {
                  'id': doc['id']?.toString() ?? '',
                  'title': doc['name']?.toString() ?? 'Untitled',
                };
              }).toList().cast<Map<String, String>>();
            }
            isLoadingDocuments = false;
          });
        }
        // No print statement as per your request
      } else if ([400, 401, 404, 500].contains(response.statusCode)) {
        // Navigate to ErrorScreen with callback to go back to SignUpScreen on button press
        if (mounted) {
          // Check before navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check again in callback
              Navigator.of(context, rootNavigator: true).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (_) => ErrorScreen(
                        errorMessage:
                            'Request failed with status: ${response.statusCode}',
                        onReturnToSignUp: () {
                          Navigator.of(
                            context,
                            rootNavigator: true,
                          ).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => SignUpScreen()),
                            (route) => false,
                          );
                        },
                      ),
                ),
              );
            }
          });
        }
        return; // Exit method immediately after scheduling navigation
      } else {
        if (mounted) {
          // Check before setState
          setState(() {
            apiError = 'Request failed with status: ${response.statusCode}';
            isLoadingDocuments = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Check before setState
        setState(() {
          apiError = 'Error occurred: $e';
          isLoadingDocuments = false;
        });
      }
      print('Error: $e');
    }
  }

  void addDocument(String title) {
    if (mounted) {
      // Check before setState
      setState(() {
        documents.add({"title": title});
      });
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
            content: Text('File uploaded successfully! Attachment ID: ${result.attachmentId}'),
            backgroundColor: Color(0xffc7ffbf),
          ),
        );
        // Store attachmentId for later use
        print('Attachment ID: ${result.attachmentId}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error}'),
            backgroundColor: Color(0xffbd6051),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: Color(0xffbd6051),
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
            content: Text('File downloaded successfully! Size: ${result.fileBytes?.length} bytes'),
            backgroundColor: Color(0xffc7ffbf),
          ),
        );
        // Use result.fileBytes for the downloaded file
        print('Downloaded file size: ${result.fileBytes?.length} bytes');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${result.error}'),
            backgroundColor: Color(0xffbd6051),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Color(0xffbd6051),
        ),
      );
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
        backgroundColor: Color(0xfff0f0f0),
        title: Column(
          children: [
            Text(
              'Home',
              style: TextStyle(
                color: Color(0xff133223),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Show loading indicator or status in app bar
            if (isLoadingDocuments)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff133223)),
                ),
              )
            else if (apiError != null)
              Icon(Icons.error_outline, size: 16, color: Color(0xffbd6051))
            else
              Icon(Icons.check_circle_outline, size: 16, color: Color(0xffc7ffbf)),
          ],
        ),
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu, size: 40, color: Color(0xff133223)),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(0xffc3e3ea),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.document_scanner,
                    size: 40,
                    color: Color(0xff102837),
                  ),
                  onPressed: () {
                    if (mounted) {
                      // Check before navigation
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ScanPage()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Color(0xfffafafa),
      drawer: Align(
        alignment: Alignment.center,
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16), // Rounded edges
          child: Container(
            height: MediaQuery.of(context).size.height * 0.45,
            width: 200,
            decoration: BoxDecoration(
              color: Color(0xffc8c8c8),
              borderRadius: BorderRadius.circular(
                16,
              ), // Match Material borderRadius
            ),
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
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
                      leading: Icon(Icons.person, color: Color(0xff1c1c1c)),
                      title: Text(
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
                              builder:
                                  (_) => ProfilePage(
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
                      leading: Icon(Icons.logout, color: Color(0xff1c1c1c)),
                      title: Text(
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
                            MaterialPageRoute(builder: (_) => SignUpScreen()),
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
                    icon: Icon(Icons.close, color: Color(0xff133233), size: 20),
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
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Color(0xffbd6051).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xffbd6051).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Color(0xffbd6051)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          apiError!,
                          style: TextStyle(color: Color(0xffbd6051)),
                        ),
                      ),
                      TextButton(
                        onPressed: sendRequestWithCookie,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: displayedDocuments.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                                  addDocument(newTitle);
                                }
                              } else {
                                if (mounted) {
                                  // Check before navigation
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => DocumentPage(title: docTitle),
                                    ),
                                  );
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 150),
                              transform:
                                  Matrix4.identity()
                                    ..scale(isHovered ? 1.05 : 1.0),
                              decoration: BoxDecoration(
                                color:
                                    isHovered
                                        ? Color(0xffc3e3ea)
                                        : Color(0xfff0f0f0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.all(12),
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
                                  SizedBox(height: 12),
                                  if (docTitle == 'Create New') ...[
                                    SizedBox(height: 8),
                                    Text(
                                      docTitle,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ] else ...[
                                    Text(
                                      docTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Preview of $docTitle',
                                      style: TextStyle(
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
    Key? key,
    required this.errorMessage,
    required this.onReturnToSignUp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Color(0xffbd6051), size: 80),
              SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xffbd6051),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Clear authentication token on error return
                  final authService = AuthService();
                  await authService.clearToken();
                  
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
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
    Key? key,
    required this.controller,
  }) : super(key: key);

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
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<CompactToolbar> createState() => _CompactToolbarState();
}

class _CompactToolbarState extends State<CompactToolbar> {

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xfffafafa),
        border: Border(
          bottom: BorderSide(color: Color(0xffc3e3ea), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row - Text formatting
          Container(
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
                      onPressed: () => _toggleFormat(ParchmentAttribute.underline),
                    ),
                    _buildToolbarButton(
                      icon: Icons.format_strikethrough,
                      tooltip: 'Strikethrough',
                      onPressed: () => _toggleFormat(ParchmentAttribute.strikethrough),
                    ),
                    _buildToolbarButton(
                      icon: Icons.integration_instructions,
                      tooltip: 'Inline Code',
                      onPressed: () => _toggleFormat(ParchmentAttribute.inlineCode),
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
            decoration: BoxDecoration(
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
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xff102837),
          minimumSize: Size(36, 36),
          padding: EdgeInsets.all(6),
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
        title: Text('Add Link'),
        content: TextField(
          controller: linkController,
          decoration: InputDecoration(
            hintText: 'Enter URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
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
            child: Text('Add'),
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
          builder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        // Read image bytes
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();
        
        // Upload image
        final authService = AuthService();
        final result = await authService.uploadAttachment(image.name, imageBytes);
        
        // Hide loading dialog
        Navigator.pop(context);
        
        if (result.success) {
          // Store the attachment ID for this document
          await _storeImageAttachmentId(result.attachmentId!);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Color(0xffc7ffbf),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${result.error}'),
              backgroundColor: Color(0xffbd6051),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Color(0xffbd6051),
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

// ---------------- DOCUMENT & SCAN PAGES ----------------
class DocumentPage extends StatefulWidget {
  final String title;

  const DocumentPage({Key? key, required this.title}) : super(key: key);

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  late FleatherController _controller;
  late TextEditingController _titleController;
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();

    // Start with an empty document (you can also load JSON here)
    final doc = ParchmentDocument();
    _controller = FleatherController(document: doc);
    
    // Initialize title controller with the current title
    _titleController = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
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

  void _saveTitle() {
    setState(() {
      _isEditingTitle = false;
    });
    // Here you could save the title to a database or local storage
    // For now, we'll just update the state
  }

  void _cancelEditingTitle() {
    setState(() {
      _isEditingTitle = false;
      _titleController.text = widget.title; // Reset to original title
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        backgroundColor: const Color(0xfff0f0f0),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                style: TextStyle(
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
                _titleController.text.isEmpty ? widget.title : _titleController.text,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
        actions: _isEditingTitle
            ? [
                IconButton(
                  icon: Icon(Icons.check, color: Color(0xffc7ffbf)),
                  onPressed: _saveTitle,
                  tooltip: 'Save title',
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xffbd6051)),
                  onPressed: _cancelEditingTitle,
                  tooltip: 'Cancel',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.image, color: Colors.grey[700]),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ImagesPage()),
                    );
                  },
                  tooltip: 'View Images',
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey[700]),
                  onPressed: _startEditingTitle,
                  tooltip: 'Edit title',
                ),
              ],
      ),
      body: Column(
        children: [
          // Responsive toolbar for formatting
          ResponsiveFleatherToolbar(controller: _controller),

          // Editor area
          Expanded(
            child: Container(
              color: Color(0xfffafafa),
              padding: const EdgeInsets.all(8.0),
              child: FleatherEditor(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<Uint8List> _capturedPages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f0f0),
      appBar: AppBar(
        title: const Text("Scan Document"),
        backgroundColor: const Color(0xfff0f0f0),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Embedded scanner takes the available top space
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: _buildScanner(),
            ),
          ),
          // Captured pages list below current page of text
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xfffafafa),
                border: Border(top: BorderSide(color: Color(0xffc3e3ea), width: 1)),
              ),
              child: _capturedPages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Scanned pages will appear here',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final bytes = _capturedPages[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(bytes, height: 160),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: _capturedPages.length,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    // cunning_document_scanner does not provide an embedded preview widget.
    // We launch the native scanner and then display results below.
    return Center(
      child: ElevatedButton.icon(
        onPressed: _startScan,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Start scanner'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffc3e3ea),
          foregroundColor: const Color(0xff102837),
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    try {
      final List<String>? images = await CunningDocumentScanner.getPictures();
      if (images == null) return; // user cancelled
      final collected = <Uint8List>[];
      for (final path in images) {
        final f = File(path);
        if (await f.exists()) {
          collected.add(await f.readAsBytes());
        }
      }
      if (!mounted) return;
      setState(() {
        _capturedPages
          ..clear()
          ..addAll(collected);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanner error: $e'),
          backgroundColor: const Color(0xffbd6051),
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
      backgroundColor: Color(0xfff0f0f0),
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: Color(0xfffafafa),
        iconTheme: IconThemeData(color: Color(0xff1c1c1c)),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'User Profile',
              style: TextStyle(
                color: Color(0xff133223),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48),

            // Name
            Text(
              'NAME',
              style: TextStyle(
                color: Color(0xff133223),
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(0xffc7ffbf),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: TextStyle(fontSize: 18, color: Color(0xff133223)),
              ),
            ),

            SizedBox(height: 54),

            // Phone
            Text(
              'PHONE NUMBER',
              style: TextStyle(
                color: Color(0xff133223),
                letterSpacing: 2,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(0xffc7ffbf),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                getCensoredPhone(phone, countryCode),
                style: TextStyle(fontSize: 26, color: Color(0xff133223)),
              ),
            ),

            SizedBox(height: 48),

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
                    MaterialPageRoute(builder: (_) => SignUpScreen()),
                    (route) => false,
                  );
                },
                icon: Icon(Icons.logout),
                label: Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xff102837)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xffc3e3ea),
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
          backgroundColor: Color(0xffbd6051),
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
              cachedImages[attachmentId] = Uint8List.fromList(result.fileBytes!);
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
      backgroundColor: Color(0xfff0f0f0),
      appBar: AppBar(
        title: Text('Uploaded Images', style: TextStyle(color: Color(0xff1c1c1c))),
        backgroundColor: Color(0xfff0f0f0),
        iconTheme: IconThemeData(color: Color(0xff1c1c1c)),
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : imageAttachmentIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No images uploaded yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
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
                  padding: EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                              offset: Offset(0, 2),
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
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
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
                                  child: Center(
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("New Document"),
      content: TextField(
        controller: titleController,
        decoration: InputDecoration(hintText: "Enter document title"),
        autofocus: true, // auto-focus the field
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, titleController.text.trim()),
          child: Text("Create"),
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