import 'dart:collection';

// -------- Suite --------

class Suite {
  final List<Stmt> stmts;
  const Suite(this.stmts);

  dynamic evaluate(Frame f) {
    dynamic result = null;
    for (final stmt in stmts) {
      try {
        result = stmt.evaluate(f);
      } on _Return catch (e) {
        return e.value;
      }
    }
    return result;
  }
}

// -------- Stmt --------

abstract class Stmt {
  const Stmt();

  dynamic evaluate(Frame f);
}

/// `if test: thenSuite else: elseSuite`
class IfStmt extends Stmt {
  final Expr test;
  final Suite thenSuite;
  final Suite elseSuite;
  const IfStmt(this.test, this.thenSuite, this.elseSuite);

  @override
  dynamic evaluate(Frame f) {
    if (test.evaluate(f) as bool) {
      thenSuite.evaluate(f);
    } else {
      elseSuite.evaluate(f);
    }
  }
}

/// `while test: suite else: elseSuite`
class WhileStmt extends Stmt {
  final Expr test;
  final Suite suite;
  final Suite elseSuite;
  const WhileStmt(this.test, this.suite, this.elseSuite);

  @override
  dynamic evaluate(Frame f) {
    while (test.evaluate(f)) {
      try {
        suite.evaluate(f);
      } on _Break {
        return;
      }
      elseSuite.evaluate(f);
    }
  }
}

/// `for target, ... in test, ...: suite else: suite`
class ForStmt extends Stmt {
  final Expr target;
  final Expr items;
  final Suite suite;
  final Suite elseSuite;
  const ForStmt(this.target, this.items, this.suite, this.elseSuite);

  @override
  dynamic evaluate(Frame f) {
    Iterable i = items.evaluate(f);
    for (final value in i) {
      target.assign(f, value);
      try {
        suite.evaluate(f);
      } on _Break {
        return;
      }
    }
    elseSuite.evaluate(f);
  }
}

/// `try: suite finally: suite`
class TryFinallyStmt extends Stmt {
  final Suite suite, finallySuite;
  const TryFinallyStmt(this.suite, this.finallySuite);

  @override
  dynamic evaluate(Frame f) {
    try {
      suite.evaluate(f);
    } finally {
      finallySuite.evaluate(f);
    }
  }
}

/// `try: suite except test as name: suite else: suite`
class TryExceptStmt extends Stmt {
  const TryExceptStmt(Suite trySuite, List<ExceptClause> excepts, Suite elseSuite);

  @override
  dynamic evaluate(Frame f) => throw "not yet implemented";
}

class ExceptClause {
  const ExceptClause(Expr test, String name, Suite suite);
}

/// `def name(param, ...): suite`
class DefStmt extends Stmt {
  final String name;
  final List<String> params;
  final List<Expr> defs;
  final Suite suite;
  const DefStmt(this.name, this.params, this.defs, this.suite);

  @override
  dynamic evaluate(Frame f) {
    f.locals[name] = _Func(f, params, defs, suite);
  }
}

/// `class name (super): suite`
class ClassStmt extends Stmt {
  final String name;
  final Expr superExpr;
  final Suite suite;
  const ClassStmt(this.name, this.superExpr, this.suite);

  @override
  dynamic evaluate(Frame f) {
    final cls = SmClass(name, superExpr.evaluate(f));
    suite.evaluate(Frame(f, cls.methods, f.globals));
  }
}

/// `pass`
class PassStmt extends Stmt {
  const PassStmt();

  dynamic evaluate(Frame f) {}
}

/// `break`
class BreakStmt extends Stmt {
  const BreakStmt();

  @override
  dynamic evaluate(Frame f) => throw _Break();
}

/// `return`, `return test, ...`
class ReturnStmt extends Stmt {
  final Expr expr;
  const ReturnStmt(this.expr);

  @override
  dynamic evaluate(Frame f) => throw _Return(expr.evaluate(f));
}

/// `raise`, `raise test`
class RaiseStmt extends Stmt {
  final Expr expr;
  const RaiseStmt(this.expr);

  @override
  dynamic evaluate(Frame f) => throw _Raise(expr.evaluate(f));
}

class ExprStmt extends Stmt {
  final Expr expr;
  const ExprStmt(this.expr);

  @override
  dynamic evaluate(Frame f) => expr.evaluate(f);
}

/// `target = test, ...`
class AssignStmt extends Stmt {
  final Expr lhs, rhs;
  const AssignStmt(this.lhs, this.rhs);

