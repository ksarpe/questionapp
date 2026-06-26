import 'dart:async';
import 'dart:io';

import 'package:debatly/core/network/network_error.dart';
import 'package:flutter_test/flutter_test.dart';

/// `isOfflineError` must classify transport failures as offline (so the caller
/// falls back to cache) while letting genuine server errors through untouched
/// (so a real 4xx/5xx is never silently masked by stale data).
void main() {
  group('isOfflineError', () {
    test('flags transport-level exceptions as offline', () {
      expect(isOfflineError(const SocketException('no route')), isTrue);
      expect(isOfflineError(TimeoutException('slow')), isTrue);
      expect(isOfflineError(const HttpException('closed')), isTrue);
    });

    test('flags common transport error messages as offline', () {
      for (final message in const [
        'ClientException: Connection closed before full header was received',
        'SocketException: Failed host lookup: "xyz.supabase.co"',
        'Connection refused',
        'Connection reset by peer',
        'Network is unreachable',
        'AuthRetryableFetchException: retryable',
        'Operation timed out',
      ]) {
        expect(
          isOfflineError(_StringError(message)),
          isTrue,
          reason: 'should treat "$message" as offline',
        );
      }
    });

    test('does NOT flag a genuine server rejection as offline', () {
      // A Postgrest-style error that reached the server (has a code/status) and
      // a plain logic error must rethrow, not be masked by cache.
      expect(
        isOfflineError(
          _StringError(
            'PostgrestException: permission denied, '
            'code: 42501',
          ),
        ),
        isFalse,
      );
      expect(isOfflineError(StateError('bad state')), isFalse);
      expect(isOfflineError(_StringError('not found')), isFalse);
    });
  });
}

/// An error whose `toString()` is a controlled message, to exercise the
/// message-matching branch of [isOfflineError].
class _StringError {
  _StringError(this.message);
  final String message;
  @override
  String toString() => message;
}
