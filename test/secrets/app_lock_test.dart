import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/app_lock.dart';
import 'package:sshetu/core/secrets/device_authenticator.dart';
import 'package:sshetu/core/secrets/locked_secret_vault.dart';
import 'package:sshetu/core/secrets/secret_ref.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/key_material_cache.dart';
import 'package:sshetu/core/ssh/ssh_credentials.dart';

import 'fake_device_authenticator.dart';

/// The credential lock end to end, short of a real sensor: the switch's
/// rules, and the vault the rest of the app is handed because of it.
void main() {
  // The locked vault listens for the app being hidden, which needs a binding.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const password = SecretRef.hostPassword('h1');

  late InMemorySecretVault keychain;
  late FakeDeviceAuthenticator device;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    keychain = InMemorySecretVault();
    await keychain.write(password, 'hunter2');
    device = FakeDeviceAuthenticator();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        keychainSecretVaultProvider.overrideWithValue(keychain),
        deviceAuthenticatorProvider.overrideWithValue(device),
      ],
    );
    addTearDown(container.dispose);
  });

  bool lockOn() => container.read(settingsControllerProvider).requireUnlock;
  AppLockController lock() => container.read(appLockControllerProvider);
  SecretVault vault() => container.read(secretVaultProvider);

  group('turning the lock on', () {
    test('is off on a fresh install', () {
      expect(lockOn(), isFalse);
    });

    test('happens only after a successful unlock', () async {
      final change = await lock().setEnabled(true, reason: 'enable');

      expect(change, AppLockChange.enabled);
      expect(lockOn(), isTrue);
      expect(device.prompts, ['enable']);
    });

    for (final (result, change) in [
      (DeviceAuthResult.cancelled, AppLockChange.cancelled),
      (DeviceAuthResult.failed, AppLockChange.failed),
      (DeviceAuthResult.lockedOut, AppLockChange.lockedOut),
      (DeviceAuthResult.unavailable, AppLockChange.unavailable),
    ]) {
      test('does not happen when the prompt ends ${result.name}', () async {
        device.result = result;

        expect(await lock().setEnabled(true, reason: 'enable'), change);
        expect(lockOn(), isFalse);
      });
    }

    test(
      'is refused without a prompt on a device with nothing to check',
      () async {
        // No screen lock, no biometrics: a lock here could never be opened.
        device.available = false;

        expect(
          await lock().setEnabled(true, reason: 'enable'),
          AppLockChange.unavailable,
        );
        expect(lockOn(), isFalse);
        expect(device.prompts, isEmpty);
      },
    );
  });

  group('turning the lock off', () {
    setUp(() async {
      await lock().setEnabled(true, reason: 'enable');
      device.prompts.clear();
    });

    test('asks first, so a borrowed phone cannot just switch it off', () async {
      device.result = DeviceAuthResult.cancelled;

      expect(
        await lock().setEnabled(false, reason: 'disable'),
        AppLockChange.cancelled,
      );
      expect(lockOn(), isTrue);
      expect(device.prompts, ['disable']);
    });

    test('goes through after a successful unlock', () async {
      expect(
        await lock().setEnabled(false, reason: 'disable'),
        AppLockChange.disabled,
      );
      expect(lockOn(), isFalse);
    });

    test(
      'is allowed without a prompt once the device can no longer ask',
      () async {
        // The screen lock was removed after the credential lock was turned
        // on. Insisting on a check nobody can pass would strand the owner.
        device.available = false;

        expect(
          await lock().setEnabled(false, reason: 'disable'),
          AppLockChange.disabled,
        );
        expect(lockOn(), isFalse);
        expect(device.prompts, isEmpty);
      },
    );

    test('is allowed when the prompt reports nothing to check', () async {
      device.result = DeviceAuthResult.unavailable;

      expect(
        await lock().setEnabled(false, reason: 'disable'),
        AppLockChange.disabled,
      );
      expect(lockOn(), isFalse);
    });
  });

  group('the vault the app is handed', () {
    test('is the keychain itself while the lock is off', () async {
      expect(vault(), same(keychain));
      expect(await vault().read(password), 'hunter2');
      expect(device.prompts, isEmpty);
    });

    test('asks before reading once the lock is on', () async {
      await lock().setEnabled(true, reason: 'enable');
      device.prompts.clear();

      expect(vault(), isA<LockedSecretVault>());
      expect(await vault().read(password), 'hunter2');
      expect(device.prompts, hasLength(1));
      expect(
        device.prompts.single,
        isNot('enable'),
        reason: 'a connection prompt carries its own, localised reason',
      );
    });

    test('hands over nothing when the unlock fails', () async {
      await lock().setEnabled(true, reason: 'enable');
      device.result = DeviceAuthResult.cancelled;

      await expectLater(
        vault().read(password),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('does not ask just to say whether a secret exists', () async {
      await lock().setEnabled(true, reason: 'enable');
      device.prompts.clear();

      expect(await vault().contains(password), isTrue);
      expect(device.prompts, isEmpty);
    });

    test(
      'goes back to the bare keychain when the lock is turned off',
      () async {
        await lock().setEnabled(true, reason: 'enable');
        expect(vault(), isA<LockedSecretVault>());

        await lock().setEnabled(false, reason: 'disable');
        device.prompts.clear();

        expect(vault(), same(keychain));
        expect(await vault().read(password), 'hunter2');
        expect(device.prompts, isEmpty);
      },
    );

    test('tells anything listening when it is swapped', () async {
      // The repositories watch this provider; a toggle that did not notify
      // would leave them holding the unlocked keychain.
      final seen = <SecretVault>[];
      container.listen(secretVaultProvider, (_, next) => seen.add(next));

      await lock().setEnabled(true, reason: 'enable');
      vault();

      expect(seen.single, isA<LockedSecretVault>());
    });

    test('drops keys decoded before the lock went on', () async {
      final cache = container.read(keyMaterialCacheProvider);
      cache['k1'] = const SshPrivateKey(
        identityId: 'k1',
        label: 'k1',
        pem: 'PEM',
      );

      await lock().setEnabled(true, reason: 'enable');
      vault();

      expect(cache.length, 0);
    });

    test(
      'locks again, and forgets decoded keys, when the app is hidden',
      () async {
        await lock().setEnabled(true, reason: 'enable');
        final locked = vault() as LockedSecretVault;
        await locked.read(password);
        expect(locked.isUnlocked, isTrue);

        final cache = container.read(keyMaterialCacheProvider);
        cache['k1'] = const SshPrivateKey(
          identityId: 'k1',
          label: 'k1',
          pem: 'PEM',
        );

        // One step at a time, as the engine reports them.
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        addTearDown(() {
          binding
            ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
            ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        });

        // Inactive is not hidden: the system's own Face ID sheet makes the
        // app inactive, and locking then would undo the unlock it is doing.
        expect(locked.isUnlocked, isTrue);

        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

        expect(locked.isUnlocked, isFalse);
        expect(cache.length, 0);
      },
    );
  });
}
