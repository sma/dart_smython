// ---- AST ----

class Suite {
  final List<Stmt> stmts;
  const Suite(this.stmts);

  void execute(Frame f) {
    for (var stmt in stmts) stmt.execute(f);
  }
}

abstract class Stmt {
  const Stmt();

  void execute(Frame f);
}

class PassStmt extends Stmt {
  const PassStmt();

  void execute(Frame f) {}
}

class DefStmt extends Stmt {
  final String name;
  final List<String> params;
  final Suite suite;
  const DefStmt(this.name, this.params, this.suite);

  void execute(Frame f) {
    f.globals[name] = _Func(f, params, suite);
  }
}

class IfStmt extends Stmt {
  final Expr test;
  final Suite thenSuite;
  final Suite elseSuite;
  const IfStmt(this.test, this.thenSuite, this.elseSuite);

  void execute(Frame f) {
    if (test.evaluate(f) as bool) {
      thenSuite.execute(f);
    } else {
      elseSuite.execute(f);
    }
  }
}

class ReturnStmt extends Stmt {
  final Expr expr;
  const ReturnStmt(this.expr);

  void execute(Frame f) {
    throw _Return(expr.evaluate(f));
  }
}

class ExprStmt extends Stmt {
  final Expr expr;
  const ExprStmt(this.expr);

  void execute(Frame f) {
    expr.evaluate(f);
  }
}

abstract class Expr {
  const Expr();

  dynamic evaluate(Frame f);
}

class EqExpr extends Expr {
  final Expr left, right;
  const EqExpr(this.left, this.right);

  dynamic evaluate(Frame f) {
    return left.evaluate(f) == right.evaluate(f);
  }
}

class LeExpr extends Expr {
  final Expr left, right;
  const LeExpr(this.left, this.right);

  dynamic evaluate(Frame f) {
    return left.evaluate(f) <= right.evaluate(f);
  }
}

class AddExpr extends Expr {
  final Expr left, right;
  const AddExpr(this.left, this.right);

  dynamic evaluate(Frame f) {
    return left.evaluate(f) + right.evaluate(f);
  }
}

class SubExpr extends Expr {
  final Expr left, right;
  const SubExpr(this.left, this.right);

  dynamic evaluate(Frame f) {
    return left.evaluate(f) - right.evaluate(f);
  }
}

class MulExpr extends Expr {
  final Expr left, right;
  const MulExpr(this.left, this.right);

  dynamic evaluate(Frame f) {
    return left.evaluate(f) * right.evaluate(f);
  }
}

class VarExpr extends Expr {
  final String name;
  const VarExpr(this.name);

  dynamic evaluate(Frame f) {
    return f.lookup(name);
  }
}

class LitExpr extends Expr {
  final dynamic value;
  const LitExpr(this.value);

  dynamic evaluate(Frame f) {
    return value;
  }
}

class CallExpr extends Expr {
  final Expr expr;
  final List<Expr> args;
  const CallExpr(this.expr, this.args);

  dynamic evaluate(Frame f) {
    return expr.evaluate(f).call(f, args.map((arg) => arg.evaluate(f)).toList());
  }
}

// ---- Runtime ----

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
    throw ArgumentError("unbound variable $name");
  }
}

class _Return extends Error {
  final dynamic value;
  _Return(this.value);
}

class _Func {
  final Frame df;
  final List<String> params;
  final Suite suite;

  _Func(this.df, this.params, this.suite);

  dynamic call(Frame cf, List<dynamic> args) {
    final f = Frame(df, {}, df.globals);
    for (int i = 0; i < params.length; i++) {
      f.locals[params[i]] = args[i];
    }
    try {
      suite.execute(f);
    } on _Return catch (e) {
      return e.value;
    }
    return null;
  }
}
