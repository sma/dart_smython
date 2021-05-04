/// Splits source code into tokens.
library scanner;

import 'token.dart';
export 'token.dart';

/// Returns an iterable of [Token]s tokenized from [source].
///
/// * Code must be indented by exactly four spaces.
/// * TABs are not allowed.
/// * Open parentheses do not relax indentation rules.
Iterable<Token> tokenize(String source) sync* {
  // keep track of indentation
  var curIndent = 0;
  var newIndent = 0;

  // combine lines with trailing backslashes with following lines
  source = source.replaceAll('\\\n', '');

  // assure that the source ends with a newline
  source += '\n';

  // compile the regular expression to tokenize the source
  final _regex = RegExp(
    '^ *(?:#.*)?\n|#.*\$|(' // whitespace and comments
    '^ +|' // indentation
    '\n|' // newline
    '\\d+(?:\\.\\d*)?|' // numbers
    '\\w+|' // names
    '[()\\[\\]{}:.,;]|' // syntax
    '[+\\-*/%<>=]=?|!=|' // operators
    "'(?:\\\\[n'\"\\\\]|[^'])*'|" // single-quote strings
    '"(?:\\\\[n\'"\\\\]|[^"])*"' // double-quote strings
    ')',
    multiLine: true,
  );

  for (final match in _regex.allMatches(source)) {
    // did we get a match (empty lines and comments are ignored)?
    final s = match.group(1);
    if (s == null) continue;
    if (s[0] == ' ') {
      // compute new indentation which is applied before the next non-whitespace token
      newIndent = s.length ~/ 4;
    } else {
      if (s[0] == '\n') {
        // reset indentation
        newIndent = 0;
      } else {
        // found a non-whitespace token, apply new indentation
        while (curIndent < newIndent) {
          yield Token.indent;
          curIndent++;
        }
        while (curIndent > newIndent) {
          yield Token.dedent;
          curIndent--;
        }
      }
      // add newline or non-whitespace token to result
      yield Token(match.input, match.start, match.end);
    }
  }

  // balance pending INDENTs
  while (curIndent > 0) {
    yield Token.dedent;
    curIndent--;
  }

  // append EOF
  yield Token.eof;
}
