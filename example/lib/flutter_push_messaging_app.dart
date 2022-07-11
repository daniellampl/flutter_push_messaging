import 'package:flutter/material.dart';
import 'package:flutter_push_messaging/flutter_push_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flutterPushMessagingProvider = Provider<FlutterPushMessaging>((ref) {
  return FlutterPushMessaging();
});

class FlutterPushMessagingApp extends ConsumerWidget {
  const FlutterPushMessagingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PushMessagingHandler(
      // TODO: find a solution to not pass the instance to the handler (maybe a singleton for notification handling)
      notifications: ref.watch(flutterPushMessagingProvider),
      child: MaterialApp(
        title: 'Flutter Push Messaging Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Push Messaging'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                Text("You're currently testing flutter_push_messaging"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
