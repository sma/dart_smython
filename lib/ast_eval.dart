/// AST nodes represent a Smython program and can be evaluated.
///
/// A [Suite] is a sequential list of statements.
/// [Stmt] is the abstract superclass for all statements.
/// [Expr] is the abstract superclass for all expressions.
///
/// All nodes have a `evaluate(Frame)` method.
/// Some expressions also support `assign(Frame,SmyValue)`.
library ast_eval;

import 'package:smython/smython.dart';

// -------- Suite --------

/// A suite of [Stmt]s.
class Suite {
  const Suite(this.stmts);
  final List<Stmt> stmts;

  SmyValue evaluate(Frame f) {
    SmyValue result = SmyValue.none;
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

/// A statement that can be executed.
abstract class Stmt {
  const Stmt();

  SmyValue evaluate(Frame f);
}

/// `if test: thenSuite else: elseSuite`
class IfStmt extends Stmt {
  const IfStmt(this.test, this.thenSuite, this.elseSuite);
  final Expr test;
  final Suite thenSuite;
  final Suite elseSuite;

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
  const WhileStmt(this.test, this.suite, this.elseSuite);
  final Expr test;
  final Suite suite;
  final Suite elseSuite;

  @override
  SmyValue evaluate(Frame f) {
    while (test.evaluate(f).boolValue) {
      try {
        suite.evaluate(f);
      } on _Break {
        return SmyValue.none;
      } on _Continue {
        continue;
      }
    }
    return elseSuite.evaluate(f);
  }
}

/// `for target, ... in test, ...: suite else: suite`
class ForStmt extends Stmt {
  const ForStmt(this.target, this.items, this.suite, this.elseSuite);
  final Expr target;
  final Expr items;
  final Suite suite;
  final Suite elseSuite;

  @override
  SmyValue evaluate(Frame f) {
    final i = items.evaluate(f).iterable;
    for (final value in i) {
      target.assign(f, value);
      try {
        suite.evaluate(f);
      } on _Break {
        return SmyValue.none;
      } on _Continue {
        continue;
      }
    }
    return elseSuite.evaluate(f);
  }
}

/// `try: suite finally: suite`
class TryFinallyStmt extends Stmt {
  const TryFinallyStmt(this.suite, this.finallySuite);
  final Suite suite, finallySuite;

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
  const TryExceptStmt(this.trySuite, this.excepts, this.elseSuite);
  final Suite trySuite, elseSuite;
  final List<ExceptClause> excepts;

  @override
  SmyValue evaluate(Frame f) {
    try {
      trySuite.evaluate(f);
      elseSuite.evaluate(f);
    } on _Raise catch (e) {
      final ex = e.value;
      for (final except in excepts) {
        // TODO search for the right clause
        var ff = f;
        if (except.name != null) {
          ff = Frame(f, {SmyString(except.name!): ex}, f.globals, f.builtins);
        }
        except.suite.evaluate(ff);
      }
    }
    return SmyValue.none;
  }
}

/// `except test as name: suite` (part of [TryExceptStmt])
class ExceptClause {
  const ExceptClause(this.test, this.name, this.suite);
  final Expr? test;
  final String? name;
  final Suite suite;
}

/// `def name(param=def, ...): suite`
class DefStmt extends Stmt {
  const DefStmt(this.name, this.params, this.defs, this.suite);
  final String name;
  final List<String> params;
  final List<Expr> defs;
  final Suite suite;

  @override
  SmyValue evaluate(Frame f) {
    final n = SmyString.intern(name);
    return f.locals[n] = SmyFunc(f, n, params, defs, suite);
  }
}

/// `class name (super): suite`
class ClassStmt extends Stmt {
  const ClassStmt(this.name, this.superExpr, this.suite);
  final String name;
  final Expr superExpr;
  final Suite suite;

  @override
  SmyValue evaluate(Frame f) {
    final superclass = superExpr.evaluate(f);
    if (superclass != SmyValue.none && !(superclass is SmyClass)) {
      throw 'TypeError: superclass is not a class';
    }
    final n = SmyString.intern(name);
    final cls = SmyClass(n, superclass != SmyValue.none ? superclass as SmyClass : null);
    f.locals[n] = cls;
    suite.evaluate(Frame(f, cls.methods, f.globals, f.builtins));
    return SmyValue.none;
  }
}

/// `pass`
class PassStmt extends Stmt {
  const PassStmt();

  @override
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

/// `continue`
class ContinueStmt extends Stmt {
  const ContinueStmt();

  @override
  SmyValue evaluate(Frame f) => throw _Continue();
}

/// `return`, `return test, ...`
class ReturnStmt extends Stmt {
  const ReturnStmt(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => throw _Return(expr.evaluate(f));
}

/// `raise`, `raise test`
class RaiseStmt extends Stmt {
  const RaiseStmt(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => throw _Raise(expr.evaluate(f));
}

/// `import NAME, ...`
class ImportNameStmt extends Stmt {
  const ImportNameStmt(this.names);
  final List<List<String>> names;

  @override
  SmyValue evaluate(Frame f) => throw UnimplementedError();
}

/// `from NAME import NAME, ...`
class FromImportStmt extends Stmt {
  const FromImportStmt(this.module, this.names);
  final String module;
  final List<List<String>> names;

  @override
  SmyValue evaluate(Frame f) => throw UnimplementedError();
}

/// `global NAME, ...`
class GlobalStmt extends Stmt {
  const GlobalStmt(this.names);
  final List<String> names;

  @override
  SmyValue evaluate(Frame f) => throw UnimplementedError();
}

/// `assert test`, `assert test, test`
class AssertStmt extends Stmt {
  const AssertStmt(this.expr, this.message);
  final Expr expr;
  final Expr? message;

  @override
  SmyValue evaluate(Frame f) {
    if (!expr.evaluate(f).boolValue) {
      final m = message?.evaluate(f).stringValue;
      throw make(m == null ? 'AssertionError' : 'AssertionError: $m');
    }
    return SmyValue.none;
  }
}

/// `expr`
class ExprStmt extends Stmt {
  const ExprStmt(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => expr.evaluate(f);
}

/// `target = test, ...`
class AssignStmt extends Stmt {
  const AssignStmt(this.lhs, this.rhs);
  final Expr lhs, rhs;

  @override
  SmyValue evaluate(Frame f) => lhs.assign(f, rhs.evaluate(f));
}

abstract class AugAssignStmt extends Stmt {
  const AugAssignStmt(this.lhs, this.rhs, this.op);
  final Expr lhs, rhs;
  final SmyValue Function(SmyValue, SmyValue) op;

  @override
  SmyValue evaluate(Frame f) => lhs.assign(f, op(lhs.evaluate(f), rhs.evaluate(f)));
}

/// `target += test`
class AddAssignStmt extends AugAssignStmt {
  const AddAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.add);
}

/// `target -= test`
class SubAssignStmt extends AugAssignStmt {
  const SubAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.sub);
}

/// `target *= test`
class MulAssignStmt extends AugAssignStmt {
  const MulAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.mul);
}

/// `target /= test`
class DivAssignStmt extends AugAssignStmt {
  const DivAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.div);
}

/// `target %= test, ...`
class ModAssignStmt extends AugAssignStmt {
  const ModAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.mod);
}

/// `target |= test`
class OrAssignStmt extends AugAssignStmt {
  const OrAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.or);
}

