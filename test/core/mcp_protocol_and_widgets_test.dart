import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/mcp/models/mcp_protocol.dart';
import 'package:ChillEast/core/widgets/login_required_placeholder.dart';
import 'package:ChillEast/core/widgets/triangle_painter.dart';
import 'package:ChillEast/features/campus_bus/models/campus_bus_data.dart';
import 'package:ChillEast/features/repairs/services/repair_cache_storage.dart';
import 'package:ChillEast/features/score/models/score_model.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

Widget _buildLocalizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('McpProtocol Tests', () {
    test('McpRequest fromJson and toJson', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 'req-1',
        'method': 'tools/call',
        'params': {'name': 'query_score', 'arguments': {}},
      };

      final req = McpRequest.fromJson(json);
      expect(req.jsonrpc, '2.0');
      expect(req.id, 'req-1');
      expect(req.method, 'tools/call');
      expect(req.params?['name'], 'query_score');

      final out = req.toJson();
      expect(out['id'], 'req-1');
      expect(out['method'], 'tools/call');

      // Request without params
      final noParams = McpRequest(id: 2, method: 'tools/list');
      expect(noParams.toJson()['params'], isNull);
    });

    test('McpResponse success and error factories and JSON serialization', () {
      final success = McpResponse.success(id: 1, result: {'status': 'ok'});
      expect(success.id, 1);
      expect(success.result['status'], 'ok');
      expect(success.error, isNull);
      expect(success.toJsonString(), contains('"result":{"status":"ok"}'));

      final err = McpResponse.error(
        id: 2,
        code: McpError.invalidParams,
        message: '参数错误',
        data: {'param': 'semester'},
      );
      expect(err.id, 2);
      expect(err.error?.code, McpError.invalidParams);
      expect(err.error?.message, '参数错误');
      expect(err.error?.data['param'], 'semester');

      final errJson = err.toJson();
      expect(errJson['error']['code'], -32602);
      expect(err.toJsonString(), contains('"message":"参数错误"'));
    });

    test('McpError codes constants', () {
      expect(McpError.parseError, -32700);
      expect(McpError.invalidRequest, -32600);
      expect(McpError.methodNotFound, -32601);
      expect(McpError.invalidParams, -32602);
      expect(McpError.internalError, -32603);
    });
  });

  group('AppConstants Tests', () {
    test('verify dynamic URLs and getters', () {
      expect(AppConstants.fusionWorkspaceUrl, AppConstants.portalWorkspaceUrl);
      expect(AppConstants.noticeDetailUrl('abc'), contains('/fusion/notice/detail/abc'));
      expect(AppConstants.fusionAvatarUrl('12345'), 'https://photo.chaoxing.com/p/12345_480');
      expect(AppConstants.chaoxingNoticeDetailUrl('uuid-99'), contains('/pc/notice/uuid-99/detail'));
    });
  });

  group('ScoreModel and SemesterModel Tests', () {
    test('ScoreModel toString', () {
      final score = ScoreModel(
        courseName: '操作系统',
        score: '95',
        credit: '3.0',
        examType: '考试',
      );
      expect(score.toString(), contains('操作系统'));
      expect(score.toString(), contains('95'));
    });

    test('SemesterModel value, xq, equality and hashCode', () {
      final s1 = SemesterModel(id: '2025-2026-2', name: '2025-2026学年第二学期', isActive: true);
      final s2 = SemesterModel(id: '2025-2026-2', name: '2025-2026-2');
      final s3 = SemesterModel(id: '2025-2026-1', name: '2025-2026-1');

      expect(s1.value, '2025-2026-2');
      expect(s1.xq, '2');
      expect(s1, equals(s2));
      expect(s1 == s3, isFalse);
      expect(s1.hashCode, s2.hashCode);
      expect(s1.toString(), contains('2025-2026-2'));
    });
  });

  group('CampusBusRepository station and line query tests', () {
    test('getStationById returns station or null', () {
      final stn = CampusBusRepository.getStationById('north_gate');
      expect(stn, isNotNull);
      expect(stn?.name, '北门');

      final unknown = CampusBusRepository.getStationById('non_existing');
      expect(unknown, isNull);
    });

    test('getLineById returns line or null', () {
      final line = CampusBusRepository.getLineById('red_loop');
      expect(line, isNotNull);
      expect(line?.name, '红色环线');

      final unknown = CampusBusRepository.getLineById('non_existing');
      expect(unknown, isNull);
    });

    test('getStationsForLine returns valid stations list or empty', () {
      final stations = CampusBusRepository.getStationsForLine('red_loop');
      expect(stations, isNotEmpty);
      expect(stations.first.id, 'fengze');

      final empty = CampusBusRepository.getStationsForLine('invalid_line');
      expect(empty, isEmpty);
    });
  });

  group('RepairCacheStorage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveRaws, getCachedRaws and clearItems', () async {
      expect(await RepairCacheStorage.getCachedRaws(), isEmpty);

      final testOrders = [
        {'id': 'order-1', 'title': '修理水龙头'},
        {'id': 'order-2', 'title': '修灯泡'},
      ];

      await RepairCacheStorage.saveRaws(testOrders);
      final retrieved = await RepairCacheStorage.getCachedRaws();
      expect(retrieved.length, 2);
      expect(retrieved[0]['id'], 'order-1');

      await RepairCacheStorage.clearItems();
      expect(await RepairCacheStorage.getCachedRaws(), isEmpty);
    });

    test('getCachedRaws handles corrupted JSON safely', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_ongoing_repair_items', 'not json');
      expect(await RepairCacheStorage.getCachedRaws(), isEmpty);
    });
  });

  group('UI Widgets Tests: TrianglePainter and LoginRequiredPlaceholder', () {
    test('TrianglePainter paints and does not repaint', () {
      final painter = TrianglePainter(color: Colors.blue);
      expect(painter.shouldRepaint(TrianglePainter(color: Colors.blue)), isFalse);
    });

    testWidgets('TrianglePainter renders inside CustomPaint without error', (tester) async {
      await tester.pumpWidget(
        CustomPaint(
          size: const Size(20, 20),
          painter: TrianglePainter(color: Colors.red),
        ),
      );
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('LoginRequiredPlaceholder renders with default and custom strings', (tester) async {
      await tester.pumpWidget(_buildLocalizedApp(
        const LoginRequiredPlaceholder(),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Custom title and message
      await tester.pumpWidget(_buildLocalizedApp(
        const LoginRequiredPlaceholder(
          title: '请先登录账号',
          message: '需要登录后才能查看当前内容',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('请先登录账号'), findsOneWidget);
      expect(find.text('需要登录后才能查看当前内容'), findsOneWidget);
    });
  });
}
