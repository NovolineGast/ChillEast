import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final hasSeenOnboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier extends StateNotifier<bool> {
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';

  OnboardingNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(hasSeenOnboardingKey) ?? false;
    } catch (_) {
      state = false;
    }
  }

  Future<void> completeOnboarding() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(hasSeenOnboardingKey, true);
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    state = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(hasSeenOnboardingKey);
    } catch (_) {}
  }
}
