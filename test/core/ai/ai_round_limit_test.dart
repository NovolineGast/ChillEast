import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/ai/ai_provider.dart';

void main() {
  group('AiAssistantState Round Limit Tests', () {
    test('roundCount calculates user turns correctly', () {
      final state0 = AiAssistantState();
      expect(state0.roundCount, 0);
      expect(state0.isRoundLimitReached, isFalse);

      final state1 = AiAssistantState(
        displayMessages: [
          AiDisplayMessage(role: 'user', text: '你好'),
          AiDisplayMessage(role: 'assistant', text: '你好！有什么可以帮您？'),
          AiDisplayMessage(role: 'user', text: '查询今天课表'),
          AiDisplayMessage(role: 'assistant', text: '今天有两节课...'),
        ],
      );
      expect(state1.roundCount, 2);
      expect(state1.isRoundLimitReached, isFalse);
    });

    test('isRoundLimitReached is true when user turns reach 20', () {
      final messages = <AiDisplayMessage>[];
      for (int i = 1; i <= 20; i++) {
        messages.add(AiDisplayMessage(role: 'user', text: 'Query $i'));
        messages.add(AiDisplayMessage(role: 'assistant', text: 'Response $i'));
      }

      final state20 = AiAssistantState(displayMessages: messages);
      expect(state20.roundCount, 20);
      expect(state20.isRoundLimitReached, isTrue);
    });
  });
}
