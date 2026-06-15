import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

@immutable
class AppErrorData {
  const AppErrorData({required this.code, required this.details});

  factory AppErrorData.from(
    Object error, [
    StackTrace? stackTrace,
    String? code,
  ]) {
    final message = error.toString().trim();
    final resolvedCode = code?.trim().isNotEmpty == true
        ? code!.trim()
        : _errorCode(error);
    final stack = stackTrace?.toString().trim();
    return AppErrorData(
      code: resolvedCode,
      details: stack == null || stack.isEmpty ? message : '$message\n\n$stack',
    );
  }

  factory AppErrorData.fromMessage(String message) {
    final clean = message.trim();
    final firebaseCode = RegExp(
      r'\[firebase_[^/]+/([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(clean)?.group(1);
    return AppErrorData(
      code: firebaseCode ?? 'unexpected-error',
      details: clean,
    );
  }

  final String code;
  final String details;
}

class AppErrorController {
  static final ValueNotifier<AppErrorData?> current = ValueNotifier(null);

  static void report(Object error, [StackTrace? stackTrace, String? code]) {
    final data = AppErrorData.from(error, stackTrace, code);
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      current.value = data;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      current.value = data;
    });
  }

  static void clear() {
    current.value = null;
  }
}

bool looksLikeTechnicalError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('setstate(') ||
      lower.contains('markneedsbuild') ||
      lower.contains('stack trace') ||
      lower.contains('firebase_') ||
      lower.contains('firebaseexception') ||
      lower.contains('platformexception') ||
      lower.contains('failed assertion') ||
      lower.contains('#0 ');
}

String _errorCode(Object error) {
  if (error is FirebaseException && error.code.trim().isNotEmpty) {
    return error.code.trim();
  }
  if (error is PlatformException && error.code.trim().isNotEmpty) {
    return error.code.trim();
  }

  final text = error.toString();
  if (text.toLowerCase().contains('setstate(')) return 'invalid-set-state';
  final name = error.runtimeType.toString();
  return name
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => '-')
      .replaceAll('_', '-')
      .toLowerCase();
}