  @override
  dynamic evaluate(Frame f) => lhs.assign(f, rhs.evaluate(f));
}

// -------- Expr --------

abstract class Expr {
  const Expr();

  /// Returns the result of the evaluation of this node in the context of [f].
  dynamic evaluate(Frame f);

  dynamic assign(Frame f, dynamic value) => throw "SyntaxError: can't assign";

  /// Returns whether [assign] can be called on this node.
  bool get assignable => false;
}

/// _expr_ `if` _test_ `else` _test_
class CondExpr extends Expr {
  final Expr test, thenExpr, elseExpr;
  const CondExpr(this.test, this.thenExpr, this.elseExpr);

  @override
  dynamic evaluate(Frame f) {
    return (test.evaluate(f) ? thenExpr : elseExpr).evaluate(f);
  }
}

/// expr `or` expr
class OrExpr extends Expr {
  final Expr left, right;
  const OrExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) || right.evaluate(f);
  }
}

/// expr `and` expr
class AndExpr extends Expr {
  final Expr left, right;
  const AndExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) && right.evaluate(f);
  }
}

/// `not expr`
class NotExpr extends Expr {
  final Expr expr;
  const NotExpr(this.expr);

  @override
  dynamic evaluate(Frame f) => !expr.evaluate(f);
}

/// `expr == expr`
class EqExpr extends Expr {
  final Expr left, right;
  const EqExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) == right.evaluate(f);
  }
}

/// `expr >= expr`
class GeExpr extends Expr {
  final Expr left, right;
  const GeExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) >= right.evaluate(f);
  }
}

/// `expr > expr`
class GtExpr extends Expr {
  final Expr left, right;
  const GtExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) > right.evaluate(f);
  }
}

/// `expr <= expr`
class LeExpr extends Expr {
  final Expr left, right;
  const LeExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) <= right.evaluate(f);
  }
}

/// `expr < expr`
class LtExpr extends Expr {
  final Expr left, right;
  const LtExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) < right.evaluate(f);
  }
}

/// `expr != expr`
class NeExpr extends Expr {
  final Expr left, right;
  const NeExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) != right.evaluate(f);
  }
}

/// `expr in expr`
class InExpr extends Expr {
  final Expr left, right;
  const InExpr(this.left, this.right);

  dynamic evaluate(Frame f) => throw "not implemented yet";
}

/// `expr is expr`
class IsExpr extends Expr {
  final Expr left, right;
  const IsExpr(this.left, this.right);

  dynamic evaluate(Frame f) => throw "not implemented yet";
}

/// `expr + expr`
class AddExpr extends Expr {
  final Expr left, right;
  const AddExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) + right.evaluate(f);
  }
}

/// `expr - expr`
class SubExpr extends Expr {
  final Expr left, right;
  const SubExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) - right.evaluate(f);
  }
}

/// `expr * expr`
class MulExpr extends Expr {
  final Expr left, right;
  const MulExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) * right.evaluate(f);
  }
}

/// `expr / expr`
class DivExpr extends Expr {
  final Expr left, right;
  const DivExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) / right.evaluate(f);
  }
}

/// `expr % expr`
class ModExpr extends Expr {
  final Expr left, right;
  const ModExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    return left.evaluate(f) % right.evaluate(f);
  }
}

/// `+expr`
class PosExpr extends Expr {
  final Expr expr;
  const PosExpr(this.expr);

  @override
  dynamic evaluate(Frame f) => expr.evaluate(f);
}

/// `-expr`
class NegExpr extends Expr {
  final Expr expr;
  const NegExpr(this.expr);

  @override
  dynamic evaluate(Frame f) => -expr.evaluate(f);
}

/// `expr(args, ...)`
class CallExpr extends Expr {
  final Expr expr;
  final List<Expr> args;
  const CallExpr(this.expr, this.args);

  dynamic evaluate(Frame f) {
    return expr.evaluate(f).call(f, args.map<dynamic>((arg) => arg.evaluate(f)).toList());
  }
}

/// `expr[expr]`
class IndexExpr extends Expr {
  final Expr left, right;
  const IndexExpr(this.left, this.right);

