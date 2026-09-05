import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/localization/language_controller.dart';
import 'package:sehatmate_ai/localization/language_scope.dart';
import 'package:sehatmate_ai/screens/library_screens.dart';
import 'package:sehatmate_ai/services/document_service.dart';

void main() {
  testWidgets('DocumentsScreen renders real backend documents', (tester) async {
    await _pumpDocuments(tester, service: _FakeDocumentClient([_document()]));

    expect(find.text('rx.pdf'), findsOneWidget);
    expect(find.text('Recovery'), findsOneWidget);
    expect(find.text('Processed'), findsOneWidget);
    expect(find.textContaining('2 KB'), findsOneWidget);
    expect(
      find.text('Document preview is not available in this demo.'),
      findsNothing,
    );
  });

  testWidgets('DocumentsScreen shows empty state', (tester) async {
    await _pumpDocuments(tester, service: _FakeDocumentClient(const []));

    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('Upload document'), findsOneWidget);
  });

  testWidgets('DocumentsScreen fetches bytes before viewing', (tester) async {
    DocumentFile? viewed;
    final service = _FakeDocumentClient([_document()]);
    await _pumpDocuments(
      tester,
      service: service,
      fileViewer: (context, file) async => viewed = file,
    );

    final viewButton = find.byKey(const Key('document_view_7'));
    expect(viewButton, findsOneWidget);

    await tester.ensureVisible(viewButton);
    await tester.pumpAndSettle();

    await tester.tap(viewButton);
    await tester.pump();

    expect(service.fileFetches, ['7']);
    expect(viewed?.documentId, '7');
    expect(viewed?.bytes, _fileBytes);
    expect(viewed?.mimeType, 'image/png');
  });

  testWidgets('DocumentsScreen confirms delete with instruction warning', (
    tester,
  ) async {
    final service = _FakeDocumentClient([_document()]);
    await _pumpDocuments(tester, service: service);

    var deleteButton = find.byKey(const Key('document_delete_7'));
    expect(deleteButton, findsOneWidget);

    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('Delete document?'), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('rx.pdf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Recovery')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('4 extracted instruction'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('3 verified')),
      findsOneWidget,
    );
    expect(service.deleted, isEmpty);

    service.deleteFailures.add(
      const DocumentException('Delete failed', retryable: true),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
    await tester.pumpAndSettle();

    expect(service.deleted, ['7']);
    expect(find.text('rx.pdf'), findsOneWidget);
    expect(find.text('No documents yet'), findsNothing);

    deleteButton = find.byKey(const Key('document_delete_7'));
    expect(deleteButton, findsOneWidget);

    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(service.deleted, ['7']);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
    await tester.pumpAndSettle();

    expect(service.deleted, ['7', '7']);
    expect(service.listFetches, 2);
    expect(find.text('No documents yet'), findsOneWidget);
  });

  testWidgets('DocumentsScreen shows retryable offline state', (tester) async {
    final service = _FakeDocumentClient.sequence([
      const DocumentException('Network unavailable', retryable: true),
      [_document()],
    ]);

    await _pumpDocuments(tester, service: service);

    expect(find.text('Documents could not load'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);
    final retryButton = find.byKey(const Key('documents_retry_button'));
    expect(retryButton, findsOneWidget);
    expect(service.listFetches, 1);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(service.listFetches, 2);
    expect(find.text('rx.pdf'), findsOneWidget);
    expect(find.text('Network unavailable'), findsNothing);
  });
}

Future<void> _pumpDocuments(
  WidgetTester tester, {
  required DocumentClient service,
  DocumentFileViewer? fileViewer,
}) async {
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController.forTesting(),
      child: MaterialApp(
        home: DocumentsScreen(service: service, fileViewer: fileViewer),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _FakeDocumentClient implements DocumentClient {
  _FakeDocumentClient(List<CareDocument> documents)
    : _documents = List<CareDocument>.of(documents),
      _listResponses = [];

  _FakeDocumentClient.sequence(List<Object> responses)
    : _documents = [],
      _listResponses = List<Object>.of(responses);

  List<CareDocument> _documents;
  final List<Object> _listResponses;
  final fileFetches = <String>[];
  final deleted = <String>[];
  final deleteFailures = <Object>[];
  var listFetches = 0;

  @override
  Future<List<CareDocument>> listDocuments() async {
    listFetches += 1;
    if (_listResponses.isNotEmpty) {
      final response = _listResponses.removeAt(0);
      if (response is List<CareDocument>) {
        _documents = List<CareDocument>.of(response);
        return List<CareDocument>.of(_documents);
      }
      throw response;
    }
    return List<CareDocument>.of(_documents);
  }

  @override
  Future<DocumentFile> fetchDocumentFile(String documentId) async {
    fileFetches.add(documentId);
    return DocumentFile(
      documentId: documentId,
      originalName: 'rx.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(_fileBytes),
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    deleted.add(documentId);
    if (deleteFailures.isNotEmpty) {
      throw deleteFailures.removeAt(0);
    }
    _documents = _documents
        .where((document) => document.id != documentId)
        .toList();
  }
}

const _fileBytes = [137, 80, 78, 71];

CareDocument _document() {
  return CareDocument(
    id: '7',
    carePlanId: '3',
    carePlanTitle: 'Recovery',
    documentType: 'prescription',
    originalName: 'rx.pdf',
    mimeType: 'application/pdf',
    fileSizeBytes: 2048,
    pageCount: null,
    processingStatus: 'processed',
    processingError: null,
    createdAt: DateTime.utc(2026, 9, 1, 10),
    instructionCount: 4,
    verifiedInstructionCount: 3,
  );
}
