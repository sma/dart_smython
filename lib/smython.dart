import 'ast_eval.dart';
import 'parser.dart';

/// Main entry point.
class Smython {
  final Map<SmyValue, SmyValue> builtins = {
    SmyString('print'): SmyBuiltin((Frame cf, List<SmyValue> args) {
      print(args.map((v) => '$v').join(' '));
      return SmyValue.none;
    }),
    SmyString('len'): SmyBuiltin((Frame cf, List<SmyValue> args) {
      return SmyInt(args[0].length);
    }),
  };

  final Map<SmyValue, SmyValue> globals = {};

  void execute(String source) {
    parse(source).evaluate(Frame(null, globals, globals, builtins));
  }
}

/// Everything is a Smython value.
abstract class SmyValue {
  const SmyValue();

  bool get boolValue => false;
  int get intValue => throw 'TypeError: Not an integer';
  SmyValue call(Frame f, List<SmyValue> args) => throw 'TypeError: Not callable';

  Iterable<SmyValue> get iterable => throw 'TypeError: Not iterable';
  int get length => iterable.length;

  SmyValue getAttr(String name) => throw "AttributeError: No attribute '$name'";
  SmyValue setAttr(String name, SmyValue value) => throw "AttributeError: No attribute '$name'";

  static const SmyValue none = SmyNone();
  static const SmyValue trueValue = SmyBool(true);
  static const SmyValue falseValue = SmyBool(false);
}

/// `None` (singleton, equatable, hashable)
class SmyNone extends SmyValue {
  const SmyNone();

  @override
  bool operator ==(dynamic other) => other is SmyNone;

  @override
  int get hashCode => 18736098234;

  @override
  String toString() => 'None';
}

/// `True` or `False` (singletons, equatable, hashable)
class SmyBool extends SmyValue {
  final bool value;
  const SmyBool(this.value);

  @override
  bool operator ==(dynamic other) => other is SmyBool && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value ? 'True' : 'False';

  @override
  bool get boolValue => value;
}

/// `NUMBER` (equatable, hashable)
class SmyInt extends SmyValue {
  final int value;
  const SmyInt(this.value);
  const SmyInt.fromBool(bool value) : value = value ? 1 : 0;

  @override
  bool operator ==(dynamic other) => other is SmyInt && value == other.value;

  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => '$value';

  @override
  bool get boolValue => value != 0;

  @override
  int get intValue => value;
}

/// `STRING` (equatable, hashable)
class SmyString extends SmyValue {
  final String value;
  const SmyString(this.value);

  @override
  bool operator ==(dynamic other) => other is SmyString && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  @override
  bool get boolValue => value.isNotEmpty;

  @override
  int get length => value.length;
}

/// `(expr, ...)`
class SmyTuple extends SmyValue {
  final List<SmyValue> values;
  const SmyTuple(this.values);

  @override
  String toString() {
    if (values.length == 0) return '()';
    if (values.length == 1) return '(${values[0]},)';
    return '(${values.map((v) => '$v').join(', ')})';
  }

  @override
  bool get boolValue => values.isNotEmpty;

  @override
  Iterable<SmyValue> get iterable => values;

  @override
  int get length => values.length;
}

/// `[expr, ...]`
class SmyList extends SmyValue {
  final List<SmyValue> values;
  const SmyList(this.values);

  @override
  String toString() {
    if (values.isEmpty) return '[]';
    return '[${values.map((v) => '$v').join(', ')}]';
  }

  @override
  bool get boolValue => values.isNotEmpty;

  @override
  Iterable<SmyValue> get iterable => values;

  @override
  int get length => values.length;
}

/// `{expr: expr, ...}`
class SmyDict extends SmyValue {
  final Map<SmyValue, SmyValue> values;
  const SmyDict(this.values);

  @override
  String toString() {
    if (values.isEmpty) return '{}';
    return '{${values.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
  }

  @override
  bool get boolValue => values.isNotEmpty;

