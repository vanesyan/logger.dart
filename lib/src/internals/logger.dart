import "dart:async" show Completer, StreamController, Zone;

import "package:logger/logger.dart"
    show ContextBuilder, Handler, Interface, Level, Logger, Tracer, Record;

import "context.dart";
import "context_builder.dart" show ContextBuilderImpl;

final Map<String, LoggerImpl> _loggers = {};

class LoggerImpl implements Logger {
  LoggerImpl({this.name})
      : _level = Level.info,
        _completer = Completer(),
        _controller = StreamController<Record>.broadcast(sync: true),
        _isClosed = false {
    _context = Context(this);
  }

  factory LoggerImpl.getLogger(String name) {
    if (_loggers.containsKey(name)) {
      return _loggers[name];
    }

    final logger = LoggerImpl(name: name);
    _loggers[name] = logger;

    return logger;
  }

  final Completer<void> _completer;
  final StreamController<Record> _controller;
  bool _isClosed;
  Context _context;
  Level _level;

  @override
  final String name;

  Stream<Record> get _onRecord => _controller?.stream;

  @override
  bool get isClosed => _isClosed;

  @override
  Level get level => _level;

  @override
  set level(Level level) {
    if (level == null) {
      throw ArgumentError.notNull("level");
    }

    _level = level;
  }

  @override
  Future<void> get done => _completer.future;

  void _cleanUp() {
    _isClosed = true;

    if (name != null) {
      _loggers.remove(name);
    }
  }

  Future<void> _close() {
    if (isClosed) {
      return Future.error("Logger is already closed!");
    }

    _cleanUp();

    // ignore: avoid_annotating_with_dynamic
    return _controller.close().then<void>((dynamic _) {
      _completer.complete();

      return _completer.future;
    });
  }

  void write(Record record) => _controller?.add(record);

  @override
  void addHandler(Handler handler) {
    handler.subscription = _onRecord?.listen(handler, onDone: handler.close);
  }

  @override
  Future<void> close() => _close();

  @override
  bool isEnabledFor(Level other) => level <= other;

  @override
  void log(Level level, String message, [Zone zone]) =>
      _context.log(level, message, zone);

  @override
  void debug(String message) => _context.debug(message);

  @override
  void info(String message) => _context.info(message);

  @override
  void warning(String message) => _context.warning(message);

  @override
  void error(String message) => _context.error(message);

  @override
  void fatal(String message, {bool die = true}) =>
      _context.fatal(message, die: die);

  @override
  Tracer trace(String message) => _context.trace(message);

  @override
  ContextBuilder<Interface> bind() => ContextBuilderImpl(this);
}
