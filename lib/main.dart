import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_restart_scope.dart';
import 'core/errors/app_error.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'shared/widgets/app_error_widgets.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint = (String? message, {int? wrapWidth}) {};
  // Most framework and asynchronous errors are recoverable and should not
  // replace an otherwise usable page.
  FlutterError.onError = (_) {};
  PlatformDispatcher.instance.onError = (_, _) => true;
  ErrorWidget.builder = (details) {
    return PageErrorFallback(
      error: AppErrorData.from(details.exception, details.stack),
    );
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (_supportsFirebaseMessaging) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    runApp(const AppRestartScope(child: MyApp()));
  } catch (error, stackTrace) {
    runApp(_BootstrapErrorApp(error: AppErrorData.from(error, stackTrace)));
  }
}

bool get _supportsFirebaseMessaging {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final AppErrorData error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TravelAgentTheme.light(),
      home: UnexpectedErrorView(error: error, showBackButton: false),
    );
  }
}
