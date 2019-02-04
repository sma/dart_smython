class Token {
  final String _source;
  final int _start;
  final int _end;

  const Token(this._source, this._start, this._end);

  String get value => _source.substring(_start, _end);

  bool get isKeyword => _keywords.contains(value);
  bool get isName => value.startsWith(RegExp('[A-Za-z_]')) && !isKeyword;
  bool get isNumber => value.startsWith(RegExp('[0-9]'));
  double get number => double.parse(value);

  bool operator ==(dynamic other) {
    return value == other.value;
  }

  String toString() => '«$value»';

  static const indent = Token("!INDENT", 0, 7);
  static const dedent = Token("!DEDENT", 0, 7);
  static const eof = Token("!EOF", 0, 4);
}

final _keywords = Set.of([
  "and",
  "as",
  "assert",
  "break",
  "class",
  "continue",
  "def",
  "del",
  "elif",
  "else",
  "except",
  "exec",
  "finally",
  "for",
  "from",
  "global",
  "if",
  "import",
  "in",
  "is",
  "lambda",
  "not",
  "or",
  "pass",
  "raise",
  "return",
  "try",
  "while",
  "with",
  "yield",
]);
