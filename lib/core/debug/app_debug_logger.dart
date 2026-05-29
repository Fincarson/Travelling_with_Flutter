import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class AppDebugLogger {
  AppDebugLogger._();

  static bool _initialized = false;
  static DateTime _lastFrameLog = DateTime.fromMillisecondsSinceEpoch(0);
  static FlutterExceptionHandler? _previousFlutterError;
  static ErrorCallback? _previousPlatformError;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      logException('FlutterError', details.exception, details.stack);
      (_previousFlutterError ?? FlutterError.presentError)(details);
    };

    _previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      logException('PlatformDispatcher', error, stack);
      return _previousPlatformError?.call(error, stack) ?? false;
    };

    SchedulerBinding.instance.addTimingsCallback(_logFrameTimings);

    assert(() {
      debugPrintRebuildDirtyWidgets = true;
      debugPrintScheduleBuildForStacks = true;
      debugProfileBuildsEnabled = true;
      debugProfilePaintsEnabled = true;
      return true;
    }());

    debugPrint('[app-debug] Logger active.');
  }

  static void logZoneError(Object error, StackTrace stack) {
    logException('runZonedGuarded', error, stack);
  }

  static void logStateChange(String source, String message) {
    debugPrint('[app-debug][state] $source: $message');
  }

  static void logException(String source, Object error, StackTrace? stack) {
    debugPrint('[app-debug][error][$source] $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack, maxFrames: 16);
    }
  }

  static void _logFrameTimings(List<FrameTiming> timings) {
    final now = DateTime.now();
    if (now.difference(_lastFrameLog) < const Duration(seconds: 2)) return;
    _lastFrameLog = now;

    var buildMicros = 0;
    var rasterMicros = 0;
    var totalMicros = 0;
    for (final timing in timings) {
      buildMicros += timing.buildDuration.inMicroseconds;
      rasterMicros += timing.rasterDuration.inMicroseconds;
      totalMicros += timing.totalSpan.inMicroseconds;
    }

    final count = timings.length;
    if (count == 0) return;
    final avgTotal = totalMicros / count;
    final estimatedFps = avgTotal <= 0
        ? 0.0
        : Duration.microsecondsPerSecond / avgTotal;

    debugPrint(
      '[app-debug][frame] avg build=${_ms(buildMicros / count)}ms '
      'raster=${_ms(rasterMicros / count)}ms '
      'total=${_ms(avgTotal)}ms est=${estimatedFps.toStringAsFixed(1)}fps',
    );
  }

  static String _ms(num microseconds) {
    return (microseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(
      2,
    );
  }
}
