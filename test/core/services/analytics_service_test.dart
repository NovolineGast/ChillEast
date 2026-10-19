import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnalyticsService', () {
    test('generateUuid produces valid RFC 4122 v4 UUID format', () {
      final uuid = AnalyticsService.generateUuid();
      expect(uuid.length, 36);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(uuid),
        isTrue,
      );
    });

    test('isEnabled defaults to true', () async {
      final enabled = await AnalyticsService.isEnabled();
      expect(enabled, isTrue);
    });

    test('setEnabled persists preference locally', () async {
      await AnalyticsService.setEnabled(false);
      expect(await AnalyticsService.isEnabled(), isFalse);

      await AnalyticsService.setEnabled(true);
      expect(await AnalyticsService.isEnabled(), isTrue);
    });

    test('getOrCreateUuid creates and persists UUID consistently', () async {
      final id1 = await AnalyticsService.getOrCreateUuid();
      expect(id1.isNotEmpty, isTrue);

      final id2 = await AnalyticsService.getOrCreateUuid();
      expect(id2, equals(id1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AnalyticsService.uuidKey), equals(id1));
    });
  });
}
