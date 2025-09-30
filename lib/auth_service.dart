import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _baseUrl = 'https://draftly-notes.com';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Store token securely
  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Retrieve stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Clear stored token (for logout)
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Send phone number for verification
  Future<AuthResult> sendPhoneVerification(String phoneNumber) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/start');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phoneNumber,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Network error: $e',
        statusCode: 0,
      );
    }
  }

  // Verify code and get token
  Future<AuthResult> verifyCode(String phoneNumber, String code) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/finish');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phoneNumber,
          'code': code,
        }),
      );

      final result = _handleResponse(response);
      
      // If successful, store the token
      if (result.success && result.token != null) {
        await storeToken(result.token!);
      }
      
      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Network error: $e',
        statusCode: 0,
      );
    }
  }

  // Make authenticated API calls
  Future<http.Response> makeAuthenticatedRequest(String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        return await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        return await http.get(url, headers: headers);
    }
  }

  // Upload attachment
  Future<AttachmentUploadResult> uploadAttachment(String filePath, List<int> fileBytes) async {
    try {
      // Step 1: Get upload URL from server
      final url = Uri.parse('$_baseUrl/api/attachments/upload');
      final response = await makeAuthenticatedRequest('/api/attachments/upload', method: 'POST');
      
      if (response.statusCode != 200) {
        return AttachmentUploadResult(
          success: false,
          error: 'Failed to get upload URL: ${response.statusCode}',
        );
      }
      
      final data = jsonDecode(response.body);
      final attachmentId = data['attachment_id'];
      final uploadUrl = data['upload_url'];
      
      // Step 2: Upload file to the provided URL
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );
      
      if (uploadResponse.statusCode == 200) {
        return AttachmentUploadResult(
          success: true,
          attachmentId: attachmentId,
        );
      } else {
        return AttachmentUploadResult(
          success: false,
          error: 'Upload failed: ${uploadResponse.statusCode}',
        );
      }
    } catch (e) {
      return AttachmentUploadResult(
        success: false,
        error: 'Upload error: $e',
      );
    }
  }

  // Download attachment
  Future<AttachmentDownloadResult> downloadAttachment(String attachmentId) async {
    try {
      // Step 1: Get download URL from server
      final url = Uri.parse('$_baseUrl/api/attachments/download/$attachmentId?expires_in=3600');
      final response = await makeAuthenticatedRequest('/api/attachments/download/$attachmentId?expires_in=3600');
      
      if (response.statusCode != 200) {
        return AttachmentDownloadResult(
          success: false,
          error: 'Failed to get download URL: ${response.statusCode}',
        );
      }
      
      final data = jsonDecode(response.body);
      final downloadUrl = data['download_url'];
      
      // Step 2: Download file from the provided URL
      final downloadResponse = await http.get(Uri.parse(downloadUrl));
      
      if (downloadResponse.statusCode == 200) {
        return AttachmentDownloadResult(
          success: true,
          fileBytes: downloadResponse.bodyBytes,
        );
      } else {
        return AttachmentDownloadResult(
          success: false,
          error: 'Download failed: ${downloadResponse.statusCode}',
        );
      }
    } catch (e) {
      return AttachmentDownloadResult(
        success: false,
        error: 'Download error: $e',
      );
    }
  }

  // Handle API response
  AuthResult _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      
      switch (response.statusCode) {
        case 200:
          return AuthResult(
            success: true,
            message: data['message'] ?? 'Success',
            token: data['token'],
            statusCode: response.statusCode,
          );
        case 400:
          return AuthResult(
            success: false,
            error: 'Formatted number wrong (my fault)',
            statusCode: response.statusCode,
          );
        case 401:
          return AuthResult(
            success: false,
            error: 'They gave wrong code. Ask for right code again.',
            statusCode: response.statusCode,
          );
        case 500:
          return AuthResult(
            success: false,
            error: 'Server error, something went wrong',
            statusCode: response.statusCode,
          );
        default:
          return AuthResult(
            success: false,
            error: 'Unexpected error occurred',
            statusCode: response.statusCode,
          );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Failed to parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }
}

class AuthResult {
  final bool success;
  final String? message;
  final String? token;
  final String? error;
  final int statusCode;

  AuthResult({
    required this.success,
    this.message,
    this.token,
    this.error,
    required this.statusCode,
  });
}

class AttachmentUploadResult {
  final bool success;
  final String? attachmentId;
  final String? error;

  AttachmentUploadResult({
    required this.success,
    this.attachmentId,
    this.error,
  });
}

class AttachmentDownloadResult {
  final bool success;
  final List<int>? fileBytes;
  final String? error;

  AttachmentDownloadResult({
    required this.success,
    this.fileBytes,
    this.error,
  });
}