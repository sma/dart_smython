import 'dart:io';

import 'package:smython/ast_eval.dart';
import 'package:smython/parser.dart';

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
      final frame = Frame(null, {}, {
        'len': (Frame f, List args) {
          return args[0].length;
        },
        'slice': (Frame f, List args) {
          return args;
        }
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
  if (value == null) return 'None';
  if (value is String) {
    return '\'${value.replaceAll('\\', '\\\\').replaceAll('\'', '\\\'').replaceAll('\n', '\\n')}\'';
  }
  return '$value';
}
