import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import 'auth_service.dart';

class DocumentException implements Exception {
  const DocumentException(
    this.message, {
    this.statusCode,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

class CareDocument {
  const CareDocument({
    required this.id,
    required this.carePlanId,
    required this.carePlanTitle,
    required this.documentType,
    required this.originalName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.processingStatus,
    required this.processingError,
    required this.createdAt,
    required this.instructionCount,
    required this.verifiedInstructionCount,
  });

  final String id;
  final String carePlanId;
  final String carePlanTitle;
  final String documentType;
  final String originalName;
  final String mimeType;
  final int fileSizeBytes;
  final int? pageCount;
  final String processingStatus;
  final String? processingError;
  final DateTime? createdAt;
  final int instructionCount;
  final int verifiedInstructionCount;

  bool get hasVerifiedInstructions => verifiedInstructionCount > 0;
  bool get hasInstructions => instructionCount > 0;
}

class DocumentFile {
  const DocumentFile({
    required this.documentId,
    required this.originalName,
    required this.mimeType,
    required this.bytes,
  });

  final String documentId;
  final String originalName;
  final String mimeType;
  final Uint8List bytes;

  bool get isImage =>
      mimeType == 'image/png' ||
      mimeType == 'image/jpeg' ||
      originalName.toLowerCase().endsWith('.png') ||
      originalName.toLowerCase().endsWith('.jpg') ||
      originalName.toLowerCase().endsWith('.jpeg');

  bool get isPdf =>
      mimeType == 'application/pdf' ||
      originalName.toLowerCase().endsWith('.pdf');
}

abstract class DocumentClient {
  Future<List<CareDocument>> listDocuments();
  Future<DocumentFile> fetchDocumentFile(String documentId);
  Future<void> deleteDocument(String documentId);
}

class DocumentService implements DocumentClient {
  DocumentService({http.Client? client, String? Function()? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? (() => AuthSession.instance.token);

  static final DocumentService instance = DocumentService();
  static const _timeout = Duration(seconds: 25);

  final http.Client _client;
  final String? Function() _tokenProvider;

  @override
  Future<List<CareDocument>> listDocuments() async {
    final data = await _jsonRequest('GET', '/documents');
    final documents = data['documents'] is List
        ? data['documents'] as List
        : const [];
    return documents
        .whereType<Map<String, dynamic>>()
        .map(_documentFromJson)
        .where((document) => document.id.isNotEmpty)
        .toList();
  }

  @override
  Future<DocumentFile> fetchDocumentFile(String documentId) async {
    final token = _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const DocumentException('Please sign in to continue.');
    }

    try {
      final response = await _client
          .get(
            ApiConfig.endpoint('/documents/$documentId/file'),
            headers: {
              'Accept': 'application/pdf,image/png,image/jpeg,*/*',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFromResponse(response);
      }
      final mimeType =
          response.headers['content-type']
              ?.split(';')
              .first
              .trim()
              .toLowerCase() ??
          'application/octet-stream';
      return DocumentFile(
        documentId: documentId,
        originalName:
            _filenameFromDisposition(response.headers['content-disposition']) ??
            'document',
        mimeType: mimeType,
        bytes: Uint8List.fromList(response.bodyBytes),
      );
    } on TimeoutException {
      throw const DocumentException(
        'Could not connect to SehatMate. Please try again.',
        retryable: true,
      );
    } on http.ClientException {
      throw const DocumentException(
        'Could not connect to SehatMate. Please check your connection.',
        retryable: true,
      );
    }
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _jsonRequest('DELETE', '/documents/$documentId');
  }

  Future<Map<String, dynamic>> _jsonRequest(String method, String path) async {
    final token = _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const DocumentException('Please sign in to continue.');
    }

    try {
      late final http.Response response;
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final uri = ApiConfig.endpoint(path);
      if (method == 'DELETE') {
        response = await _client
            .delete(uri, headers: headers)
            .timeout(_timeout);
      } else {
        response = await _client.get(uri, headers: headers).timeout(_timeout);
      }
      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DocumentException(
          decoded['message']?.toString() ??
              'Document request could not be completed.',
          statusCode: response.statusCode,
          retryable:
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
        );
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      throw const DocumentException(
        'The server returned invalid document data.',
      );
    } on TimeoutException {
      throw const DocumentException(
        'Could not connect to SehatMate. Please try again.',
        retryable: true,
      );
    } on http.ClientException {
      throw const DocumentException(
        'Could not connect to SehatMate. Please check your connection.',
        retryable: true,
      );
    } on FormatException {
      throw const DocumentException(
        'The server returned invalid document data.',
      );
    }
  }

  DocumentException _errorFromResponse(http.Response response) {
    try {
      final decoded = _decode(response);
      return DocumentException(
        decoded['message']?.toString() ??
            'Document request could not be completed.',
        statusCode: response.statusCode,
        retryable:
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500,
      );
    } on FormatException {
      return DocumentException(
        'Document request could not be completed.',
        statusCode: response.statusCode,
        retryable:
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500,
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object.');
  }

  CareDocument _documentFromJson(Map<String, dynamic> json) {
    return CareDocument(
      id: _text(json['id']),
      carePlanId: _text(json['carePlanId']),
      carePlanTitle: _text(json['carePlanTitle']).isEmpty
          ? 'Care plan'
          : _text(json['carePlanTitle']),
      documentType: _text(json['documentType']).isEmpty
          ? 'other'
          : _text(json['documentType']),
      originalName: _text(json['originalName']).isEmpty
          ? 'Document'
          : _text(json['originalName']),
      mimeType: _text(json['mimeType']),
      fileSizeBytes: _int(json['fileSizeBytes']),
      pageCount: json['pageCount'] == null ? null : _int(json['pageCount']),
      processingStatus: _text(json['processingStatus']).isEmpty
          ? 'uploaded'
          : _text(json['processingStatus']),
      processingError: _text(json['processingError']).isEmpty
          ? null
          : _text(json['processingError']),
      createdAt: DateTime.tryParse(_text(json['createdAt'])),
      instructionCount: _int(json['instructionCount']),
      verifiedInstructionCount: _int(json['verifiedInstructionCount']),
    );
  }

  String? _filenameFromDisposition(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final encoded = RegExp("filename\\*=UTF-8''([^;]+)").firstMatch(value);
    if (encoded != null) {
      return Uri.decodeComponent(encoded.group(1) ?? '').trim();
    }
    final quoted = RegExp('filename="([^"]+)"').firstMatch(value);
    if (quoted != null) return quoted.group(1)?.trim();
    return null;
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value) =>
      value
          ?.toString()
          .replaceAll(
            RegExp(r'[\u0000-\u001F\u007F\u200B-\u200D\u2060\uFEFF]'),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim() ??
      '';
}
