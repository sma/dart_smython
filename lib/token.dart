/// Represents a piece of source code.
///
/// Tokens are either keywords, NAMEs, NUMBERs, STRINGs, operators, syntax,
/// or synthesized INDENT, DEDENT, NEWLINE or EOF tokens. Currently, these
/// syntheized tokens have no valid line number.
class Token {
  const Token(this._source, this._start, this._end);

  final String _source;
  final int _start;
  final int _end;

  /// Returns the piece of source code this token represents.
  String get value => _source.substring(_start, _end);

  /// Returns whether this token is a Smython keyword.
  bool get isKeyword => _keywords.contains(value);

  /// Returns whether this token is a NAME but not also a keyword.
  bool get isName => value.startsWith(RegExp('[A-Za-z_]')) && !isKeyword;

  /// Returns whether this token is a (positive) NUMBER.
  bool get isNumber => value.startsWith(RegExp('[0-9]'));

  /// Returns whether this token is a quoted STRING.
  bool get isString => _source[_start] == '"' || _source[_start] == "'";

  /// Returns the token's numeric value (only valid if [isNumber] is true).
  int get number => int.parse(value);

  /// Returns the token's string value (only valid if [isString] is true).
  String get string => _unescape(_source.substring(_start + 1, _end - 1));

  /// Returns the line of the source code this token is at (1-based).
  int get line {
    var line = 1;
    for (var i = 0; i < _start; i++) {
      if (_source[i] == '\n') line++;
    }
    return line;
  }

  @override
  bool operator ==(dynamic other) {
    return other is Token && value == other.value;
  }

  @override
  String toString() => '«$value»';

  static const indent = Token('!INDENT', 0, 7);

  static const dedent = Token('!DEDENT', 0, 7);

  static const eof = Token('!EOF', 0, 4);

  static String _unescape(String s) {
    // see scanner.dart for which string escapes are supported
    return s.replaceAllMapped(RegExp('\\\\([n\'"\\\\])'), (match) {
      final s = match.group(1)!;
      return s == 'n' ? '\n' : s;
    });
  }

  static const _keywords = {
    'and',
    'as',
    'assert',
    'break',
    'class',
    'continue',
    'def',
    //'del',
    'elif',
    'else',
    'except',
    'exec',
    'finally',
    'for',
    'from',
    'global',
    'if',
    'import',
    'in',
    'is',
    'lambda',
    'not',
    'or',
    'pass',
    'raise',
    'return',
    'try',
    'while',
    'with',
    'yield',
  };
}
