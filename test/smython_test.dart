import 'package:smython/test_runner.dart';
import 'package:test/test.dart';

void main() {
  test('test runner', () {
    expect(run('parser_tests.py'), isTrue);
  });
}
