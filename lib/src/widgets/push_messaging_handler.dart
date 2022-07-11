import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:push_messaging/push_messaging.dart';
import 'package:push_messaging/src/push_messaging.dart';

/// Signature for callbacks that get triggered when a [RemoteMessage] is
/// received in the foreground or background.
typedef OnMessage = Future<void> Function(RemoteMessage message);

/// {@template push_messaging_handler}
/// A widget that handles push messages.
///
/// This widget must only be added once to the widget tree.
/// {@endtemplate}
class PushMessagingHandler extends StatefulWidget {
  /// {@macro push_messaging_handler}
  const PushMessagingHandler({
    required this.notifications,
    this.onForegroundMessage,
    this.onBackgroundMessage,
    this.onNotificationOpened,
    this.androidNotificationSettings = const AndroidNotificationSettings(),
    this.enableForegroundNotifications = false,
    this.child,
    super.key,
  });

  /// The [PushMessaging] instance used for dealing with push notifications.
  final Notifications? notifications;

  /// The callback the gets triggered when a message is received while the
  /// application is in the foreground.
  final OnMessage? onForegroundMessage;

  /// The callback the gets triggered when a message is received while the
  /// application is in the background but not terminated.
  ///
  /// This must be a static or top level function. Otherwise it won't get called
  /// properly.
  final OnMessage? onBackgroundMessage;

  /// The callback that gets trigger when a notification is opened by the user.
  final OnNotificationOpened? onNotificationOpened;

  /// Settings for customizing Android notifications.
  final AndroidNotificationSettings androidNotificationSettings;

  /// Whether notifications should be display when the application is in the
  /// foreground.
  final bool enableForegroundNotifications;

  /// The child widget.
  final Widget? child;

  @override
  State<PushMessagingHandler> createState() => _PushMessagingHandlerState();
}

class _PushMessagingHandlerState extends State<PushMessagingHandler> {
  StreamSubscription? _onMessageSubscription;
  StreamSubscription? _onMessageOpenedAppSubscription;

  late final Notifications _notifications;

  @override
  void didUpdateWidget(covariant PushMessagingHandler oldWidget) {
    if (oldWidget.onBackgroundMessage != widget.onBackgroundMessage) {
      if (widget.onBackgroundMessage == null) {
        // set empy function as background handler in order to reset the
        // previously registered one
        FirebaseMessaging.onBackgroundMessage(_backgroundHandlerReset);
      } else {
        _registerBackgroundRemoteMessageHandler();
      }
    }

    if (oldWidget.onForegroundMessage != widget.onForegroundMessage) {
      _onMessageSubscription?.cancel();
      _startListeningToRemoteMessages();
    }

    if (oldWidget.onNotificationOpened != widget.onNotificationOpened) {
      _initNotifications(isReinitialization: true);
    }

    // update android notification channels if needed
    if (oldWidget.androidNotificationSettings !=
            widget.androidNotificationSettings ||
        oldWidget.enableForegroundNotifications !=
            widget.enableForegroundNotifications) {
      _notifications.updateAndroidNotificationChannels(
        notificationChannelSettings:
            widget.androidNotificationSettings.notificationChannelSettings,
      );
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    _notifications = widget.notifications ?? PushMessaging();

    // we initialize PushMessaging here since it does not take too much time
    // and we also only use it once the initialization is done.
    _initNotifications();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<PushMessagingHandler>() == null,
      '`PushMessagingHandler` is already part of the widget tree! '
      'This widget must not be added mutliple times to the widget tree. '
      'Otherwise this could lead to unwanted push notification behavior.',
    );

    return widget.child ?? const SizedBox();
  }

  @override
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToRemoteMessages() {
    if (_onMessageSubscription != null) {
      _onMessageSubscription!.cancel();
    }

    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen((message) async {
      // only display foreground notifications on Android manually since
      // this gets handled on iOS automatically.
      if (Platform.isAndroid &&
          message.isNotification &&
          widget.enableForegroundNotifications) {
        await _notifications.showRemoteMessageNotification(
          message: message,
        );
      } else if (widget.onForegroundMessage != null) {
        await widget.onForegroundMessage!(message);
      }
    });
  }

  void _registerBackgroundRemoteMessageHandler() {
    FirebaseMessaging.onBackgroundMessage(widget.onBackgroundMessage!);
  }

  void _initNotifications({
    bool isReinitialization = false,
  }) {
    _notifications
        .setupNotifications(
      onNotificationSelected: widget.onNotificationOpened,
      enableForegroundNotifications: widget.enableForegroundNotifications,
      androidSettings: widget.androidNotificationSettings,
      shouldUpdateAndroidNotificationChannels: !isReinitialization,
    )
        .then((value) {
      if (widget.onBackgroundMessage != null) {
        _registerBackgroundRemoteMessageHandler();
      }

      _startListeningToRemoteMessages();

      if (_onMessageOpenedAppSubscription != null) {
        _onMessageOpenedAppSubscription!.cancel();
      }

      // listen to firebase cloud message open events
      _onMessageOpenedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
        widget.onNotificationOpened?.call(message.data);
      });
    });
  }

  /// A placeholder method that gets registered as background handler if the
  /// previously registered handler should be removed.
  static Future<void> _backgroundHandlerReset(
    RemoteMessage message,
  ) async {}
}

extension _RemoteMessageX on RemoteMessage {
  /// Whether the message is a notification or not.
  ///
  /// There are two different types of messages:
  /// - _Notification_: a [RemoteMessage] which contains the #
  /// [RemoteMessage.notification] property. Could also container the
  /// [RemoteMessage.data] property.
  /// - _Data Message_: a [RemoteMessage] without and
  /// [RemoteMessage.notification] information but the mandatory
  /// [RemoteMessage.data] property.
  bool get isNotification => notification != null;
}
