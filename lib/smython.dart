import 'ast_eval.dart';
import 'parser.dart';

class Smython {
  final Map<String, dynamic> globals = {
    'print': (Frame cf, List<dynamic> args) => print(args.map((v) => '$v').join(' ')),
  };

  void execute(String source) {
    Parser(source).parseFileInput().execute(Frame(null, {}, globals));
  }
}
