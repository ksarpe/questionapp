import 'package:debatly/features/account/providers/session_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // The auth listener converges the session on out-of-band identity changes.
  // Widening this set silently would turn a token refresh into a reload storm
  // (and trip the QuestionScreen identity listener); narrowing it would leave a
  // zombie UI after a silent sign-out. Pin exactly which events act.
  group('isIdentityChangingAuthEvent', () {
    test('a silent sign-out reloads (mint a fresh guest)', () {
      expect(isIdentityChangingAuthEvent(AuthChangeEvent.signedOut), isTrue);
    });

    test('an anonymous→email upgrade reloads', () {
      expect(isIdentityChangingAuthEvent(AuthChangeEvent.userUpdated), isTrue);
    });

    test('the initial session / sign-in / token refresh do NOT reload', () {
      expect(
        isIdentityChangingAuthEvent(AuthChangeEvent.initialSession),
        isFalse,
      );
      expect(isIdentityChangingAuthEvent(AuthChangeEvent.signedIn), isFalse);
      expect(
        isIdentityChangingAuthEvent(AuthChangeEvent.tokenRefreshed),
        isFalse,
      );
    });
  });

  // The effective-premium precedence is the gate the whole app reads. The order
  // matters (a promo grant with no purchase must still unlock) AND the
  // short-circuit matters (a resolved sync must not fire the other two
  // network/SDK calls).
  group('resolveEffectivePremium', () {
    test('the reconciled store↔DB sync wins when it resolves', () async {
      var profileCalls = 0;
      var storeCalls = 0;
      final result = await resolveEffectivePremium(
        sync: () async => true,
        profile: () async {
          profileCalls++;
          return false;
        },
        store: () async {
          storeCalls++;
          return false;
        },
      );
      expect(result, isTrue);
      expect(profileCalls, 0, reason: 'sync resolved — must not hit profile');
      expect(storeCalls, 0, reason: 'sync resolved — must not hit store');
    });

    test(
      'falls through to the profile flag when sync is null (promo grant)',
      () async {
        var storeCalls = 0;
        final result = await resolveEffectivePremium(
          sync: () async => null,
          profile: () async => true,
          store: () async {
            storeCalls++;
            return false;
          },
        );
        expect(
          result,
          isTrue,
          reason: 'a promo/admin grant unlocks with no buy',
        );
        expect(storeCalls, 0, reason: 'profile resolved — must not hit store');
      },
    );

    test('falls through to the store cache only when both are null', () async {
      final result = await resolveEffectivePremium(
        sync: () async => null,
        profile: () async => null,
        store: () async => true,
      );
      expect(result, isTrue);
    });

    test('is free when every source declines', () async {
      final result = await resolveEffectivePremium(
        sync: () async => null,
        profile: () async => null,
        store: () async => false,
      );
      expect(result, isFalse);
    });

    test('a false from sync is authoritative — does NOT fall through', () async {
      // A resolved `false` is a real answer (lapsed), not "unknown"; only null
      // means "couldn't reconcile, try the next source".
      var profileCalls = 0;
      final result = await resolveEffectivePremium(
        sync: () async => false,
        profile: () async {
          profileCalls++;
          return true;
        },
        store: () async => true,
      );
      expect(result, isFalse);
      expect(profileCalls, 0);
    });
  });
}
