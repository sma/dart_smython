import 'package:smython/smython.dart';

// -------- Suite --------

class Suite {
  final List<Stmt> stmts;
  const Suite(this.stmts);

  SmyValue evaluate(Frame f) {
    var result = SmyValue.none;
    for (final stmt in stmts) {
      result = stmt.evaluate(f);
    }
    return result;
  }

  SmyValue evaluateAsFunc(Frame f) {
    try {
      return evaluate(f);
    } on _Return catch (e) {
      return e.value;
    }
  }
}

// -------- Stmt --------

abstract class Stmt {
  const Stmt();

  SmyValue evaluate(Frame f);
}

/// `if test: thenSuite else: elseSuite`
class IfStmt extends Stmt {
  final Expr test;
  final Suite thenSuite;
  final Suite elseSuite;
  const IfStmt(this.test, this.thenSuite, this.elseSuite);

  @override
  SmyValue evaluate(Frame f) {
    if (test.evaluate(f).boolValue) {
      thenSuite.evaluate(f);
    } else {
      elseSuite.evaluate(f);
    }
    return SmyValue.none;
  }
}

/// `while test: suite else: elseSuite`
class WhileStmt extends Stmt {
  final Expr test;
  final Suite suite;
  final Suite elseSuite;
  const WhileStmt(this.test, this.suite, this.elseSuite);

  @override
  SmyValue evaluate(Frame f) {
    while (test.evaluate(f).boolValue) {
      try {
        suite.evaluate(f);
      } on _Break {
        return SmyValue.none;
      }
    }
    return elseSuite.evaluate(f);
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
  SmyValue evaluate(Frame f) {
    final i = items.evaluate(f).iterable;
    for (final value in i) {
      target.assign(f, value);
      try {
        suite.evaluate(f);
      } on _Break {
        return SmyValue.none;
      }
    }
    return elseSuite.evaluate(f);
  }
}

/// `try: suite finally: suite`
class TryFinallyStmt extends Stmt {
  final Suite suite, finallySuite;
  const TryFinallyStmt(this.suite, this.finallySuite);

  @override
  SmyValue evaluate(Frame f) {
    try {
      suite.evaluate(f);
    } finally {
      finallySuite.evaluate(f);
    }
    return SmyValue.none;
  }
}

/// `try: suite except test as name: suite else: suite`
class TryExceptStmt extends Stmt {
  final Suite trySuite, elseSuite;
  final List<ExceptClause> excepts;
  const TryExceptStmt(this.trySuite, this.excepts, this.elseSuite);

  @override
  SmyValue evaluate(Frame f) {
    try {
      trySuite.evaluate(f);
      elseSuite.evaluate(f);
    } on _Raise catch (e) {
      final ex = e.value;
      for (final except in excepts) {
        // TODO search for the right clause
        Frame ff = f;
        if (except.name != null) {
          ff = Frame(f, {SmyString(except.name): ex}, f.globals, f.builtins);
        }
        except.suite.evaluate(ff);
      }
    }
    return SmyValue.none;
  }
}

class ExceptClause {
  final Expr test;
  final String name;
  final Suite suite;
  const ExceptClause(this.test, this.name, this.suite);
}

/// `def name(param, ...): suite`
class DefStmt extends Stmt {
  final String name;
  final List<String> params;
  final List<Expr> defs;
  final Suite suite;
  const DefStmt(this.name, this.params, this.defs, this.suite);

  @override
  SmyValue evaluate(Frame f) {
    final n = SmyString.intern(name);
    return f.locals[n] = SmyFunc(f, n, params, defs, suite);
  }
}

/// `class name (super): suite`
class ClassStmt extends Stmt {
  final String name;
  final Expr superExpr;
  final Suite suite;
  const ClassStmt(this.name, this.superExpr, this.suite);

  @override
  SmyValue evaluate(Frame f) {
    final superclass = superExpr.evaluate(f);
    if (superclass != SmyValue.none && !(superclass is SmyClass)) {
      throw 'TypeError: superclass is not a class';
    }
    final n = SmyString.intern(name);
    final cls = SmyClass(n, superclass != SmyValue.none ? superclass : null);
    f.locals[n] = cls;
    suite.evaluate(Frame(f, cls.methods, f.globals, f.builtins));
    return SmyValue.none;
  }
}

/// `pass`
class PassStmt extends Stmt {
  const PassStmt();

  SmyValue evaluate(Frame f) {
    return SmyValue.none;
  }
}

/// `break`
class BreakStmt extends Stmt {
  const BreakStmt();

  @override
  SmyValue evaluate(Frame f) => throw _Break();
}

/// `return`, `return test, ...`
class ReturnStmt extends Stmt {
  final Expr expr;
  const ReturnStmt(this.expr);

