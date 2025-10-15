import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage document metadata including last modified times
class DocumentMetadataService {
  static final DocumentMetadataService _instance = DocumentMetadataService._internal();
  factory DocumentMetadataService() => _instance;
  DocumentMetadataService._internal();

  static const String _metadataKey = 'document_metadata';
  
  /// Document metadata structure
  static const String _lastModifiedKey = 'lastModified';
  static const String _createdAtKey = 'createdAt';
  static const String _titleKey = 'title';

  /// Get all document metadata
  Future<Map<String, Map<String, dynamic>>> getAllMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? metadataJson = prefs.getString(_metadataKey);
      
      if (metadataJson == null || metadataJson.isEmpty) {
        return {};
      }
      
      final Map<String, dynamic> decoded = jsonDecode(metadataJson);
      return decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
    } catch (e) {
      return {};
    }
  }

  /// Get metadata for a specific document
  Future<Map<String, dynamic>?> getDocumentMetadata(String documentId) async {
    final allMetadata = await getAllMetadata();
    return allMetadata[documentId];
  }

  /// Get last modified time for a document
  Future<DateTime?> getLastModified(String documentId) async {
    final metadata = await getDocumentMetadata(documentId);
    if (metadata == null || !metadata.containsKey(_lastModifiedKey)) {
      return null;
    }
    
    final timestamp = metadata[_lastModifiedKey];
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    
    return null;
  }

  /// Update last modified time for a document
  Future<void> updateLastModified(String documentId, {String? title}) async {
    final allMetadata = await getAllMetadata();
    
    // Get existing metadata or create new
    final metadata = allMetadata[documentId] ?? {};
    
    // Update last modified time
    metadata[_lastModifiedKey] = DateTime.now().millisecondsSinceEpoch;
    
    // Update title if provided
    if (title != null) {
      metadata[_titleKey] = title;
    }
    
    // Set created time if not already set
    if (!metadata.containsKey(_createdAtKey)) {
      metadata[_createdAtKey] = DateTime.now().millisecondsSinceEpoch;
    }
    
    // Save back to preferences
    allMetadata[documentId] = metadata;
    await _saveAllMetadata(allMetadata);
  }

  /// Update document title
  Future<void> updateTitle(String documentId, String title) async {
    final allMetadata = await getAllMetadata();
    
    final metadata = allMetadata[documentId] ?? {};
    metadata[_titleKey] = title;
    
    allMetadata[documentId] = metadata;
    await _saveAllMetadata(allMetadata);
  }

  /// Remove metadata for a document
  Future<void> removeDocumentMetadata(String documentId) async {
    final allMetadata = await getAllMetadata();
    allMetadata.remove(documentId);
    await _saveAllMetadata(allMetadata);
  }

  /// Get documents sorted by last modified time (most recent first)
  Future<List<Map<String, dynamic>>> getDocumentsSortedByLastModified(
    List<Map<String, dynamic>> documents
  ) async {
    final allMetadata = await getAllMetadata();
    
    // Create a list with metadata
    final List<Map<String, dynamic>> documentsWithMetadata = documents.map((doc) {
      final documentId = doc['id']?.toString() ?? '';
      final metadata = allMetadata[documentId] ?? {};
      
      return {
        ...doc,
        'lastModified': metadata[_lastModifiedKey],
        'createdAt': metadata[_createdAtKey],
        'localTitle': metadata[_titleKey],
      };
    }).toList();
    
    // Sort by last modified time (most recent first)
    documentsWithMetadata.sort((a, b) {
      final aTime = a['lastModified'] as int? ?? 0;
      final bTime = b['lastModified'] as int? ?? 0;
      return bTime.compareTo(aTime); // Descending order
    });
    
    return documentsWithMetadata;
  }

  /// Initialize metadata for documents that don't have it
  Future<void> initializeMissingMetadata(List<Map<String, dynamic>> documents) async {
    final allMetadata = await getAllMetadata();
    bool hasChanges = false;
    
    for (final doc in documents) {
      final documentId = doc['id']?.toString() ?? '';
      if (!allMetadata.containsKey(documentId)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        allMetadata[documentId] = {
          _lastModifiedKey: now,
          _createdAtKey: now,
          _titleKey: doc['name']?.toString() ?? 'Untitled',
        };
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveAllMetadata(allMetadata);
    }
  }

  /// Clear all metadata
  Future<void> clearAllMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_metadataKey);
  }

  /// Save all metadata to SharedPreferences
  Future<void> _saveAllMetadata(Map<String, Map<String, dynamic>> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String metadataJson = jsonEncode(metadata);
      await prefs.setString(_metadataKey, metadataJson);
    } catch (e) {
      // Handle error silently or log it
    }
  }

  /// Get formatted last modified time string
  String formatLastModified(DateTime? lastModified) {
    if (lastModified == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(lastModified);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}