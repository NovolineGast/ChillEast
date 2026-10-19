import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/profile/services/backup_export_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_subscription_service.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TimetableSubscriptionService', () {
    test('generateUuid produces valid RFC 4122 v4 UUID', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      final uuids = <String>{};
      for (int i = 0; i < 50; i++) {
        final uuid = TimetableSubscriptionService.generateUuid();
        expect(uuid.length, 36);
        expect(uuidRegex.hasMatch(uuid), isTrue,
            reason: 'UUID $uuid does not match v4 pattern');
        uuids.add(uuid);
      }
      expect(uuids.length, 50, reason: 'Generated UUIDs must be unique');
    });

    test('buildSubscriptionUrl and buildWebcalUrl construct expected URLs', () {
      const testUuid = '12345678-1234-4234-8234-123456789abc';
      final subUrl =
          TimetableSubscriptionService.buildSubscriptionUrl(testUuid);
      expect(subUrl,
          'https://ics.chilleast.soilzhu.su/12345678-1234-4234-8234-123456789abc/timetable.ics');

      final webcalUrl =
          TimetableSubscriptionService.buildWebcalUrl(testUuid);
      expect(webcalUrl,
          'webcal://ics.chilleast.soilzhu.su/12345678-1234-4234-8234-123456789abc/timetable.ics');
    });

    test('getOrCreateUuid retrieves saved or generates and persists new UUID',
        () async {
      final service = TimetableSubscriptionService();

      expect(await service.getUuid(), isNull);

      final uuid1 = await service.getOrCreateUuid();
      expect(uuid1, isNotEmpty);
      expect(await service.getUuid(), uuid1);

      // Subsequent call should return the exact same UUID
      final uuid2 = await service.getOrCreateUuid();
      expect(uuid2, uuid1);
    });

    test('uploadTimetable performs HTTP PUT to R2 subscription URL', () async {
      String? requestedMethod;
      String? requestedUrl;
      dynamic requestedData;
      String? requestedContentType;

      final dio = Dio();
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        requestedMethod = options.method;
        requestedUrl = options.uri.toString();
        requestedData = options.data;
        requestedContentType = options.headers['Content-Type'];

        return ResponseBody.fromString(
          '{"success":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          TimetableSubscriptionService.subscriptionEnabledKey, true);
      await prefs.setString(
          TimetableSubscriptionService.subscriptionUuidKey,
          'test-uuid-12345');

      final service = TimetableSubscriptionService(dio: dio);

      const ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
      final result = await service.uploadTimetable(icsContent: ics);

      expect(result, isTrue);
      expect(requestedMethod, 'PUT');
      expect(requestedUrl,
          'https://ics.chilleast.soilzhu.su/test-uuid-12345/timetable.ics');
      expect(requestedData, ics);
      expect(requestedContentType, 'text/calendar; charset=utf-8');
    });

    test('deleteRemoteTimetable performs HTTP DELETE to R2 subscription URL',
        () async {
      String? requestedMethod;
      String? requestedUrl;

      final dio = Dio();
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        requestedMethod = options.method;
        requestedUrl = options.uri.toString();

        return ResponseBody.fromString(
          '{"success":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          TimetableSubscriptionService.subscriptionUuidKey,
          'test-uuid-delete');

      final service = TimetableSubscriptionService(dio: dio);
      final result = await service.deleteRemoteTimetable();

      expect(result, isTrue);
      expect(requestedMethod, 'DELETE');
      expect(requestedUrl,
          'https://ics.chilleast.soilzhu.su/test-uuid-delete/timetable.ics');
    });

    test('resetUuid deletes old subscription and generates new UUID', () async {
      final requestedUrls = <String>[];
      final requestedMethods = <String>[];

      final dio = Dio();
      dio.httpClientAdapter = MockHttpClientAdapter((options) async {
        requestedMethods.add(options.method);
        requestedUrls.add(options.uri.toString());

        return ResponseBody.fromString(
          '{"success":true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          TimetableSubscriptionService.subscriptionEnabledKey, true);
      await prefs.setString(
          TimetableSubscriptionService.subscriptionUuidKey,
          'old-uuid-111');

      final service = TimetableSubscriptionService(dio: dio);
      final newUuid = await service.resetUuid();

      expect(newUuid, isNot('old-uuid-111'));
      expect(await service.getUuid(), newUuid);
      expect(requestedMethods, contains('DELETE'));
      expect(requestedUrls.first,
          'https://ics.chilleast.soilzhu.su/old-uuid-111/timetable.ics');
    });
  });

  group('BackupExportService - TimetableSubscription integration', () {
    test('buildBackupData includes timetableSubscription settings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          TimetableSubscriptionService.subscriptionEnabledKey, true);
      await prefs.setString(
          TimetableSubscriptionService.subscriptionUuidKey,
          'backed-up-uuid-999');

      final backup = await BackupExportService.buildBackupData();
      final settings = backup['settings'] as Map<String, dynamic>;
      final sub = settings['timetableSubscription'] as Map<String, dynamic>;

      expect(sub['enabled'], isTrue);
      expect(sub['uuid'], 'backed-up-uuid-999');
    });

    test('applyBackupData restores timetableSubscription settings', () async {
      final prefs = await SharedPreferences.getInstance();
      final backup = {
        'format': BackupExportService.backupFormat,
        'version': BackupExportService.backupVersion,
        'settings': {
          'timetableSubscription': {
            'enabled': true,
            'uuid': 'restored-uuid-888',
          },
        },
        'localData': {},
      };

      await BackupExportService.applyBackupData(backup);

      expect(
        prefs.getBool(TimetableSubscriptionService.subscriptionEnabledKey),
        isTrue,
      );
      expect(
        prefs.getString(TimetableSubscriptionService.subscriptionUuidKey),
        'restored-uuid-888',
      );
    });
  });
}
