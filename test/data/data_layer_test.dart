import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/data/app_database.dart';
import 'package:app/data/enums.dart';
import 'package:app/data/models.dart';
import 'package:app/data/repositories/documents_repository.dart';
import 'package:app/data/repositories/pipeline_repository.dart';
import 'package:app/data/repositories/results_repository.dart';

void main() {
  late AppDatabase db;
  late DocumentsRepository docs;
  late PipelineRepository pipe;
  late ResultsRepository results;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    docs = DocumentsRepository(db);
    pipe = PipelineRepository(db);
    results = ResultsRepository(db);
    await docs.create(PdfRecord(
      id: 'd1',
      name: 'a.pdf',
      sizeBytes: 10,
      status: DocStatus.processing,
      createdAt: 1,
      updatedAt: 1,
    ));
  });

  tearDown(() => db.close());

  test('delete cascades to pages, stages, chunks and results', () async {
    await docs.savePage(PageText(
        documentId: 'd1', pageNumber: 1, text: 'hi', method: PageMethod.direct));
    await pipe.initStages('d1', ['extract', 'summary']);
    await pipe.saveChunk('d1', 'summary', 0, 'x');
    await results.save('d1', 'summary', {'text': 'ok'});

    await docs.delete('d1');

    expect(await docs.pages('d1'), isEmpty);
    expect(await pipe.stages('d1'), isEmpty);
    expect(await pipe.completedChunks('d1', 'summary'), isEmpty);
    expect(await results.get('d1', 'summary'), isNull);
  });

  test('recoverInterrupted pauses running stages and processing docs', () async {
    await pipe.initStages('d1', ['extract']);
    await pipe.markRunning('d1', 'extract');

    final fixed = await pipe.recoverInterrupted();

    expect(fixed, 1);
    expect((await pipe.stages('d1')).first.status, StageStatus.paused);
    expect((await docs.get('d1'))!.status, DocStatus.paused);
  });

  test('results round-trip as JSON', () async {
    await results.save('d1', 'quiz', {'q': ['a', 'b']});
    expect(await results.get('d1', 'quiz'), {'q': ['a', 'b']});
  });

  test('pendingOcrPageNumbers lists only pages that still need OCR', () async {
    await docs.savePage(PageText(
        documentId: 'd1', pageNumber: 1, text: 'x', method: PageMethod.direct));
    await docs.savePage(PageText(
        documentId: 'd1', pageNumber: 2, text: '', method: PageMethod.pendingOcr));
    await docs.savePage(PageText(
        documentId: 'd1', pageNumber: 3, text: 'y', method: PageMethod.ocr));

    expect(await docs.pendingOcrPageNumbers('d1'), [2]);
    expect((await docs.pageMethodCounts('d1'))[PageMethod.ocr], 1);
  });
}
