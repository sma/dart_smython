import 'ast_eval.dart';
import 'scanner.dart';

class Parser {
  final Iterator<Token> _iter;

  Parser(String source) : _iter = tokenize(source).iterator {
    advance();
  }

  // -------- Helper --------

  /// Returns the current token.
  Token get token => _iter.current;

  /// Consumes the curent token and advances to the next token.
  void advance() => _iter.moveNext();

  /// Consumes the current token only if its value is [value].
  bool at(String value) {
    if (token.value == value) {
      advance();
      return true;
    }
    return false;
  }

  /// Consumes the current token if its value is [value]
  /// and throws a [ParserError] otherwise.
  void expect(String value) {
    if (!at(value)) throw ParserError("expected $value but found $token at some line");
  }

  bool get atNewline => at("\n");

  // -------- Suite parsing --------

  // file_input: {NEWLINE | stmt} ENDMARKER
  Suite parseFileInput() {
    final stmts = <Stmt>[];
    while (!at(Token.eof.value)) {
      if (!atNewline) stmts.addAll(parseStmt());
    }
    return Suite(stmts);
  }

  // suite: simple_stmt | NEWLINE INDENT stmt+ DEDENT
  Suite parseSuite() {
    if (atNewline) {
      expect(Token.indent.value);
      final stmts = <Stmt>[];
      while (!at(Token.dedent.value)) {
        stmts.addAll(parseStmt());
      }
      return Suite(stmts);
    }
    return Suite(parseSimpleStmt());
  }

  // -------- Compount statement parsing --------

  // stmt: simple_stmt | compound_stmt
  List<Stmt> parseStmt() {
    final stmt = parseCompoundStmt();
    if (stmt != null) return [stmt];
    return parseSimpleStmt();
  }

  // compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | funcdef | classdef
  Stmt parseCompoundStmt() {
    if (at("if")) return parseIfStmt();
    //if (at("while")) return parseWhileStmt();
    //if (at("for")) return parseForStmt();
    //if (at("try")) return parseTryStmt();
    if (at("def")) return parseFuncDef();
    //if (at("class")) return parseClassDef();
    return null;
  }

  // funcdef: 'def' NAME parameters ':' suite
  Stmt parseFuncDef() {
    final name = parseName();
    final params = parseParameters();
    expect(":");
    return DefStmt(name, params, parseSuite());
  }

  // parameters: '(' [NAME {',' NAME} [',']] ')'
  List<String> parseParameters() {
    final params = <String>[];
    expect("(");
    if (at(")")) return params;
    params.add(parseParameter());
    while (at(",")) {
      if (at(")")) return params;
      params.add(parseParameter());
    }
    expect(")");
    return params;
  }

  // parameter: NAME ['=' test]
  String parseParameter() {
    final name = parseName();
    if (at("=")) {
      throw ParserError("default parameter value not yet implemented");
    }
    return name;
  }

  // if_stmt: 'if' test ':' suite {'elif' test ':' suite} ['else' ':' suite]
  Stmt parseIfStmt() {
    final test = parseTest();
    expect(":");
    return IfStmt(test, parseSuite(), parseIfStmtCont());
  }

  // private: ['elif' test ':' suite | 'else' ':' suite]
  Suite parseIfStmtCont() {
    if (at("elif")) {
      final test = parseTest();
      expect(":");
      return Suite([IfStmt(test, parseSuite(), parseIfStmtCont())]);
    }
    return parseElse();
  }

  //private: ['else' ':' suite]
  Suite parseElse() {
    if (at("else")) {
      expect(":");
      return parseSuite();
    }
    return Suite([const PassStmt()]);
  }

  // -------- Simple statement parsing --------

  // simple_stmt: small_stmt {';' small_stmt} [';'] NEWLINE
  List<Stmt> parseSimpleStmt() {
    final stmts = <Stmt>[parseSmallStmt()];
    while (at(";")) {
      if (atNewline) return stmts;
      stmts.add(parseSmallStmt());
    }
    expect("\n");
    return stmts;
  }

