/// A test runner for Smython source code.
///
/// Lines starting with `#` and empty lines are ignored. Lines starting
/// with `>>>` or `...` are stripped from the prefix, are combined and then
/// executed as Symthon code, comparing the result of the last expression
/// to the next non-empty, non-comment line without a prefix, after using
/// [repr] to convert the result of the evaluation into a string
/// representation for easy comparison.
///
/// Then either `OK` is printed or both the actual and the expected value.
///
/// After running all tests, the number of failures is printed. If the
/// output ends with `OK`, there are no failure and everything is shiny.
library test_runner;

import 'dart:io';

import 'smython.dart';

/// Runs the Smython test suite loaded from [filename].
bool run(String filename) {
  var failures = 0;
  final report = stdout;
  final buffer = StringBuffer();

  for (final line in File(filename).readAsLinesSync()) {
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('>>> ') || line.startsWith('... ')) {
      buffer.writeln(line.substring(4));
    } else {
      final expected = line;
      final source = buffer.toString();
      // report.writeln('----------');
      // report.write(source);

      String actual;
      try {
        final suite = parse(source);
        final frame = Frame(null, {}, {}, Smython().builtins);
        actual = repr(suite.evaluate(frame));
      } catch (e) {
        actual = '$e';
      }
      if (actual == expected) {
        // report.writeln('OK');
      } else {
        report.writeln('----------');
        report.write(source);
        report.writeln('Actual..: $actual');
        report.writeln('Expected: $expected');
        failures++;
      }

      buffer.clear();
    }
  }
  if (failures > 0) {
    report.writeln('----------');
    report.writeln('$failures failure(s)');
  }
  return failures == 0;
}

/// Returns a canonical string prepresentation of the given [value] that
/// can be used to compare a computed value to a stringified value from the
/// the suite. Strings are therefore displayed always with single quotes.
/// Sets and dictionaries are displayed after sorting their keys first.
/// Then sets, dictionaries, and lists are recursively displayed using
/// [repr]. All other values are displayed using their `toString` method.
String repr(SmyValue? value) {
  if (value == null) throw 'missing value';
  if (value is SmyString) {
    return "'${value.value.replaceAll('\\', '\\\\').replaceAll('\'', '\\\'').replaceAll('\n', '\\n')}'";
  } else if (value is SmyTuple) {
    return '(${value.values.map(repr).join(', ')}${value.length == 1 ? ',' : ''})';
  } else if (value is SmyList) {
    return '[${value.values.map(repr).join(', ')}]';
  } else if (value is SmySet) {
    return '{${(value.values.map(repr).toList()..sort()).join(', ')}}';
  } else if (value is SmyDict) {
    final v = value.values.entries.map((e) => MapEntry(repr(e.key), repr(e.value))).toList();
    return '{${(v..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}: ${e.value}').join(', ')}}';
  }
  return '$value';
}
