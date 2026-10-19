import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/state/auth_state.dart';

void main() {
  group('AuthState unit tests', () {
    test('Constructors initialize fields correctly', () {
      const initial = AuthState.initial();
      expect(initial.status, equals(AuthStatus.unauthenticated));
      expect(initial.isGuestMode, isFalse);
      expect(initial.isInitialized, isTrue);
      expect(initial.errorMessage, isNull);
      expect(initial.username, isNull);
      expect(initial.realName, isNull);
      expect(initial.uid, isNull);
      expect(initial.avatarUrl, isNull);
      expect(initial.hasAccount, isFalse);

      const authenticating = AuthState.authenticating();
      expect(authenticating.status, equals(AuthStatus.authenticating));
      expect(authenticating.isInitialized, isFalse);

      const authenticated = AuthState.authenticated(
        username: '202440800001',
        realName: '测试用户',
        uid: 'uid_123',
        avatarUrl: 'https://example.com/avatar.png',
      );
      expect(authenticated.status, equals(AuthStatus.authenticated));
      expect(authenticated.username, equals('202440800001'));
      expect(authenticated.realName, equals('测试用户'));
      expect(authenticated.uid, equals('uid_123'));
      expect(authenticated.avatarUrl, equals('https://example.com/avatar.png'));
      expect(authenticated.hasAccount, isTrue);

      const errorState = AuthState.error('密码错误');
      expect(errorState.status, equals(AuthStatus.unauthenticated));
      expect(errorState.errorMessage, equals('密码错误'));
    });

    test('copyWith sentinel behavior for errorMessage', () {
      const stateWithError = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: '网络连接超时',
        username: '202440800001',
      );

      // 1. Calling copyWith without errorMessage preserves the existing errorMessage
      final copyWithoutTouchingError = stateWithError.copyWith(
        status: AuthStatus.authenticating,
      );
      expect(copyWithoutTouchingError.errorMessage, equals('网络连接超时'));
      expect(copyWithoutTouchingError.status, equals(AuthStatus.authenticating));

      // 2. Calling copyWith with errorMessage: null explicitly CLEARS the errorMessage
      final copyClearingError = stateWithError.copyWith(
        errorMessage: null,
      );
      expect(copyClearingError.errorMessage, isNull);
      expect(copyClearingError.username, equals('202440800001'));

      // 3. Calling copyWith with a new errorMessage replaces it
      final copyReplacingError = stateWithError.copyWith(
        errorMessage: '新错误信息',
      );
      expect(copyReplacingError.errorMessage, equals('新错误信息'));
    });

    test('copyWith updates all individual fields correctly', () {
      const base = AuthState.initial();

      final updated = base.copyWith(
        status: AuthStatus.authenticated,
        username: 'user1',
        realName: '张三',
        uid: 'u1',
        avatarUrl: 'https://avatar.url',
        isGuestMode: true,
        isInitialized: true,
      );

      expect(updated.status, equals(AuthStatus.authenticated));
      expect(updated.username, equals('user1'));
      expect(updated.realName, equals('张三'));
      expect(updated.uid, equals('u1'));
      expect(updated.avatarUrl, equals('https://avatar.url'));
      expect(updated.isGuestMode, isTrue);
      expect(updated.isInitialized, isTrue);
    });

    test('Equality (operator ==) and hashCode comparisons', () {
      const state1 = AuthState(
        status: AuthStatus.authenticated,
        errorMessage: null,
        username: 'user123',
        realName: '李四',
        uid: 'uid_999',
        avatarUrl: 'https://test.com/a.png',
        isGuestMode: false,
        isInitialized: true,
      );

      const state2 = AuthState(
        status: AuthStatus.authenticated,
        errorMessage: null,
        username: 'user123',
        realName: '李四',
        uid: 'uid_999',
        avatarUrl: 'https://test.com/a.png',
        isGuestMode: false,
        isInitialized: true,
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      // Any differing field produces inequality
      expect(state1 == state2.copyWith(status: AuthStatus.unauthenticated), isFalse);
      expect(state1 == state2.copyWith(errorMessage: 'some error'), isFalse);
      expect(state1 == state2.copyWith(username: 'other_user'), isFalse);
      expect(state1 == state2.copyWith(realName: '王五'), isFalse);
      expect(state1 == state2.copyWith(uid: 'uid_888'), isFalse);
      expect(state1 == state2.copyWith(avatarUrl: 'other_url'), isFalse);
      expect(state1 == state2.copyWith(isGuestMode: true), isFalse);
      expect(state1 == state2.copyWith(isInitialized: false), isFalse);
    });

    test('hasAccount logic', () {
      expect(const AuthState.initial().hasAccount, isFalse);
      expect(const AuthState(status: AuthStatus.unauthenticated, username: '').hasAccount, isFalse);
      expect(const AuthState(status: AuthStatus.unauthenticated, username: 'test').hasAccount, isTrue);
    });
  });
}
