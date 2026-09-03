import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/util/responsive.dart';

/// The terminal's key bar is an accessory to the software keyboard: it appears
/// with one and never without. These pin the two conditions that decide it,
/// because getting either wrong is immediately visible — a row of dead buttons
/// on a desktop, or no way to send Ctrl-C on a phone.
void main() {
  // The platform override is set and cleared inside each probe, not in a
  // tearDown: flutter_test asserts that foundation debug variables are back to
  // their defaults by the time the test body returns, which is before any
  // tearDown runs.
  Future<({bool usesSoftwareKeyboard, bool isVisible})> probe(
    WidgetTester tester, {
    required TargetPlatform platform,
    required double keyboardInset,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    late bool usesSoftwareKeyboard;
    late bool isVisible;

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: Builder(
          builder: (context) {
            usesSoftwareKeyboard = context.usesSoftwareKeyboard;
            isVisible = context.isSoftwareKeyboardVisible;
            return const SizedBox();
          },
        ),
      ),
    );

    debugDefaultTargetPlatformOverride = null;
    return (usesSoftwareKeyboard: usesSoftwareKeyboard, isVisible: isVisible);
  }

  group('usesSoftwareKeyboard', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('is true on $platform', (tester) async {
        final result = await probe(
          tester,
          platform: platform,
          keyboardInset: 0,
        );
        expect(result.usesSoftwareKeyboard, isTrue);
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets('is false on $platform', (tester) async {
        final result = await probe(
          tester,
          platform: platform,
          keyboardInset: 0,
        );
        expect(
          result.usesSoftwareKeyboard,
          isFalse,
          reason:
              'a desktop has a real Ctrl, Esc, Tab and arrows; an '
              'on-screen strip duplicating them is wasted space',
        );
      });
    }

    testWidgets('is decided by platform, not window width', (tester) async {
      // A desktop window dragged down to phone width still has a physical
      // keyboard. Keying this on a breakpoint would put the bar back.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      late bool usesSoftwareKeyboard;
      late bool isCompact;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(320, 700)),
          child: Builder(
            builder: (context) {
              usesSoftwareKeyboard = context.usesSoftwareKeyboard;
              isCompact = context.isCompact;
              return const SizedBox();
            },
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      expect(isCompact, isTrue, reason: 'the window really is phone-width');
      expect(usesSoftwareKeyboard, isFalse);
    });
  });

  group('isSoftwareKeyboardVisible', () {
    testWidgets('is false with no bottom view inset', (tester) async {
      final result = await probe(
        tester,
        platform: TargetPlatform.android,
        keyboardInset: 0,
      );
      expect(result.isVisible, isFalse);
    });

    testWidgets('is true while the keyboard occludes the bottom', (
      tester,
    ) async {
      final result = await probe(
        tester,
        platform: TargetPlatform.android,
        keyboardInset: 320,
      );
      expect(result.isVisible, isTrue);
    });

    testWidgets('is true even part-way through the opening animation', (
      tester,
    ) async {
      // The inset grows frame by frame. Treating only a fully open keyboard as
      // visible would make the bar snap in late, after the terminal has
      // already resized around it.
      final result = await probe(
        tester,
        platform: TargetPlatform.android,
        keyboardInset: 12,
      );
      expect(result.isVisible, isTrue);
    });
  });

  group('the combined condition', () {
    testWidgets('a phone with a hardware keyboard gets no bar', (tester) async {
      // An attached Bluetooth keyboard raises no software keyboard, so there
      // is no inset — and the user has real modifier keys anyway.
      final result = await probe(
        tester,
        platform: TargetPlatform.android,
        keyboardInset: 0,
      );

      expect(result.usesSoftwareKeyboard && result.isVisible, isFalse);
    });

    testWidgets('a phone with the keyboard up gets the bar', (tester) async {
      final result = await probe(
        tester,
        platform: TargetPlatform.iOS,
        keyboardInset: 291,
      );

      expect(result.usesSoftwareKeyboard && result.isVisible, isTrue);
    });
  });
}
