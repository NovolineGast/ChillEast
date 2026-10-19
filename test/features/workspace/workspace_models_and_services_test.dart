import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/core/network/dio_client.dart';
import 'package:ChillEast/features/workspace/models/classroom_model.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/models/transaction_model.dart';
import 'package:ChillEast/features/workspace/services/classroom_service.dart';

class _FakeBrowserPlatform extends webview.InAppWebViewPlatform {
  @override
  webview.PlatformCookieManager createPlatformCookieManager(
          webview.PlatformCookieManagerCreationParams params) =>
      _FakeCookieManager();
}

class _FakeCookieManager extends webview.PlatformCookieManager {
  _FakeCookieManager()
      : super.implementation(const webview.PlatformCookieManagerCreationParams());

  @override
  Future<bool> deleteAllCookies() async => true;
}

class _MockDioAdapter implements HttpClientAdapter {
  int statusCode = 200;
  dynamic responseData = '';
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final String bodyStr = responseData is String ? responseData : jsonEncode(responseData);
    final isHtml = responseData is String && responseData.trimLeft().startsWith('<');
    final contentType = isHtml ? 'text/html; charset=utf-8' : 'application/json; charset=utf-8';
    return ResponseBody.fromString(
      bodyStr,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late _MockDioAdapter adapter;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('workspace-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    webview.InAppWebViewPlatform.instance = _FakeBrowserPlatform();
    await AppCookieManager().initialize();
    await DioClient().initialize();
  });

