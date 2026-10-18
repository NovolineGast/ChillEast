import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/cloudisk/services/cloud_backup_manager.dart';
import 'package:ChillEast/features/cloudisk/services/cloudisk_service.dart';

void main() {
  group('CloudBackupManager.buildFileName', () {
    test('formats slot + timestamp', () {
      expect(
        CloudBackupManager.buildFileName('a', DateTime(2026, 9, 26, 9, 30, 15)),
        'chilleast-backup-a-20260926-093015.json',
      );
    });

    test('lexicographic order matches chronological order', () {
      final earlier = CloudBackupManager.buildFileName(
          'a', DateTime(2026, 9, 26, 9, 30, 15));
      final later = CloudBackupManager.buildFileName(
          'a', DateTime(2026, 9, 26, 9, 31, 2));
      expect(earlier.compareTo(later) < 0, isTrue);
    });
    test('defaults to slot b', () {
      expect(
        CloudBackupManager.buildFileName(
            CloudBackupManager.fixedSlot, DateTime(2026, 9, 26, 9, 30, 15)),
        'chilleast-backup-b-20260926-093015.json',
      );
    });
  });

  group('CloudBackupManager.parseFileName', () {
    test('round-trips buildFileName', () {
      const name = 'chilleast-backup-b-20260926-093015.json';
      final parsed = CloudBackupManager.parseFileName(name);
      expect(parsed, isNotNull);
      expect(parsed!.slot, 'b');
      expect(parsed.stamp, '20260926-093015');
    });

    test('rejects foreign names', () {
      expect(CloudBackupManager.parseFileName('pubspec.yaml'), isNull);
      expect(
          CloudBackupManager.parseFileName('chilleast-backup-c-20260926.json'),
          isNull);
      expect(
          CloudBackupManager.parseFileName('chilleast-backup-a-latest.json'),
          isNull);
    });
  });

  group('CloudBackupManager.pickTargetSlot', () {
    test('always returns b', () {
      expect(CloudBackupManager.pickTargetSlot(null), 'b');
      expect(CloudBackupManager.pickTargetSlot('a'), 'b');
      expect(CloudBackupManager.pickTargetSlot('b'), 'b');
    });
  });

  group('CloudBackupManager.pickStaleEntries', () {
    List<Map<String, dynamic>> fiveBackups() => [
          {
            'id': 'resid-1',
            'name': 'chilleast-backup-b-20260928-120000.json',
            'encryptedId': 'enc-1',
            'puid': '1',
          },
          {
            'id': 'resid-2',
            'name': 'chilleast-backup-b-20260927-120000.json',
            'encryptedId': 'enc-2',
            'puid': '1',
          },
          {
            'id': 'resid-3',
            'name': 'chilleast-backup-b-20260926-120000.json',
            'encryptedId': 'enc-3',
            'puid': '1',
          },
          {
            'id': 'resid-4',
            'name': 'chilleast-backup-a-20260925-120000.json',
            'encryptedId': 'enc-4',
            'puid': '1',
          },
          {
            'id': 'resid-5',
            'name': 'chilleast-backup-a-20260924-120000.json',
            'encryptedId': 'enc-5',
            'puid': '1',
          },
          {
            'id': 'other',
            'name': 'pubspec.yaml',
            'encryptedId': 'enc-x',
            'puid': '1',
          },
        ];

    test('retains strictly 3 latest backups by default, flags older snapshots', () {
      final stale =
          CloudBackupManager.pickStaleEntries(fiveBackups(), 'resid-1');
      // Latest 3 (resid-1, resid-2, resid-3) are kept. Older 2 are stale.
      expect(stale.map((e) => e['resid']), ['resid-4', 'resid-5']);
    });

    test('guarantees keepResid is kept within the 3 retained snapshots', () {
      // Even if keepResid is resid-4 (chronologically 4th), it must be preserved
      final stale =
          CloudBackupManager.pickStaleEntries(fiveBackups(), 'resid-4');
      // Kept: resid-4 (forced), resid-1, resid-2 (total 3)
      // Stale: resid-3, resid-5
      expect(stale.map((e) => e['resid']), containsAll(['resid-3', 'resid-5']));
      expect(stale.map((e) => e['resid']), isNot(contains('resid-4')));
    });

    test('keeps all entries when count <= 3', () {
      final entries = fiveBackups().take(2).toList();
      final stale = CloudBackupManager.pickStaleEntries(entries, 'resid-1');
      expect(stale, isEmpty);
    });

    test('ignores non-backup files', () {
      final stale =
          CloudBackupManager.pickStaleEntries(fiveBackups(), 'resid-1');
      expect(stale.map((e) => e['resid']), isNot(contains('other')));
    });

    test('supports custom keepCount override', () {
      final stale = CloudBackupManager.pickStaleEntries(
        fiveBackups(),
        'resid-1',
        keepCount: 1,
      );
      expect(stale.map((e) => e['resid']),
          ['resid-2', 'resid-3', 'resid-4', 'resid-5']);
    });
  });

  group('Sidecar and Companion sync', () {
    test('pickSidecarEntry identifies chilleast-sidecar-v2.json', () {
      final entries = [
        {
          'id': 'sc-1',
          'name': 'chilleast-sidecar-v2.json',
          'encryptedId': 'enc-sc',
          'puid': '1',
        },
        {
          'id': 'b-1',
          'name': 'chilleast-backup-b-20260926-093015.json',
          'encryptedId': 'enc-b',
          'puid': '1',
        },
      ];
      final sc = CloudBackupManager.pickSidecarEntry(entries);
      expect(sc, isNotNull);
      expect(sc!['resid'], 'sc-1');
      expect(sc['name'], 'chilleast-sidecar-v2.json');
    });

    test('buildSidecarData extracts version-specific fields', () {
      final backup = {
        'format': 'chilleast-backup',
        'settings': {
          'customCourseColors': {'c1': 0xFF00FF},
          'timetableSubscription': {'enabled': true, 'uuid': 'sub-uuid'},
          'electricityRoom2': {'room': '102'},
          'appearance': {
            'feedAutoSort': true,
          },
        },
        'localData': {
          'examList': [
            {'id': 'ex-1', 'title': '期末考'}
          ],
          'aiMemories': [
            {'id': 'mem-1', 'content': '寝室601'}
          ],
        },
      };

      final sidecar = CloudBackupManager.buildSidecarData(backup);
      expect(sidecar['format'], 'chilleast-sidecar');
      expect(sidecar['customCourseColors'], {'c1': 0xFF00FF});
      expect(sidecar['timetableSubscription']['uuid'], 'sub-uuid');
      expect(sidecar['electricityRoom2'], {'room': '102'});
      expect(sidecar['feedAutoSort'], isTrue);
      expect((sidecar['examList'] as List).first['id'], 'ex-1');
      expect((sidecar['aiMemories'] as List).first['id'], 'mem-1');
    });

    test('mergeSidecar complements missing fields from sidecar into old main backup', () {
      // 老版本 main 1.0.12 生成的主快照（缺失新字段）
      final oldBackup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {
          'languageCode': 'zh',
          'courseReminderMinutes': 15,
          'appearance': {'homeItems': []},
        },
        'localData': {
          'timetableIcs': 'BEGIN:VCALENDAR...',
          'courses': [],
        },
      };

      final sidecar = {
        'format': 'chilleast-sidecar',
        'version': 2,
        'customCourseColors': {'c1': 0x123456},
        'timetableSubscription': {'enabled': true, 'uuid': 'uuid-123'},
        'electricityRoom2': {'room': '305'},
        'feedAutoSort': true,
        'examList': [
          {'id': 'ex-99', 'title': '高等数学'}
        ],
        'aiMemories': [
          {'id': 'mem-99', 'content': '自习室三楼'}
        ],
      };

      final merged = CloudBackupManager.mergeSidecar(oldBackup, sidecar);
      final settings = merged['settings'] as Map<String, dynamic>;
      final localData = merged['localData'] as Map<String, dynamic>;

      expect(settings['languageCode'], 'zh');
      expect(settings['customCourseColors'], {'c1': 0x123456});
      expect(settings['timetableSubscription']['uuid'], 'uuid-123');
      expect(settings['electricityRoom2'], {'room': '305'});
      expect(settings['appearance']['feedAutoSort'], isTrue);
      expect((localData['examList'] as List).first['id'], 'ex-99');
      expect((localData['aiMemories'] as List).first['id'], 'mem-99');
    });
  });

  group('CloudBackupManager.pickLatestBackupEntry', () {
    List<Map<String, dynamic>> entries() => [
          {
            'id': 'old-resid',
            'name': 'chilleast-backup-a-20260925-220000.json',
            'encryptedId': 'enc-old',
            'puid': '1',
          },
          {
            'id': 'new-resid',
            'name': 'chilleast-backup-b-20260926-093015.json',
            'encryptedId': 'enc-new',
            'puid': '1',
          },
          {
            'id': 'other',
            'name': 'pubspec.yaml',
            'encryptedId': 'enc-x',
            'puid': '1',
          },
          {
            'id': 'broken',
            'name': 'chilleast-backup-a-20260927-000000.json',
            'encryptedId': '',
            'puid': '1',
          },
        ];

    test('picks newest by stamp, ignores foreign and broken entries', () {
      final latest = CloudBackupManager.pickLatestBackupEntry(entries());
      expect(latest, isNotNull);
      expect(latest!['resid'], 'new-resid');
      expect(latest['slot'], 'b');
    });

    test('picks newest by stamp even if newer is slot a and older is slot b', () {
      final crossSlotEntries = [
        {
          'id': 'older-b',
          'name': 'chilleast-backup-b-20260925-100000.json',
          'encryptedId': 'enc-b',
          'puid': '1',
        },
        {
          'id': 'newer-a',
          'name': 'chilleast-backup-a-20260926-100000.json',
          'encryptedId': 'enc-a',
          'puid': '1',
        },
      ];
      final latest = CloudBackupManager.pickLatestBackupEntry(crossSlotEntries);
      expect(latest, isNotNull);
      expect(latest!['resid'], 'newer-a');
      expect(latest['slot'], 'a');
    });

    test('returns null when no backup exists', () {
      expect(
        CloudBackupManager.pickLatestBackupEntry([
          {'id': 'x', 'name': 'pubspec.yaml', 'encryptedId': 'e', 'puid': '1'},
        ]),
        isNull,
      );
    });
  });

  group('CloudiskService.parseSession', () {
    const html = '''
      <script>
      rootdir = "1040921812082581504";
      const _token = "930e5385a80fe00fcedd018b0502c004";
      const encstr = "d34171a3f77471befaf2ef6f66cfcb34"
      const currentPuid = "342380530";
      </script>
    ''';

    test('extracts session constants', () {
      final s = CloudiskService.parseSession(html);
      expect(s.puid, '342380530');
      expect(s.rootDirId, '1040921812082581504');
      expect(s.enc, 'd34171a3f77471befaf2ef6f66cfcb34');
      expect(s.token, '930e5385a80fe00fcedd018b0502c004');
    });

    test('throws auth error on login page', () {
      expect(
        () => CloudiskService.parseSession('<html>passport login</html>'),
        throwsA(isA<CloudiskAuthException>()),
      );
    });

    test('ignores p_auth_token and cx_p_token traps', () {
      // 真实首页文末 script 之前散落着 var p_auth_token = ""、
      // cx_p_token = "…"、href="?p_auth_token=" 等干扰串（见 HAR）。
      const trapped = '''
        <script>var p_auth_token = ""; cx_p_token = "11b6581db641bc297b2936a1802063c2";</script>
        <a href="/pcuserpan/squareIndex?customRootId=&p_auth_token=">x</a>
        <script>
        const rootdir = "1040921812082581504";
        const _token = "930e5385a80fe00fcedd018b0502c004";
        const encstr = "d34171a3f77471befaf2ef6f66cfcb34"
        const currentPuid = "342380530";
        </script>
      ''';
      final s = CloudiskService.parseSession(trapped);
      expect(s.token, '930e5385a80fe00fcedd018b0502c004');
      expect(s.puid, '342380530');
    });
  });

  group('CloudBackupManager.pullLatestOnStartup', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('returns null when cloud backup toggle is disabled', () async {
      SharedPreferences.setMockInitialValues({
        CloudBackupManager.toggleKey: false,
      });
      final result =
          await CloudBackupManager.instance.pullLatestOnStartup();
      expect(result, isNull);
    });

    test('returns null when toggle is not set', () async {
      SharedPreferences.setMockInitialValues({});
      final result =
          await CloudBackupManager.instance.pullLatestOnStartup();
      expect(result, isNull);
    });
  });
}
