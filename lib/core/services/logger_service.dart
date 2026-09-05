import 'package:logging/logging.dart';

class LoggerService {
  static final Logger _logger = Logger('CardCircle');

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // In production, you could integrate with Sentry/Crashlytics here
      // For debug/development, we output clean formatted print statements
      // ignore: avoid_print
      print(
        '[${record.level.name}] ${record.time} - ${record.loggerName}: ${record.message}',
      );
      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: ${record.stackTrace}');
      }
    });
  }

  static void debug(String message) => _logger.fine(message);
  static void info(String message) => _logger.info(message);
  static void warning(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => _logger.warning(message, error, stackTrace);
  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
