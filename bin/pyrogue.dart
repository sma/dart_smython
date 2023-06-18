import 'dart:io';

import 'package:smython/smython.dart';

final system = Smython();

/// Loads and runs [filename] which must be a valid Smython program.
void run(String filename) {
  system.execute(File(filename).readAsStringSync());
}

/// Tries to load and parse all files in the `pyrogue` folder.
void testParse(String filename) {
  var failures = 0;
  for (final file in Directory(filename).listSync().whereType<File>().where((f) => f.path.endsWith('.py'))) {
    if (file.path.contains('xref.py')) continue;
    try {
      parse(file.readAsStringSync());
    } catch (err) {
      print('${file.path} -> $err');
      failures++;
    }
  }
  if (failures > 0) print('Failures: $failures');
}

void main() {
  testParse('pyrogue');
  run('pyrogue/main.py');
}
