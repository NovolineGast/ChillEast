import 'package:flutter/material.dart';

/// 在平板/宽屏分栏模式下用于右半屏嵌入展示二级功能页面的容器组件
///
/// 通过内部嵌套的 Navigator 提供二级页面的独立路由环境，并配置占位根路由，
/// 使嵌入页面自动展示其自身 AppBar 默认的返回键，或页面原生的返回/关闭组件，
/// 用户点击功能自带的返回/关闭按钮时即可退出分栏并恢复原页面全宽。
class EmbeddedDetailPane extends StatefulWidget {
  final Widget child;
  final VoidCallback onClose;

  const EmbeddedDetailPane({
    super.key,
    required this.child,
    required this.onClose,
  });

  @override
  State<EmbeddedDetailPane> createState() => _EmbeddedDetailPaneState();
}

class _EmbeddedDetailPaneState extends State<EmbeddedDetailPane>
    with SingleTickerProviderStateMixin {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final _EmbeddedPaneNavigatorObserver _navigatorObserver;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    const begin = Offset(0.08, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    _slideAnimation = _animController.drive(tween);
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _navigatorObserver = _EmbeddedPaneNavigatorObserver(
      onPoppedToPlaceholder: _handleDirectPop,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerClose() {
    if (_isExiting) return;
    _isExiting = true;
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  void _handleDirectPop() {
    if (_isExiting) return;
    _isExiting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ClipRect(
          child: Navigator(
            key: _navigatorKey,
            observers: [_navigatorObserver],
            onGenerateInitialRoutes: (navigator, initialRoute) {
              return [
                // 占位根路由，使嵌入的内容页面处于非 isFirst 状态，
                // 从而自动触发其 AppBar 自带的标准返回键，或页面原生的返回/关闭组件
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const SizedBox.shrink(),
                  settings: const RouteSettings(name: '/__embedded_placeholder__'),
                ),
                PageRouteBuilder(
                  settings: const RouteSettings(name: '/__embedded_detail__'),
                  pageBuilder: (nestedContext, animation, secondaryAnimation) => PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) {
                      if (didPop) {
                        _handleDirectPop();
                        return;
                      }
                      _triggerClose();
                    },
                    child: widget.child,
                  ),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }
}

class _EmbeddedPaneNavigatorObserver extends NavigatorObserver {
  final VoidCallback onPoppedToPlaceholder;

  _EmbeddedPaneNavigatorObserver({required this.onPoppedToPlaceholder});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute?.settings.name == '/__embedded_placeholder__') {
      onPoppedToPlaceholder();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute?.settings.name == '/__embedded_placeholder__') {
      onPoppedToPlaceholder();
    }
  }
}


