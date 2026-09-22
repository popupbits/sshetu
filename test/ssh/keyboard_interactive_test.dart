import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/keyboard_interactive.dart';

/// Keyboard-interactive sign-in: when the saved password may answer for the
/// user, and how a multi-round conversation is driven.
void main() {
  const password = KeyboardInteractivePrompt('Password: ', echo: false);
  const code = KeyboardInteractivePrompt('Verification code: ', echo: true);

  KeyboardInteractiveChallenge challenge(
    List<KeyboardInteractivePrompt> prompts, {
    int round = 0,
    bool allowSavedPassword = true,
  }) => KeyboardInteractiveChallenge(
    prompts: prompts,
    round: round,
    allowSavedPassword: allowSavedPassword,
  );

  group('answering with the saved password', () {
    test(
      'first round, lone hidden password prompt, password saved: answers',
      () {
        expect(answerWithSavedPassword(challenge([password]), 's3cret'), [
          's3cret',
        ]);
      },
    );

    test('matches the prompt case-insensitively', () {
      expect(
        answerWithSavedPassword(
          challenge([
            const KeyboardInteractivePrompt(
              "deploy@example.com's PASSWORD:",
              echo: false,
            ),
          ]),
          'pw',
        ),
        ['pw'],
      );
    });

    test('no saved password: asks', () {
      expect(answerWithSavedPassword(challenge([password]), null), isNull);
      expect(answerWithSavedPassword(challenge([password]), ''), isNull);
    });

    test('a later round: asks, so a wrong password is never looped', () {
      expect(
        answerWithSavedPassword(challenge([password], round: 1), 'pw'),
        isNull,
      );
    });

    test('after the saved password was refused: asks', () {
      expect(
        answerWithSavedPassword(
          challenge([password], allowSavedPassword: false),
          'pw',
        ),
        isNull,
      );
    });

    test('an echoed prompt: asks', () {
      expect(
        answerWithSavedPassword(
          challenge([const KeyboardInteractivePrompt('Password:', echo: true)]),
          'pw',
        ),
        isNull,
      );
    });

    test('more than one prompt: asks', () {
      expect(
        answerWithSavedPassword(challenge([password, code]), 'pw'),
        isNull,
      );
    });

    test('a one-time code, even one called a password: asks', () {
      for (final text in [
        'Verification code:',
        'One-time password (OATH) for deploy:',
        'OTP password:',
        'Enter passcode:',
      ]) {
        expect(
          answerWithSavedPassword(
            challenge([KeyboardInteractivePrompt(text, echo: false)]),
            'pw',
          ),
          isNull,
          reason: text,
        );
      }
    });

    test('a prompt that is not about a password: asks', () {
      expect(
        answerWithSavedPassword(
          challenge([const KeyboardInteractivePrompt('PIN:', echo: false)]),
          'pw',
        ),
        isNull,
      );
    });
  });

  group('a keyboard-interactive session', () {
    test('drives a password round then a code round', () async {
      final seen = <KeyboardInteractiveChallenge>[];
      final session = KeyboardInteractiveSession((c) async {
        seen.add(c);
        return c.round == 0
            ? const KeyboardInteractiveAnswers(['pw'], fromSavedPassword: true)
            : const KeyboardInteractiveAnswers(['123456']);
      });

      expect(
        await session.respond(
          name: '',
          instruction: '',
          prompts: const [password],
        ),
        ['pw'],
      );
      expect(
        await session.respond(
          name: 'Two-factor',
          instruction: 'Open your authenticator.',
          prompts: const [code],
        ),
        ['123456'],
      );

      expect(seen.map((c) => c.round), [0, 1]);
      expect(seen[1].name, 'Two-factor');
      expect(seen[1].instruction, 'Open your authenticator.');
      expect(seen[1].prompts.single.echo, isTrue);
      // The saved password is spent once it is used.
      expect(seen[1].allowSavedPassword, isFalse);
      expect(session.usedSavedPassword, isTrue);
      expect(session.declined, isFalse);
    });

    test('an informational round is answered empty, without asking, and is '
        'not counted', () async {
      final seen = <KeyboardInteractiveChallenge>[];
      final session = KeyboardInteractiveSession((c) async {
        seen.add(c);
        return const KeyboardInteractiveAnswers(['pw']);
      });

      expect(
        await session.respond(
          name: '',
          instruction: 'Welcome',
          prompts: const [],
        ),
        isEmpty,
      );
      await session.respond(
        name: '',
        instruction: '',
        prompts: const [password],
      );

      expect(seen.single.round, 0);
    });

    test('cancel declines at once, without hanging', () async {
      final session = KeyboardInteractiveSession((_) async => null);

      final answers = await session
          .respond(name: '', instruction: '', prompts: const [code])
          .timeout(const Duration(seconds: 1));

      expect(answers, isNull, reason: 'null makes dartssh2 fail auth');
      expect(session.declined, isTrue);
    });

    test('an answer of the wrong length declines rather than reaching the '
        'server', () async {
      final session = KeyboardInteractiveSession(
        (_) async => const KeyboardInteractiveAnswers(['only one']),
      );

      expect(
        await session.respond(
          name: '',
          instruction: '',
          prompts: const [password, code],
        ),
        isNull,
      );
      expect(session.declined, isTrue);
    });

    test('a source that throws declines instead of tearing the transport '
        'down', () async {
      final session = KeyboardInteractiveSession(
        (_) async => throw StateError('dialog gone'),
      );

      expect(
        await session.respond(name: '', instruction: '', prompts: const [code]),
        isNull,
      );
      expect(session.declined, isTrue);
    });

    test('an attempt after a refused saved password never offers it', () async {
      final seen = <KeyboardInteractiveChallenge>[];
      final session = KeyboardInteractiveSession((c) async {
        seen.add(c);
        return const KeyboardInteractiveAnswers(['typed']);
      }, allowSavedPassword: false);

      await session.respond(
        name: '',
        instruction: '',
        prompts: const [password],
      );

      expect(seen.single.allowSavedPassword, isFalse);
      expect(session.usedSavedPassword, isFalse);
    });

    test('waits for the user as long as they take', () async {
      final answer = Completer<KeyboardInteractiveAnswers?>();
      final session = KeyboardInteractiveSession((_) => answer.future);

      final pending = session.respond(
        name: '',
        instruction: '',
        prompts: const [code],
      );
      answer.complete(const KeyboardInteractiveAnswers(['42']));

      expect(await pending, ['42']);
    });
  });
}