  @override
  dynamic evaluate(Frame f) {
    final value = left.evaluate(f);
    final index = right.evaluate(f);
    final length = value.length;
    if (index is int) {
      int i = index;
      if (i < 0) i += length;
      if (i < 0 || i >= length) throw 'IndexError: index out of range';
      return value[i];
    }
    int i = index[0] ?? 0;
    int j = index[1] ?? length;
    if (index[2] != null) throw 'slicing with step not yet implemented';
    if (i < 0) i += length;
    if (i < 0) i = 0;
    if (i > length) i = length;
    if (j < 0) j += length;
    if (j < 0) j = 0;
    if (j > length) j = length;
    if (value is String) {
      if (i >= j) return '';
      return value.substring(i, j);
    }
    if (value is Tuple) {
      if (i >= j) return Tuple([]);
      return Tuple(value.skip(i).take(j - i).toList());
    }
    if (i >= j) return [];
    return value.skip(i).take(j - i).toList();
  }

  @override
  assign(Frame f, value) => throw "not implemented yet";

  @override
  bool get assignable => true;
}

/// `expr.NAME`
class AttrExpr extends Expr {
  final Expr expr;
  final String name;
  const AttrExpr(this.expr, this.name);

  @override
  evaluate(Frame f) => throw "not implemented yet";

  @override
  assign(Frame f, value) => throw "not implemented yet";

  @override
  bool get assignable => true;
}

/// `NAME`
class VarExpr extends Expr {
  final String name;
  const VarExpr(this.name);

  @override
  dynamic evaluate(Frame f) => f.lookup(name);

  @override
  assign(Frame f, value) => f.locals[name] = value;

  @override
  bool get assignable => true;
}

/// `None`, `True`, `False`, `NUMBER`, `STRING`
class LitExpr extends Expr {
  final dynamic value;
  const LitExpr(this.value);

  @override
  dynamic evaluate(Frame f) => value;
}

/// `()`, `(expr,)`, `(expr, ...)`
class TupleExpr extends Expr {
  final List<Expr> exprs;
  const TupleExpr(this.exprs);

  @override
  dynamic evaluate(Frame f) {
    return Tuple(List.unmodifiable(exprs.map((e) => e.evaluate(f))));
  }

  @override
  dynamic assign(Frame f, dynamic value) {
    final i = (value as Iterable).iterator;
    for (final e in exprs) {
      if (!i.moveNext()) throw "ValueError: not enough values to unpack";
      e.assign(f, i.current);
    }
    if (i.moveNext()) throw "ValueError: too many values to unpack";
    return value;
  }

  @override
  bool get assignable => true;
}

/// `[]`, `[expr, ...]`
class ListExpr extends Expr {
  final List<Expr> exprs;
  const ListExpr(this.exprs);

  @override
  dynamic evaluate(Frame f) => throw "not yet implemented";
}

/// `{}`, `{expr: expr, ...}`
class DictExpr extends Expr {
  final List<Expr> exprs;
  const DictExpr(this.exprs);

  @override
  dynamic evaluate(Frame f) => throw "not yet implemented";
}

/// `{expr, ...}`
class SetExpr extends Expr {
  final List<Expr> exprs;
  const SetExpr(this.exprs);

  @override
  dynamic evaluate(Frame f) => throw "not yet implemented";
}

// -------- Runtime --------

class Frame {
  final Frame parent;
  final Map<String, dynamic> locals;
  final Map<String, dynamic> globals;

  Frame(this.parent, this.locals, this.globals);

  dynamic lookup(String name) {
    if (locals.containsKey(name)) {
      return locals[name];
    }
    if (parent != null) {
      return parent.lookup(name);
    }
    if (globals.containsKey(name)) {
      return globals[name];
    }
    throw "NameError: name '$name' is not defined";
  }
}

class _Break {}

class _Return {
  final dynamic value;
  _Return(this.value);
}

class _Raise {
  final dynamic value;
  _Raise(this.value);
}

// -------- Runtime values --------

class SmClass {
  final String name;
  final SmClass superclass;
  final Map<String, dynamic> methods = {};

  SmClass(this.name, this.superclass);
}

class _Func {
  final Frame df;
  final List<String> params;
  final List<Expr> defExprs;
  final Suite suite;

  _Func(this.df, this.params, this.defExprs, this.suite);

  dynamic call(Frame cf, List<dynamic> args) {
    final f = Frame(df, {}, df.globals);
    int j = 0;
    for (int i = 0; i < params.length; i++) {
      f.locals[params[i]] = i < args.length ? args[i] : defExprs[j++].evaluate(df);
    }
    return suite.evaluate(f);
  }
}

class Tuple with IterableMixin {
  final List<dynamic> _elements;

  Tuple(this._elements);

  @override
  Iterator get iterator => _elements.iterator;

  @override
  String toString() => '(${_elements.map((e) => '$e').join(', ')})';
}
