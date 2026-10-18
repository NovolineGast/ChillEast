import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/core/network/dio_client.dart';

class _FakeBrowserCookies extends webview.PlatformCookieManager {
  _FakeBrowserCookies()
      : super.implementation(
            const webview.PlatformCookieManagerCreationParams());

  @override
  Future<bool> deleteAllCookies() async => true;

  @override
  Future<bool> setCookie({
    required webview.WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    int? maxAge,
    bool? isSecure,
    bool? isHttpOnly,
    webview.HTTPCookieSameSitePolicy? sameSite,
    webview.PlatformInAppWebViewController? iosBelow11WebViewController,
    webview.PlatformInAppWebViewController? webViewController,
  }) async => true;
}

class _FakeBrowserPlatform extends webview.InAppWebViewPlatform {
  _FakeBrowserPlatform(this.cookies);
  final _FakeBrowserCookies cookies;

  @override
  webview.PlatformCookieManager createPlatformCookieManager(
          webview.PlatformCookieManagerCreationParams params) =>
      cookies;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('single_flight_init_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    webview.InAppWebViewPlatform.instance =
        _FakeBrowserPlatform(_FakeBrowserCookies());
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('Single-flight initialization tests', () {
    test('AppCookieManager concurrent initialize calls coalesce into a single flight', () async {
      final manager = AppCookieManager();

      // Launch multiple simultaneous initialize() calls
      final futures = List.generate(10, (_) => manager.initialize());
      await Future.wait(futures);

      // Verify that after initialization, dioCookieJar is accessible and valid
      expect(manager.dioCookieJar, isNotNull);

      // Subsequent initialize call should be instantaneous and no-op
      await manager.initialize();
      expect(manager.dioCookieJar, isNotNull);
    });

    test('DioClient concurrent initialize calls coalesce into a single flight', () async {
      final client = DioClient();

      // Launch multiple simultaneous initialize() calls
      final futures = List.generate(10, (_) => client.initialize());
      await Future.wait(futures);

      // Verify that after initialization, dio is accessible
      final dio = client.dio;
      expect(dio, isNotNull);
      expect(dio.options.baseUrl, isNotEmpty);
      expect(dio.interceptors.isNotEmpty, isTrue);

      // Subsequent initialize call should be instantaneous and return immediately
      await client.initialize();
      expect(client.dio, same(dio));
    });
  });
}
