import 'package:smython/smython.dart';

final source = """
def fac(n):
    if n == 0:
        return 1
    return n * fac(n - 1)
print(fac(10))
""";

void main() {
  Smython().execute(source);
}