  // small_stmt: expr_stmt | pass_stmt | flow_stmt
  // flow_stmt: break_stmt | return_stmt | raise_stmt
  Stmt parseSmallStmt() {
    if (at("pass")) return const PassStmt();
    // if (at("break")) return const BreakStmt();
    if (at("return")) {
      return ReturnStmt(hasTest ? parseTestListAsTuple() : const LitExpr(null));
    }
    // if (at("raise")) ...
    return parseExprStmt();
  }

  // expr_stmt: testlist [('+=' | '-=' | '*=' | '/=' | '%=' | '=') testlist]
  Stmt parseExprStmt() {
    if (hasTest) {
      final expr = parseTestListAsTuple();
      // if (at("=")) return [AssignStmt stmtWithLeftExpr:expr rightExpr:parseTestListAsTuple()];
      // if (at("+=")) return [AddAssignStmt stmtWithLeftExpr:expr rightExpr:parseTestListAsTuple()];
      // if (at("-=")) return [SubAssignStmt stmtWithLeftExpr:expr rightExpr:parseTestListAsTuple()];
      return ExprStmt(expr);
    }
    return throw ParserError("expected statement but found $token at some line");
  }

  // -------- Expression parsing --------

  // test: or_test ['if' or_test 'else' test]
  Expr parseTest() {
    return parseOrTest();
  }

  // or_test: and_test {'or' and_test}
  Expr parseOrTest() {
    return parseAndTest();
  }

  // and_test: not_test {'and' not_test}
  Expr parseAndTest() {
    return parseNotTest();
  }

  // not_test: 'not' not_test | comparison
  Expr parseNotTest() {
    return parseComparison();
  }

  // comparison: expr [('<'|'>'|'=='|'>='|'<='|'!='|'in'|'not' 'in'|'is' ['not']) expr]
  Expr parseComparison() {
    final expr = parseExpr();
    if (at("==")) return EqExpr(expr, parseExpr());
    return expr;
  }

  // expr: term {('+'|'-') term}
  Expr parseExpr() {
    var expr = parseTerm();
    while (true) {
      if (at("-"))
        expr = SubExpr(expr, parseTerm());
      else
        break;
    }
    return expr;
  }

  // term: factor {('*'|'/'|'%') factor}
  Expr parseTerm() {
    var expr = parseFactor();
    while (true) {
      if (at("*"))
        expr = MulExpr(expr, parseFactor());
      else
        break;
    }
    return expr;
  }

  // factor: ('+'|'-') factor | power
  Expr parseFactor() {
    return parsePower();
  }

  // power: atom {trailer}
  Expr parsePower() {
    var expr = parseAtom();
    // trailer: '(' [testlist] ')' | '[' subscript ']' | '.' NAME
    while (true) {
      if (at("(")) {
        expr = CallExpr(expr, parseTestlistOpt());
        expect(")");
      } else {
        break;
      }
    }
    return expr;
  }

  // atom: '(' [testlist] ')' | '[' [testlist] ']' | '{' [dictorsetmaker] '}' | NAME | NUMBER | STRING+
  Expr parseAtom() {
    final t = token;
    if (t.isName) {
      advance();
      return VarExpr(t.value);
    }
    if (t.isNumber) {
      advance();
      return LitExpr(t.number);
    }
    throw ParserError("unsupported atom $t");
  }

  // NAME
  String parseName() {
    final t = token;
    if (t.isName) {
      advance();
      return t.value;
    }
    throw ParserError("expected NAME but found $t at some line");
  }

  // -------- Expression list parsing --------

  // testlist: test {',' test} [',']
  Expr parseTestListAsTuple() {
    return parseTest();
  }

  // testlist: test {',' test} [',']
  List<Expr> parseTestlistOpt() {
    final exprs = <Expr>[];
    if (hasTest) {
      exprs.add(parseTest());
      while (at(",")) {
        if (!hasTest) break;
        exprs.add(parseTest());
      }
    }
    return exprs;
  }

  bool get hasTest {
    final t = token;
    return t.isName || t.isNumber || "+-([{\"'_".contains(t.value[0]);
  }
}

class ParserError extends Error {
  final String message;

  ParserError(this.message);

  String toString() => message;
}