/// `target &= test`
class AndAssignStmt extends AugAssignStmt {
  const AndAssignStmt(Expr lhs, Expr rhs) : super(lhs, rhs, Expr.and);
}

// -------- Expr --------

/// An expression can be evaluated.
/// It might be [assignable] in which case it can be [assign]ed to.
abstract class Expr {
  const Expr();

  /// Returns the result of the evaluation of this node in the context of [f].
  SmyValue evaluate(Frame f);

  SmyValue assign(Frame f, SmyValue value) => throw "SyntaxError: can't assign";

  /// Returns whether [assign] can be called on this node.
  bool get assignable => false;

  // default arithmetic & bit operations
  static SmyValue add(SmyValue l, SmyValue r) => SmyNum(l.numValue + r.numValue);
  static SmyValue sub(SmyValue l, SmyValue r) => SmyNum(l.numValue - r.numValue);
  static SmyValue mul(SmyValue l, SmyValue r) => SmyNum(l.numValue * r.numValue);
  static SmyValue div(SmyValue l, SmyValue r) => SmyNum(l.numValue / r.numValue);
  static SmyValue mod(SmyValue l, SmyValue r) => SmyNum(l.numValue % r.numValue);
  static SmyValue or(SmyValue l, SmyValue r) => SmyNum(l.intValue | r.intValue);
  static SmyValue and(SmyValue l, SmyValue r) => SmyNum(l.intValue & r.intValue);
}