  @override
  SmyValue evaluate(Frame f) => throw _Return(expr.evaluate(f));
}

/// `raise`, `raise test`
class RaiseStmt extends Stmt {
  final Expr expr;
  const RaiseStmt(this.expr);

  @override
  SmyValue evaluate(Frame f) => throw _Raise(expr.evaluate(f));
}

class ExprStmt extends Stmt {
  final Expr expr;
  const ExprStmt(this.expr);

  @override
  SmyValue evaluate(Frame f) => expr.evaluate(f);
}

/// `target = test, ...`
class AssignStmt extends Stmt {
  final Expr lhs, rhs;
  const AssignStmt(this.lhs, this.rhs);

  @override
  SmyValue evaluate(Frame f) => lhs.assign(f, rhs.evaluate(f));
}

// -------- Expr --------

abstract class Expr {
  const Expr();

  /// Returns the result of the evaluation of this node in the context of [f].
  SmyValue evaluate(Frame f);

  SmyValue assign(Frame f, SmyValue value) => throw "SyntaxError: can't assign";

  /// Returns whether [assign] can be called on this node.
  bool get assignable => false;
}

/// _expr_ `if` _test_ `else` _test_
class CondExpr extends Expr {
  final Expr test, thenExpr, elseExpr;
  const CondExpr(this.test, this.thenExpr, this.elseExpr);

  @override
  SmyValue evaluate(Frame f) {
    return (test.evaluate(f).boolValue ? thenExpr : elseExpr).evaluate(f);
  }
}

/// expr `or` expr
class OrExpr extends Expr {
  final Expr left, right;
  const OrExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).boolValue || right.evaluate(f).boolValue);
  }
}

/// expr `and` expr
class AndExpr extends Expr {
  final Expr left, right;
  const AndExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).boolValue && right.evaluate(f).boolValue);
  }
}

/// `not expr`
class NotExpr extends Expr {
  final Expr expr;
  const NotExpr(this.expr);

  @override
  SmyValue evaluate(Frame f) => SmyBool(!expr.evaluate(f).boolValue);
}

/// `expr == expr`
class EqExpr extends Expr {
  final Expr left, right;
  const EqExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f) == right.evaluate(f));
  }
}

/// `expr >= expr`
class GeExpr extends Expr {
  final Expr left, right;
  const GeExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).intValue >= right.evaluate(f).intValue);
  }
}

/// `expr > expr`
class GtExpr extends Expr {
  final Expr left, right;
  const GtExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).intValue > right.evaluate(f).intValue);
  }
}

/// `expr <= expr`
class LeExpr extends Expr {
  final Expr left, right;
  const LeExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).intValue <= right.evaluate(f).intValue);
  }
}

/// `expr < expr`
class LtExpr extends Expr {
  final Expr left, right;
  const LtExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).intValue < right.evaluate(f).intValue);
  }
}

/// `expr != expr`
class NeExpr extends Expr {
  final Expr left, right;
  const NeExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f) != right.evaluate(f));
  }
}

/// `expr in expr`
class InExpr extends Expr {
  final Expr left, right;
  const InExpr(this.left, this.right);

  SmyValue evaluate(Frame f) => throw "in not implemented yet";
}

/// `expr is expr`
class IsExpr extends Expr {
  final Expr left, right;
  const IsExpr(this.left, this.right);

  SmyValue evaluate(Frame f) => throw "is not implemented yet";
}

/// `expr + expr`
class AddExpr extends Expr {
  final Expr left, right;
  const AddExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyInt(left.evaluate(f).intValue + right.evaluate(f).intValue);
  }
}

/// `expr - expr`
class SubExpr extends Expr {
  final Expr left, right;
  const SubExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyInt(left.evaluate(f).intValue - right.evaluate(f).intValue);
  }
}

/// `expr * expr`
class MulExpr extends Expr {
  final Expr left, right;
  const MulExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyInt(left.evaluate(f).intValue * right.evaluate(f).intValue);
  }
}

/// `expr / expr`
class DivExpr extends Expr {
  final Expr left, right;
  const DivExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyInt(left.evaluate(f).intValue ~/ right.evaluate(f).intValue);
  }
}

/// `expr % expr`
class ModExpr extends Expr {
  final Expr left, right;
  const ModExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    return SmyInt(left.evaluate(f).intValue % right.evaluate(f).intValue);
  }
}

/// `+expr`
class PosExpr extends Expr {
  final Expr expr;
  const PosExpr(this.expr);

  @override
  SmyValue evaluate(Frame f) => expr.evaluate(f);
}

