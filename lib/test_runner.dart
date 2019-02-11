import 'dart:io';

import 'package:smython/parser.dart';
import 'package:smython/smython.dart';

void run(String filename) {
  int failures = 0;
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
      final frame = Frame(null, {}, {}, Smython().builtins);

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
        failures++;
      }

      buffer.clear();
    }
  }
  if (failures > 0) {
    report.writeln('----------');
    report.writeln('$failures failure(s)');
  }
}

String repr(dynamic value) {
  if (value == null) throw 'missing value';
  if (value is SmyString) {
    return '\'${value.value.replaceAll('\\', '\\\\').replaceAll('\'', '\\\'').replaceAll('\n', '\\n')}\'';
  }
  return '$value';
}
