import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../auth/screens/login_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static Route route() {
    return MaterialPageRoute(
      builder: (_) => const OnboardingScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C382C),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 背景图自适应剪切在设备上，始终左下角完整对齐屏幕左下角
            Positioned.fill(
              child: Image.asset(
                'assets/images/welcome_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomLeft,
              ),
            ),
            // 右下角内容：东湖事自在事放在登录按钮上方，右对齐
            Positioned(
              right: 28,
              bottom: bottomPadding + 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/donghu_title.svg',
                    width: 132,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  _buildLoginButton(context, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, dynamic l10n) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: const Key('welcome_login_button'),
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            LoginScreen.route(),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.loginTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
