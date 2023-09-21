import 'package:logger/logger.dart';

Logger get logger => Log.instance;

class Log extends Logger {
  static final instance = Log._();
  Log._() : super(printer: PrettyPrinter(printTime: true));
}
