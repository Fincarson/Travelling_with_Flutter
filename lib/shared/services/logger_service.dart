import 'dart:developer' as developer;

class LoggerService {
  void log(String message) {
    developer.log(message, name: 'TravelPlan');
  }
}
