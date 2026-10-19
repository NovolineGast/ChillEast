import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/utils/atomic_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atomic_storage_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicStorageHelper', () {
    test('atomicWriteString creates file and writes content', () async {
      final file = File('${tempDir.path}/test.json');
      await AtomicStorageHelper.atomicWriteString(file, '{"a": 1}');

      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '{"a": 1}');
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });

    test('atomicWriteString creates .bak on subsequent writes', () async {
      final file = File('${tempDir.path}/test.json');
      await AtomicStorageHelper.atomicWriteString(file, '{"version": 1}');
      await AtomicStorageHelper.atomicWriteString(file, '{"version": 2}');

      expect(await file.readAsString(), '{"version": 2}');
      final bakFile = File('${file.path}.bak');
      expect(await bakFile.exists(), isTrue);
      expect(await bakFile.readAsString(), '{"version": 1}');
    });

    test('readJsonWithRecovery recovers from .bak on FormatException', () async {
      final file = File('${tempDir.path}/test.json');
      // Write version 1 -> creates original
      await AtomicStorageHelper.atomicWriteString(file, '{"data": "valid_v1"}');
      // Write version 2 -> creates .bak with v1, file has v2
      await AtomicStorageHelper.atomicWriteString(file, '{"data": "valid_v2"}');

      // Now corrupt the primary file
      await file.writeAsString('{corrupted json content!!!');

      // Attempt reading
      final result = await AtomicStorageHelper.readJsonWithRecovery(file);
      expect(result, isNotNull);
      expect(result['data'], 'valid_v1');

      // Verify corrupted file was quarantined
      final quarantinedFiles = tempDir
          .listSync()
          .where((f) => f.path.contains('test.json.corrupted.'));
      expect(quarantinedFiles.isNotEmpty, isTrue);

      // Verify file was restored from .bak
      expect(await file.readAsString(), '{"data": "valid_v1"}');
    });

    test('readJsonWithRecovery quarantines file and returns null when no .bak exists', () async {
      final file = File('${tempDir.path}/test.json');
      await file.writeAsString('{not valid json}');

      final result = await AtomicStorageHelper.readJsonWithRecovery(file);
      expect(result, isNull);

      final quarantinedFiles = tempDir
          .listSync()
          .where((f) => f.path.contains('test.json.corrupted.'));
      expect(quarantinedFiles.isNotEmpty, isTrue);
    });

    test('deleteWithBackups removes target, .tmp, and .bak', () async {
      final file = File('${tempDir.path}/test.json');
      final tmpFile = File('${file.path}.tmp');
      final bakFile = File('${file.path}.bak');

      await file.writeAsString('a');
      await tmpFile.writeAsString('b');
      await bakFile.writeAsString('c');

      await AtomicStorageHelper.deleteWithBackups(file);
      expect(await file.exists(), isFalse);
      expect(await tmpFile.exists(), isFalse);
      expect(await bakFile.exists(), isFalse);
    });
  });
}
