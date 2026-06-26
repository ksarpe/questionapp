import 'package:flutter_test/flutter_test.dart';

import 'package:questionapp/features/account/providers/session_providers.dart';

/// Premium is tied to the *identity* (the Supabase UUID every user gets at
/// launch via anonymous sign-in), NOT to having a real account. These tests pin
/// down that decoupling so the "a guest can hold PRO" / "restore doesn't log you
/// in" guarantees don't silently regress.
void main() {
  // A signed-in-but-anonymous guest: has a stable UUID, no email, isAnonymous.
  SessionState guest({bool isPremium = false}) => SessionState(
    userId: 'anon-uuid',
    isAnonymous: true,
    isPremium: isPremium,
  );

  // A real account: anonymous identity upgraded to email/password or Google.
  SessionState account({bool isPremium = false}) => SessionState(
    userId: 'anon-uuid',
    email: 'user@example.com',
    isAnonymous: false,
    isPremium: isPremium,
  );

  group('identity vs account', () {
    test('a guest is signed in but has no account', () {
      final s = guest();
      expect(s.isSignedIn, isTrue, reason: 'every user gets a UUID at launch');
      expect(s.hasAccount, isFalse, reason: 'anonymous == no real account');
    });

    test('an upgraded user has an account', () {
      expect(account().hasAccount, isTrue);
    });

    test(
      'a still-loading session (null userId) is neither signed in nor an account',
      () {
        const s = SessionState();
        expect(s.isSignedIn, isFalse);
        expect(s.hasAccount, isFalse);
      },
    );
  });

  group('premium is independent of having an account', () {
    test('a guest can hold PRO', () {
      final s = guest(isPremium: true);
      expect(s.isPremium, isTrue);
      expect(
        s.hasAccount,
        isFalse,
        reason: 'PRO must not require a real account',
      );
    });

    test('an account without PRO is possible', () {
      expect(account(isPremium: false).isPremium, isFalse);
    });
  });

  group('restore does not change the identity', () {
    test('restoring PRO leaves a guest a guest (no login happens)', () {
      final before = guest();
      // restorePurchases() only re-reads the entitlement; the session is then
      // refreshed. Model that as flipping isPremium and nothing else.
      final after = before.copyWith(isPremium: true);

      expect(after.isPremium, isTrue, reason: 'entitlement restored');
      expect(after.isAnonymous, isTrue, reason: 'still anonymous');
      expect(after.hasAccount, isFalse, reason: 'restore is not a login');
      expect(after.userId, before.userId, reason: 'same identity');
    });
  });
}
