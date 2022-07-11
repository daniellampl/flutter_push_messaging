import 'package:example/flutter_push_messaging_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  final container = ProviderContainer();

  await container.read(flutterPushMessagingProvider).requestPermissions();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FlutterPushMessagingApp(),
    ),
  );
}
