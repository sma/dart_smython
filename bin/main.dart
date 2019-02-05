import 'package:smython/smython.dart';

final source1 = """
def fac(n):
    if n == 0:
        return 1
    return n * fac(n - 1)
print(fac(10))
""";

final source2 = """
def fib(n):
    if n <= 2:
        return 1
    return fib(n - 1) + fib(n - 2)
print(fib(20))
""";

void main() {
  Smython()..execute(source1)..execute(source2);
}
