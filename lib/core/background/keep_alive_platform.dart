import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter/services.dart';

/// What the keep-alive notification says. Every string is already localized.
@immutable
class KeepAliveNotice {
  const KeepAliveNotice({
    required this.title,
    required this.text,
    required this.disconnectAllLabel,
    required this.channelName,
  });

  final String title;

  /// "2 sessions, 1 tunnel active".
  final String text;
  final String disconnectAllLabel;

  /// The name Android shows for the notification channel in system settings.
  final String channelName;

  Map<String, String> toMap() => {
    'title': title,
    'text': text,
    'disconnectAllLabel': disconnectAllLabel,
    'channelName': channelName,
  };

  @override
  bool operator ==(Object other) =>
      other is KeepAliveNotice &&
      other.title == title &&
      other.text == text &&
      other.disconnectAllLabel == disconnectAllLabel &&
      other.channelName == channelName;

  @override
  int get hashCode => Object.hash(title, text, disconnectAllLabel, channelName);
}

/// The native half of keeping connections alive: an Android foreground
/// service, `KeepAliveService.kt`.
///
/// The service does no networking. The sockets stay in this isolate; the
/// service exists so Android keeps the process running, and in the
/// foreground, while the app is not on screen.
abstract interface class KeepAlivePlatform {
  Future<void> start(KeepAliveNotice notice);

  Future<void> update(KeepAliveNotice notice);

  Future<void> stop();

  /// Asks for POST_NOTIFICATIONS on Android 13 and later. Returns without
  /// waiting for the user's answer, which changes nothing here: see
  /// `KeepAliveController`.
  Future<void> requestNotificationPermission();

  /// Called when the notification's "Disconnect all" action is tapped.
  set onDisconnectAll(Future<void> Function()? handler);
}

/// Whether this platform has a keep-alive service at all.
///
/// A capability check, not a layout one: only Android kills a backgrounded
/// app's sockets *and* lets an app prevent it. iOS suspends the app and offers
/// nothing that keeps a socket open for long; desktops never suspend.
bool get keepAliveSupported => !kIsWeb && Platform.isAndroid;

class MethodChannelKeepAlivePlatform implements KeepAlivePlatform {
  MethodChannelKeepAlivePlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// Shared with `MainActivity.kt`.
  static const channelName = 'com.popupbits.sshetu/keep_alive';

  final MethodChannel _channel;

  @override
  Future<void> start(KeepAliveNotice notice) =>
      _channel.invokeMethod<void>('start', notice.toMap());

  @override
  Future<void> update(KeepAliveNotice notice) =>
      _channel.invokeMethod<void>('update', notice.toMap());

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> requestNotificationPermission() =>
      _channel.invokeMethod<void>('requestNotificationPermission');

  @override
  set onDisconnectAll(Future<void> Function()? handler) {
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'disconnectAll') await handler();
            },
    );
  }
}