  setUp(() {
    adapter = _MockDioAdapter();
    DioClient().dio.httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  group('TransactionRecord and TransactionType Tests', () {
    test('TransactionRecord fromJson handles key fallbacks', () {
      final json1 = {
        'mername': '教工食堂',
        'txamt': '15.50',
        'txdate': '2026-10-18 12:30:00',
        'tradeType': '1',
      };
      final t1 = TransactionRecord.fromJson(json1);
      expect(t1.merchantName, '教工食堂');
      expect(t1.amount, '15.50');
      expect(t1.time, '2026-10-18 12:30:00');
      expect(t1.tradeType, '1');

      // Alternative keys (mercname, paytime, tradetype, etc.)
      final json2 = {
        'mercname': '红旗超市',
        'txamt': '20.00',
        'paytime': '2026-10-18 13:00:00',
        'type': '2',
      };
      final t2 = TransactionRecord.fromJson(json2);
      expect(t2.merchantName, '红旗超市');
      expect(t2.time, '2026-10-18 13:00:00');
      expect(t2.tradeType, '2');

      final json3 = {'txtype': '3'};
      expect(TransactionRecord.fromJson(json3).tradeType, '3');
    });

    test('TransactionType enum values and labels', () {
      expect(TransactionType.all.value, '-1');
      expect(TransactionType.all.label, '全部');

      expect(TransactionType.consume.value, '1');
      expect(TransactionType.consume.label, '消费');

      expect(TransactionType.recharge.value, '2');
      expect(TransactionType.recharge.label, '充值');

      expect(TransactionType.subsidy.value, '3');
      expect(TransactionType.subsidy.label, '补助');

      expect(TransactionType.transfer.value, '4');
      expect(TransactionType.transfer.label, '转账');
    });
  });

  group('ClassroomModel and Options Tests', () {
    test('ClassroomModel fromJson', () {
      final model = ClassroomModel.fromJson({'JSMC': '十教南201', 'ZWS': '120'});
      expect(model.jsmc, '十教南201');
      expect(model.zws, '120');

      final empty = ClassroomModel.fromJson({});
      expect(empty.jsmc, '');
      expect(empty.zws, '0');
    });

    test('ClassroomInquiryOptions instantiates properly', () {
      final options = ClassroomInquiryOptions(
        buildings: ['十教', '十一教'],
        sections: ['1-2节', '3-4节'],
        weeks: ['第1周', '第2周'],
        days: [{'label': '周一', 'value': '1'}],
      );
      expect(options.buildings.length, 2);
      expect(options.sections.first, '1-2节');
      expect(options.weeks.first, '第1周');
      expect(options.days.first['label'], '周一');
    });
  });

  group('ClassroomService Tests', () {
    test('fetchOptions parses HTML options properly', () async {
      adapter.statusCode = 200;
      adapter.responseData = '''
      <html>
      <body>
        <div id="jxlCondition">
          <a>第十教学楼</a>
          <a>第十一教学楼</a>
        </div>
        <div id="jcCondition">
          <a>1-2节</a>
          <a>3-4节</a>
        </div>
        <div id="zcCondition">
          <a>第1周</a>
          <a>第2周</a>
        </div>
        <div id="weekCondition">
          <a data-value="1">星期一</a>
          <a data-value="2">星期二</a>
        </div>
      </body>
      </html>
      ''';

      final service = ClassroomService();
      final options = await service.fetchOptions();

      expect(options.buildings, ['第十教学楼', '第十一教学楼']);
      expect(options.sections, ['1-2节', '3-4节']);
      expect(options.weeks, ['第1周', '第2周']);
      expect(options.days.length, 2);
      expect(options.days.first['label'], '星期一');
      expect(options.days.first['value'], '1');
    });

    test('fetchOptions rethrows on failure', () async {
      adapter.statusCode = 500;
      adapter.responseData = 'Error';

      final service = ClassroomService();
      expect(() => service.fetchOptions(), throwsA(isA<Exception>()));
    });

    test('queryClassrooms passes correct query parameters and parses results', () async {
      adapter.statusCode = 200;
      adapter.responseData = {
        'data': [
          {'JSMC': '十教南101', 'ZWS': '80'},
          {'JSMC': '十教南102', 'ZWS': '100'},
        ]
      };

      final service = ClassroomService();
      final list = await service.queryClassrooms(
        building: '第十教学楼',
        week: '2',
        jc: '1-2节',
        day: '1',
      );

      expect(list.length, 2);
      expect(list[0].jsmc, '十教南101');
      expect(list[0].zws, '80');
      expect(list[1].jsmc, '十教南102');

      expect(adapter.lastOptions?.queryParameters['jxl'], '第十教学楼');
      expect(adapter.lastOptions?.queryParameters['week'], '1');
      expect(adapter.lastOptions?.queryParameters['jc'], '1-2节');
      expect(adapter.lastOptions?.queryParameters['zc'], '2');
    });

    test('queryClassrooms rethrows on failure', () async {
      adapter.statusCode = 500;
      adapter.responseData = 'Server error';

      final service = ClassroomService();
      expect(
        () => service.queryClassrooms(
          building: '十教',
          week: '1',
          jc: '1',
          day: '1',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ElectricityModel Tests', () {
    test('ElectricityArea fromJson handles xiaoqu / schoolname fallback', () {
      final a1 = ElectricityArea.fromJson({'xiaoqu': '东湖校区'});
      expect(a1.id, '东湖校区');
      expect(a1.name, '东湖校区');

      final a2 = ElectricityArea.fromJson({'schoolname': '修业校区'});
      expect(a2.id, '修业校区');

      final a3 = ElectricityArea.fromJson({'schoolid': '10542'});
      expect(a3.id, '10542');
    });

    test('ElectricityBuilding fromJson handles buildingname and buildingid', () {
      final b1 = ElectricityBuilding.fromJson({'buildingname': '丰泽1栋', 'buildingid': 'F1'});
      expect(b1.id, 'F1');
      expect(b1.name, '丰泽1栋');

      final b2 = ElectricityBuilding.fromJson({'buildname': '芷兰2栋', 'buildid': 'Z2'});
      expect(b2.id, 'Z2');
      expect(b2.name, '芷兰2栋');

      final b3 = ElectricityBuilding.fromJson({'buildingname': '金岸3栋'});
      expect(b3.id, '金岸3栋');
      expect(b3.name, '金岸3栋');
    });

    test('ElectricityRoom fromJson handles roomname, roomid, and mertype', () {
      final r1 = ElectricityRoom.fromJson({'roomname': '629', 'roomid': 'R629', 'mertype': 'rt'});
      expect(r1.id, 'R629');
      expect(r1.name, '629');
      expect(r1.mertype, 'rt');

      final r2 = ElectricityRoom.fromJson({});
      expect(r2.id, '');
      expect(r2.name, '');
      expect(r2.mertype, 'yk');
    });

    test('ElectricityBalanceInfo fromJson and toJson handle balance keys and status', () {
      final json1 = {
        'eledetail': '45.60',
        'eleaccdetail': '金岸公寓空调-金岸1栋-629',
        'accname': '629室',
        'elestatus': 1,
      };
      final info1 = ElectricityBalanceInfo.fromJson(json1);
      expect(info1.balance, '45.60');
      expect(info1.detail, '金岸公寓空调-金岸1栋-629');
      expect(info1.accname, '629室');
      expect(info1.elestatus, 1);

      final out = info1.toJson();
      expect(out['balance'], '45.60');
      expect(out['elestatus'], 1);

      // String status and alternative balance keys
      final json2 = {
        'balance': '12.34',
        'elestatus': '0',
      };
      final info2 = ElectricityBalanceInfo.fromJson(json2);
      expect(info2.balance, '12.34');
      expect(info2.elestatus, 0);

      final json3 = {'syje': '88.88'};
      expect(ElectricityBalanceInfo.fromJson(json3).balance, '88.88');
    });

    test('SavedElectricityRoom equality, hashCode, fromJson and toJson', () {
      const roomA = SavedElectricityRoom(
        areaName: '东湖校区',
        buildingName: '金岸1栋',
        roomId: '101',
        roomName: '101室',
        mertype: 'yk',
      );
      const roomB = SavedElectricityRoom(
        areaName: '东湖校区',
        buildingName: '金岸1栋',
        roomId: '101',
        roomName: '101室',
        mertype: 'yk',
      );
      const roomC = SavedElectricityRoom(
        areaName: '东湖校区',
        buildingName: '金岸2栋',
        roomId: '102',
        roomName: '102室',
        mertype: 'rt',
      );

      expect(roomA, equals(roomB));
      expect(roomA.hashCode, equals(roomB.hashCode));
      expect(roomA == roomC, isFalse);

      final json = roomA.toJson();
      final revived = SavedElectricityRoom.fromJson(json);
      expect(revived, equals(roomA));
    });
  });
}
