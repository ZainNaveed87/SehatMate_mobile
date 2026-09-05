import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sehatmate_ai/services/document_service.dart';

void main() {
  group('DocumentService', () {
    test('listDocuments sends auth and parses metadata only', () async {
      final service = DocumentService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/documents');
          expect(request.headers['Authorization'], 'Bearer session-token');
          expect(request.url.queryParameters.containsKey('userId'), isFalse);

          return _jsonResponse({
            'data': {
              'documents': [_documentJson()],
            },
          });
        }),
      );

      final documents = await service.listDocuments();

      expect(documents, hasLength(1));
      expect(documents.single.originalName, 'rx.pdf');
      expect(documents.single.carePlanTitle, 'Recovery');
      expect(documents.single.pageCount, isNull);
      expect(documents.single.instructionCount, 4);
      expect(documents.single.verifiedInstructionCount, 3);
    });

    test('fetchDocumentFile uses auth header and never token in URL', () async {
      final bytes = utf8.encode('%PDF-1.4');
      final service = DocumentService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/documents/7/file');
          expect(request.url.toString(), isNot(contains('session-token')));
          expect(request.headers['Authorization'], 'Bearer session-token');
          return http.Response.bytes(
            bytes,
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition':
                  'inline; filename="rx.pdf"; filename*=UTF-8\'\'rx.pdf',
            },
          );
        }),
      );

      final file = await service.fetchDocumentFile('7');

      expect(file.mimeType, 'application/pdf');
      expect(file.originalName, 'rx.pdf');
      expect(file.bytes, bytes);
      expect(file.isPdf, isTrue);
    });

    test('deleteDocument calls authenticated DELETE', () async {
      final service = DocumentService(
        tokenProvider: () => 'session-token',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/documents/7');
          expect(request.headers['Authorization'], 'Bearer session-token');
          return _jsonResponse({'data': {}});
        }),
      );

      await service.deleteDocument('7');
    });

    test('throws before HTTP when no auth token is available', () async {
      var called = false;
      final service = DocumentService(
        tokenProvider: () => null,
        client: MockClient((_) async {
          called = true;
          return _jsonResponse({});
        }),
      );

      await expectLater(
        service.listDocuments(),
        throwsA(isA<DocumentException>()),
      );
      expect(called, isFalse);
    });
  });
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _documentJson() => {
  'id': '7',
  'carePlanId': '3',
  'carePlanTitle': 'Recovery',
  'documentType': 'prescription',
  'originalName': 'rx.pdf',
  'mimeType': 'application/pdf',
  'fileSizeBytes': 2048,
  'pageCount': null,
  'processingStatus': 'processed',
  'processingError': null,
  'createdAt': '2026-09-01T10:00:00Z',
  'instructionCount': 4,
  'verifiedInstructionCount': 3,
  'fileData': 'must not be required by the client',
  'storagePath': 'must not be required by the client',
};