/// _expr_ `if` _test_ `else` _test_
class CondExpr extends Expr {
  const CondExpr(this.test, this.thenExpr, this.elseExpr);
  final Expr test, thenExpr, elseExpr;

  @override
  SmyValue evaluate(Frame f) {
    return (test.evaluate(f).boolValue ? thenExpr : elseExpr).evaluate(f);
  }
}

/// expr `or` expr
class OrExpr extends Expr {
  const OrExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).boolValue || right.evaluate(f).boolValue);
  }
}

/// expr `and` expr
class AndExpr extends Expr {
  const AndExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).boolValue && right.evaluate(f).boolValue);
  }
}

/// `not expr`
class NotExpr extends Expr {
  const NotExpr(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => SmyBool(!expr.evaluate(f).boolValue);
}

/// `expr == expr`
class EqExpr extends Expr {
  const EqExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f) == right.evaluate(f));
  }
}

/// `expr >= expr`
class GeExpr extends Expr {
  const GeExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).numValue >= right.evaluate(f).numValue);
  }
}

/// `expr > expr`
class GtExpr extends Expr {
  const GtExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).numValue > right.evaluate(f).numValue);
  }
}

/// `expr <= expr`
class LeExpr extends Expr {
  const LeExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).numValue <= right.evaluate(f).numValue);
  }
}

/// `expr < expr`
class LtExpr extends Expr {
  const LtExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f).numValue < right.evaluate(f).numValue);
  }
}

/// `expr != expr`
class NeExpr extends Expr {
  const NeExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return SmyBool(left.evaluate(f) != right.evaluate(f));
  }
}

/// `expr in expr`
class InExpr extends Expr {
  const InExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) => throw 'in not implemented yet';
}

/// `expr is expr`
class IsExpr extends Expr {
  const IsExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) => throw 'is not implemented yet';
}

