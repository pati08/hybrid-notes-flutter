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
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'phone_number': phoneNumber,
        },
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
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'phone_number': phoneNumber,
          'code': code,
        },
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
  Future<http.Response> makeAuthenticatedRequest(
    String endpoint, {
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
        return await http.post(url,
            headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        return await http.put(url,
            headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        return await http.get(url, headers: headers);
    }
  }

  // Upload attachment
  Future<AttachmentUploadResult> uploadAttachment(
      String filename, List<int> fileBytes) async {
    try {
      // Determine content type from filename
      String contentType = 'application/octet-stream';
      if (filename.toLowerCase().endsWith('.jpg') ||
          filename.toLowerCase().endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (filename.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (filename.toLowerCase().endsWith('.pdf')) {
        contentType = 'application/pdf';
      }

      // Step 1: Get upload URL and object_key from server
      final response = await makeAuthenticatedRequest(
        '/api/attachments/upload',
        method: 'POST',
        body: {
          'filename': filename,
          'content_type': contentType,
        },
      );

      if (response.statusCode != 200) {
        return AttachmentUploadResult(
          success: false,
          error: 'Failed to get upload URL: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final attachmentId = data['attachment_id'];
      final uploadUrl = data['upload_url'] as String;
      final objectKey = data['object_key'];

      // Step 2: Upload file to the correct endpoint
      // Check if upload_url is a full URL or a path
      Uri uploadUri;
      if (uploadUrl.startsWith('http://') || uploadUrl.startsWith('https://')) {
        // It's a full URL (presigned URL for external storage)
        uploadUri = Uri.parse(uploadUrl);
      } else {
        // It's a path, use our base URL
        uploadUri = Uri.parse('$_baseUrl$uploadUrl');
      }

      final uploadResponse = await http.put(
        uploadUri,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );

      if (uploadResponse.statusCode == 200) {
        return AttachmentUploadResult(
          success: true,
          attachmentId: attachmentId,
          objectKey: objectKey,
        );
      } else {
        return AttachmentUploadResult(
          success: false,
          error:
              'Upload failed: ${uploadResponse.statusCode} - ${uploadResponse.body}',
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
  Future<AttachmentDownloadResult> downloadAttachment(String attachmentId,
      {int expiresIn = 3600}) async {
    try {
      // Step 1: Get download URL from server
      final response = await makeAuthenticatedRequest(
          '/api/attachments/download/$attachmentId?expires_in=$expiresIn');

      if (response.statusCode != 200) {
        return AttachmentDownloadResult(
          success: false,
          error: 'Failed to get download URL: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final downloadUrl = data['download_url'];

      // Check if upload_url is a full URL or a path
      Uri downloadUri;
      if (downloadUrl.startsWith('http://') ||
          downloadUrl.startsWith('https://')) {
        // It's a full URL (presigned URL for external storage)
        downloadUri = Uri.parse(downloadUrl);
      } else {
        // It's a path, use our base URL
        downloadUri = Uri.parse('$_baseUrl$downloadUrl');
      }

      // Step 2: Download file from the provided URL
      final downloadResponse = await http.get(downloadUri);

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

  // Delete attachment
  Future<bool> deleteAttachment(String attachmentId) async {
    try {
      final response = await makeAuthenticatedRequest(
        '/api/attachments/delete/$attachmentId',
        method: 'POST',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Create a new document
  Future<DocumentResult> createDocument(String name) async {
    try {
      final response = await makeAuthenticatedRequest(
        '/api/docs/create/$name',
        method: 'POST',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentResult(
          success: true,
          document: data,
        );
      } else {
        return DocumentResult(
          success: false,
          error: 'Failed to create document: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DocumentResult(
        success: false,
        error: 'Error creating document: $e',
      );
    }
  }

  // Get a specific document
  Future<DocumentResult> getDocument(String documentId) async {
    try {
      final response =
          await makeAuthenticatedRequest('/api/docs/get/$documentId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentResult(
          success: true,
          document: data,
        );
      } else if (response.statusCode == 403) {
        return DocumentResult(
          success: false,
          error: 'Not authorized to access this document',
        );
      } else if (response.statusCode == 404) {
        return DocumentResult(
          success: false,
          error: 'Document not found',
        );
      } else {
        return DocumentResult(
          success: false,
          error: 'Failed to get document: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DocumentResult(
        success: false,
        error: 'Error getting document: $e',
      );
    }
  }

  // Save a document
  Future<bool> saveDocument(
      String documentId, List<Map<String, dynamic>> pages) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$_baseUrl/api/docs/save/$documentId');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(pages),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Rename a document
  Future<bool> renameDocument(String documentId, String newName) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse(
          '$_baseUrl/api/docs/rename/$documentId?new_name=${Uri.encodeComponent(newName)}');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // List all documents
  Future<DocumentListResult> listDocuments() async {
    try {
      final response = await makeAuthenticatedRequest('/api/docs/list');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return DocumentListResult(
            success: true,
            documents: data,
          );
        } else {
          return DocumentListResult(
            success: false,
            error: 'Invalid response format',
          );
        }
      } else {
        return DocumentListResult(
          success: false,
          error: 'Failed to list documents: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DocumentListResult(
        success: false,
        error: 'Error listing documents: $e',
      );
    }
  }

  // Get drawing list for a specific page
  Future<DrawingListResult> getDrawingList(String documentId, int pageIndex) async {
    try {
      final response = await makeAuthenticatedRequest(
        '/api/docs/get_drawing_list/$documentId/$pageIndex',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return DrawingListResult(
            success: true,
            drawingList: data,
          );
        } else {
          return DrawingListResult(
            success: false,
            error: 'Invalid response format',
          );
        }
      } else if (response.statusCode == 403) {
        return DrawingListResult(
          success: false,
          error: 'Not authorized to access this document',
        );
      } else if (response.statusCode == 404) {
        return DrawingListResult(
          success: false,
          error: 'Drawing list not found',
        );
      } else {
        return DrawingListResult(
          success: false,
          error: 'Failed to get drawing list: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DrawingListResult(
        success: false,
        error: 'Error getting drawing list: $e',
      );
    }
  }

  // Save drawing list for a specific page
  Future<bool> saveDrawingList(
    String documentId,
    int pageIndex,
    List<Map<String, dynamic>> drawingList,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('$_baseUrl/api/docs/save_drawing_list/$documentId/$pageIndex');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(drawingList),
      );

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      return false;
    }
  }

  // Handle API response
  AuthResult _handleResponse(http.Response response) {
    // For successful responses, empty body is OK (like /auth/start)
    if (response.statusCode == 200 && response.body.isEmpty) {
      return AuthResult(
        success: true,
        message: 'Success',
        statusCode: response.statusCode,
      );
    }

    // For error responses, empty body is a problem
    if (response.body.isEmpty) {
      return AuthResult(
        success: false,
        error: 'Server returned empty response. Status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      // Try to decode JSON
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
            error: data['error'] ?? 'Formatted number wrong (my fault)',
            statusCode: response.statusCode,
          );
        case 401:
          return AuthResult(
            success: false,
            error: data['error'] ??
                'They gave wrong code. Ask for right code again.',
            statusCode: response.statusCode,
          );
        case 500:
          return AuthResult(
            success: false,
            error: data['error'] ?? 'Server error, something went wrong',
            statusCode: response.statusCode,
          );
        default:
          return AuthResult(
            success: false,
            error: data['error'] ??
                'Unexpected error occurred (${response.statusCode})',
            statusCode: response.statusCode,
          );
      }
    } on FormatException catch (e) {
      // JSON parsing failed - for 200 responses, treat as success if body is empty
      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: 'Success',
          statusCode: response.statusCode,
        );
      }

      // For errors, show the response
      return AuthResult(
        success: false,
        error:
            'Server error: Invalid response format (Status ${response.statusCode}). Response: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
        statusCode: response.statusCode,
      );
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
  final String? objectKey;
  final String? error;

  AttachmentUploadResult({
    required this.success,
    this.attachmentId,
    this.objectKey,
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

class DocumentResult {
  final bool success;
  final Map<String, dynamic>? document;
  final String? error;

  DocumentResult({
    required this.success,
    this.document,
    this.error,
  });
}

class DocumentListResult {
  final bool success;
  final List<dynamic>? documents;
  final String? error;

  DocumentListResult({
    required this.success,
    this.documents,
    this.error,
  });
}

class DrawingListResult {
  final bool success;
  final List<dynamic>? drawingList;
  final String? error;

  DrawingListResult({
    required this.success,
    this.drawingList,
    this.error,
  });
}

