import 'dart:io';

import 'package:smython/parser.dart';
import 'package:smython/smython.dart';

void run(String filename) {
  final report = stdout;
  final buffer = StringBuffer();

  for (final line in File(filename).readAsLinesSync()) {
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('>>> ') || line.startsWith('... ')) {
      buffer.writeln(line.substring(4));
    } else {
      final expected = line;
      final source = buffer.toString();
      report.writeln('----------');
      report.write(source);

      final suite = parse(source);
      final frame = Frame(null, {}, {}, {
        SmyString('len'): SmyBuiltin((Frame f, List<SmyValue> args) {
          return SmyInt(args[0].length);
        }),
        SmyString('slice'): SmyBuiltin((Frame f, List<SmyValue> args) {
          return SmyTuple(args);
        }),
      });

      String actual;
      try {
        actual = repr(suite.evaluate(frame));
      } catch (e) {
        actual = '$e';
      }
      if (actual == expected) {
        report.writeln("OK");
      } else {
        report.writeln("Actual..: $actual");
        report.writeln("Expected: $expected");
      }

      buffer.clear();
    }
  }
}

String repr(dynamic value) {
  if (value == null) throw 'missing value';
  if (value is SmyString) {
    return '\'${value.value.replaceAll('\\', '\\\\').replaceAll('\'', '\\\'').replaceAll('\n', '\\n')}\'';
  }
  return '$value';
}