/// `expr | expr`
class BitOrExpr extends Expr {
  const BitOrExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.or(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr & expr`
class BitAndExpr extends Expr {
  const BitAndExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.and(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr + expr`
class AddExpr extends Expr {
  const AddExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.add(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr - expr`
class SubExpr extends Expr {
  const SubExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.sub(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr * expr`
class MulExpr extends Expr {
  const MulExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.mul(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr / expr`
class DivExpr extends Expr {
  const DivExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.div(left.evaluate(f), right.evaluate(f));
  }
}

/// `expr % expr`
class ModExpr extends Expr {
  const ModExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    return Expr.mod(left.evaluate(f), right.evaluate(f));
  }
}

/// `+expr`
class PosExpr extends Expr {
  const PosExpr(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => expr.evaluate(f);
}

/// `-expr`
class NegExpr extends Expr {
  const NegExpr(this.expr);
  final Expr expr;

  @override
  SmyValue evaluate(Frame f) => SmyNum(-expr.evaluate(f).numValue);
}

/// `expr(args, ...)`
class CallExpr extends Expr {
  const CallExpr(this.expr, this.args);
  final Expr expr;
  final List<Expr> args;

  @override
  SmyValue evaluate(Frame f) {
    return expr.evaluate(f).call(f, args.map<SmyValue>((arg) => arg.evaluate(f)).toList());
  }
}

/// `expr[expr]`
class IndexExpr extends Expr {
  const IndexExpr(this.left, this.right);
  final Expr left, right;

  @override
  SmyValue evaluate(Frame f) {
    final value = left.evaluate(f);
    final index = right.evaluate(f);
    final length = value.length;
    if (value is SmyDict) {
      return value.values[index] ?? SmyValue.none;
    }
    if (index is SmyNum) {
      var i = index.index;
      if (i < 0) i += length;
      if (i < 0 || i >= length) throw 'IndexError: index out of range';
      if (value is SmyString) {
        return SmyString(value.value[i]);
      }
      return value.iterable.skip(i).first;
    }
    final slice = (index as SmyTuple).values;
    var i = slice[0] != SmyValue.none ? slice[0].index : 0;
    var j = slice[1] != SmyValue.none ? slice[1].index : length;
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
  SmyValue assign(Frame f, value) => throw '[]= not implemented yet';

  @override
  bool get assignable => true;
}

/// `expr.NAME`
class AttrExpr extends Expr {
  const AttrExpr(this.expr, this.name);
  final Expr expr;
  final String name;

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
  const VarExpr(this.name);
  final SmyString name;

  @override
  SmyValue evaluate(Frame f) => f.lookup(name);

  @override
  SmyValue assign(Frame f, value) => f.locals[name] = value;

  @override
  bool get assignable => true;
}

/// `None`, `True`, `False`, `NUMBER`, `STRING`
class LitExpr extends Expr {
  const LitExpr(this.value);
  final SmyValue value;

  @override
  SmyValue evaluate(Frame f) => value;
}

/// `()`, `(expr,)`, `(expr, ...)`
class TupleExpr extends Expr {
  const TupleExpr(this.exprs);
  final List<Expr> exprs;

  @override
  SmyValue evaluate(Frame f) {
    return SmyTuple(exprs.map((e) => e.evaluate(f)).toList());
  }

  @override
  SmyValue assign(Frame f, SmyValue value) {
    final i = value.iterable.iterator;
    for (final e in exprs) {
      if (!i.moveNext()) throw 'ValueError: not enough values to unpack';
      e.assign(f, i.current);
    }
    if (i.moveNext()) throw 'ValueError: too many values to unpack';
    return value;
  }

  @override
  bool get assignable => true;
}

/// `[]`, `[expr, ...]`
class ListExpr extends Expr {
  const ListExpr(this.exprs);
  final List<Expr> exprs;

  @override
  SmyValue evaluate(Frame f) {
    if (exprs.isEmpty) return SmyList([]);
    return SmyList(exprs.map((e) => e.evaluate(f)).toList());
  }
}

/// `{}`, `{expr: expr, ...}`
class DictExpr extends Expr {
  const DictExpr(this.exprs);
  final List<Expr> exprs;

  @override
  SmyValue evaluate(Frame f) {
    final dict = <SmyValue, SmyValue>{};
    for (var i = 0; i < exprs.length; i += 2) {
      dict[exprs[i].evaluate(f)] = exprs[i + 1].evaluate(f);
    }
    return SmyDict(dict);
  }
}

/// `{expr, ...}`
class SetExpr extends Expr {
  const SetExpr(this.exprs);
  final List<Expr> exprs;

  @override
  SmyValue evaluate(Frame f) => throw 'set not yet implemented';
}

/// Implements breaking loops.
class _Break {}

/// Implements continuing loops.
class _Continue {}

/// Implements returning from functions.
class _Return {
  _Return(this.value);
  final SmyValue value;
}

/// Implements raising exceptions.
class _Raise {
  _Raise(this.value);
  final SmyValue value;
}