/// `-expr`
class NegExpr extends Expr {
  final Expr expr;
  const NegExpr(this.expr);

  @override
  SmyValue evaluate(Frame f) => SmyInt(-expr.evaluate(f).intValue);
}

/// `expr(args, ...)`
class CallExpr extends Expr {
  final Expr expr;
  final List<Expr> args;
  const CallExpr(this.expr, this.args);

  SmyValue evaluate(Frame f) {
    return expr.evaluate(f).call(f, args.map<SmyValue>((arg) => arg.evaluate(f)).toList());
  }
}

/// `expr[expr]`
class IndexExpr extends Expr {
  final Expr left, right;
  const IndexExpr(this.left, this.right);

  @override
  SmyValue evaluate(Frame f) {
    final value = left.evaluate(f);
    final index = right.evaluate(f);
    final length = value.length;
    if (value is SmyDict) {
      return value.values[index] ?? SmyValue.none;
    }
    if (index is SmyInt) {
      int i = index.intValue;
      if (i < 0) i += length;
      if (i < 0 || i >= length) throw 'IndexError: index out of range';
      if (value is SmyString) {
        return SmyString(value.value[i]);
      }
      return value.iterable.skip(i).first;
    }
    final slice = (index as SmyTuple).values;
    int i = slice[0] != SmyValue.none ? slice[0].intValue : 0;
    int j = slice[1] != SmyValue.none ? slice[1].intValue : length;
    if (slice[2] != SmyValue.none) throw 'slicing with step not yet implemented';
    if (i < 0) i += length;
    if (i < 0) i = 0;
    if (i > length) i = length;
    if (j < 0) j += length;
    if (j < 0) j = 0;
    if (j > length) j = length;
    if (value is SmyString) {
      if (i >= j) return const SmyString('');
      return SmyString(value.value.substring(i, j));
    }
    if (value is SmyTuple) {
      if (i >= j) return const SmyTuple([]);
      return SmyTuple(value.iterable.skip(i).take(j - i).toList());
    }
    if (i >= j) return const SmyList([]);
    return SmyList(value.iterable.skip(i).take(j - i).toList());
  }

  @override
  SmyValue assign(Frame f, value) => throw "[]= not implemented yet";

  @override
  bool get assignable => true;
}

/// `expr.NAME`
class AttrExpr extends Expr {
  final Expr expr;
  final String name;
  const AttrExpr(this.expr, this.name);

  @override
  SmyValue evaluate(Frame f) {
    return expr.evaluate(f).getAttr(name);
  }

  @override
  SmyValue assign(Frame f, value) {
    return expr.evaluate(f).setAttr(name, value);
  }

  @override
  bool get assignable => true;
}

/// `NAME`
class VarExpr extends Expr {
  final SmyString name;
  const VarExpr(this.name);

  @override
  SmyValue evaluate(Frame f) => f.lookup(name);

  @override
  assign(Frame f, value) => f.locals[name] = value;

  @override
  bool get assignable => true;
}

/// `None`, `True`, `False`, `NUMBER`, `STRING`
class LitExpr extends Expr {
  final SmyValue value;
  const LitExpr(this.value);

  @override
  SmyValue evaluate(Frame f) => value;
}

/// `()`, `(expr,)`, `(expr, ...)`
class TupleExpr extends Expr {
  final List<Expr> exprs;
  const TupleExpr(this.exprs);

  @override
  SmyValue evaluate(Frame f) {
    return SmyTuple(exprs.map((e) => e.evaluate(f)).toList());
  }

  @override
  SmyValue assign(Frame f, SmyValue value) {
    final i = value.iterable.iterator;
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
  SmyValue evaluate(Frame f) {
    if (exprs.isEmpty) return SmyList([]);
    return SmyList(exprs.map((e) => e.evaluate(f)).toList());
  }
}

/// `{}`, `{expr: expr, ...}`
class DictExpr extends Expr {
  final List<Expr> exprs;
  const DictExpr(this.exprs);

  @override
  SmyValue evaluate(Frame f) {
    Map<SmyValue, SmyValue> dict = {};
    for (int i = 0; i < exprs.length; i += 2) {
      dict[exprs[i].evaluate(f)] = exprs[i + 1].evaluate(f);
    }
    return SmyDict(dict);
  }
}

/// `{expr, ...}`
class SetExpr extends Expr {
  final List<Expr> exprs;
  const SetExpr(this.exprs);

  @override
  SmyValue evaluate(Frame f) => throw "set not yet implemented";
}

class _Break {}

class _Return {
  final SmyValue value;
  _Return(this.value);
}

class _Raise {
  final SmyValue value;
  _Raise(this.value);
}