  @override
  Iterable<SmyValue> get iterable => values.entries.map((e) => SmyTuple([e.key, e.value]));

  @override
  int get length => values.length;
}

/// `{expr, ...}`
class SmySet extends SmyValue {
  final Set<SmyValue> values;
  const SmySet(this.values);

  @override
  bool get boolValue => values.isNotEmpty;
}

/// `class name (super): ...`
class SmyClass extends SmyValue {
  final SmyString _name;
  final SmyClass _superclass;
  final SmyDict _dict = SmyDict({});

  SmyClass(this._name, this._superclass);

  Map<SmyValue, SmyValue> get methods => _dict.values;

  SmyValue findAttr(String name) {
    final n = SmyString(name);
    for (var cls = this; cls != null; cls = cls._superclass) {
      final value = cls._dict.values[n];
      if (value != null) return value;
    }
    return null;
  }

  @override
  String toString() => "<class '$_name'>";

  @override
  SmyValue call(Frame f, List<SmyValue> args) {
    final object = SmyObject(this);
    final init = findAttr("__init__");
    if (init is SmyFunc) {
      init.call(f, <SmyValue>[object] + args);
    }
    return object;
  }

  @override
  SmyValue getAttr(String name) {
    if (name == "__name__") return _name;
    if (name == "__superclass__") return _superclass ?? SmyValue.none;
    if (name == "__dict__") return _dict;
    return super.getAttr(name);
  }
}

class SmyObject extends SmyValue {
  final SmyClass _class;
  final SmyDict _dict = SmyDict({});

  SmyObject(this._class);

  @override
  String toString() => '<${_class._name} object $hashCode>';

  @override
  SmyValue getAttr(String name) {
    if (name == "__class__") return _class;
    if (name == "__dict__") return _dict;

    final value1 = _dict.values[SmyString(name)];
    if (value1 != null) return value1;

    final value = _class.findAttr(name);
    if (value != null) {
      if (value is SmyFunc) {
        return SmyMethod(this, value);
      }
      return value;
    }
    return super.getAttr(name);
  }

  @override
  SmyValue setAttr(String name, SmyValue value) {
    return _dict.values[SmyString(name)] = value;
  }
}

class SmyMethod extends SmyValue {
  final SmyObject self;
  final SmyFunc func;

  SmyMethod(this.self, this.func);

  @override
  SmyValue call(Frame f, List<SmyValue> args) {
    return func.call(f, <SmyValue>[self] + args);
  }
}

/// `def name(param, ...): ...`
class SmyFunc extends SmyValue {
  final Frame df;
  final List<String> params;
  final List<Expr> defExprs;
  final Suite suite;

  const SmyFunc(this.df, this.params, this.defExprs, this.suite);

  @override
  SmyValue call(Frame cf, List<SmyValue> args) {
    final f = Frame(df, {}, df.globals, df.builtins);
    int j = 0;
    for (int i = 0; i < params.length; i++) {
      f.locals[SmyString(params[i])] = i < args.length ? args[i] : defExprs[j++].evaluate(df);
    }
    return suite.evaluate(f);
  }
}

/// builtin function like print or len
class SmyBuiltin extends SmyValue {
  final SmyValue Function(Frame cf, List<SmyValue> args) func;
  SmyBuiltin(this.func);

  @override
  SmyValue call(Frame cf, List<SmyValue> args) => func(cf, args);
}

// -------- Runtime --------

class Frame {
  final Frame parent;
  final Map<SmyValue, SmyValue> locals;
  final Map<SmyValue, SmyValue> globals;
  final Map<SmyValue, SmyValue> builtins;

  Frame(this.parent, this.locals, this.globals, this.builtins);

  SmyValue lookup(SmyString name) {
    if (locals.containsKey(name)) {
      return locals[name];
    }
    if (parent != null) {
      return parent.lookup(name);
    }
    if (globals.containsKey(name)) {
      return globals[name];
    }
    if (builtins.containsKey(name)) {
      return builtins[name];
    }
    throw "NameError: name '$name' is not defined";
  }
}
