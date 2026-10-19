import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/utils/ics_export_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('ics-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  group('IcsExportHelper Tests', () {
    test('saveIcs writes content to temporary file successfully', () async {
      const content = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
      const filename = 'test_timetable.ics';

      final path = await IcsExportHelper.saveIcs(content, filename);
      expect(path, '${tempDir.path}/$filename');

      final file = io.File(path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), content);
    });

    test('saveIcs throws wrapped Exception on disk error', () async {
      // Point path provider to an invalid path that cannot be written
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => '/invalid_non_existing_dir/sub');

      expect(
        () => IcsExportHelper.saveIcs('test', 'fail.ics'),
        throwsA(isA<Exception>()),
      );

      // Restore tempDir
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path);
    });
  });
}
