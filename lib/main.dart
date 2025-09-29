import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';

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
                      color: Colors.indigo[900],
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
                            color: Colors.blue,
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
                onPressed: () {
                  String name = nameController.text.trim();
                  String rawPhone = phoneController.text;
                  String digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

                  if (digitsOnly.length == 10) {
                    String fullPhone =
                        '+${countryCodeController.text}$digitsOnly';

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => HomeScreen(
                              name: name,
                              phone: fullPhone,
                              countryCode: countryCodeController.text,
                            ),
                      ),
                    );
                  } else {
                    // Show an error message (e.g., using a SnackBar)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter a valid 10-digit phone number.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
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
                color: Colors.indigo[900],
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
                onPressed: () {
                  String name = nameController.text.trim();
                  String fullPhone =
                      '+${countryCodeController.text}${phoneController.text}';

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CodeVerificationPage(
                            name: name,
                            phone: fullPhone,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
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
            Icon(Icons.security, size: 80, color: Colors.indigo[900]),
            SizedBox(height: 24),
            Text(
              'Verification Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[900],
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
              phone,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[900],
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
              onPressed: () {
                // Simulate resending code
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification code sent!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'Didn\'t receive the code? Resend',
                style: TextStyle(
                  color: Colors.blue,
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
                onPressed: () {
                  if (codeController.text.length == 6) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => HomeScreen(
                              name: name,
                              phone: phone,
                              countryCode: codeController.text,
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a valid 6-digit code'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[900],
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
  Map<String, dynamic>? apiResponseData;

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

      final url = Uri.parse('https://example.com/api/get-documents');

      final response = returnJSON();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          // Check before setState
          setState(() {
            apiResponseData = data;
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
              Icon(Icons.error_outline, size: 16, color: Colors.red)
            else
              Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
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
                      onTap: () {
                        debugPrint('Navigating to SignUpScreen...');
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
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          apiError!,
                          style: TextStyle(color: Colors.red[700]),
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
                                        ? Colors.grey[400]
                                        : Colors.grey[300],
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
              Icon(Icons.error_outline, color: Colors.red, size: 80),
              SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
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

// ---------------- DOCUMENT & SCAN PAGES ----------------
class DocumentPage extends StatelessWidget {
  final String title;
  DocumentPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff0f0f0),
      appBar: AppBar(title: Text(title), backgroundColor: Color(0xfff0f0f0)),
      body: Center(child: Text("This is $title")),
    );
  }
}

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Align your document within the frame below",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "📄 Document Preview\n(Scanner placeholder)",
                    style: TextStyle(color: Colors.black38),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Replace this with actual scanner functionality
                print("Scan button pressed!");
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan Document"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                onPressed: () {
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
