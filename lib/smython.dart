import 'ast_eval.dart';
import 'parser.dart';

/// Main entry point.
class Smython {
  final Map<SmyValue, SmyValue> builtins = {};
  final Map<SmyValue, SmyValue> globals = {};

  Smython() {
    builtin('print', (Frame cf, List<SmyValue> args) {
      print(args.map((v) => '$v').join(' '));
      return None;
    });
    builtin('len', (Frame cf, List<SmyValue> args) {
      if (args.length != 1) throw 'TypeError: len() takes 1 argument (${args.length} given)';
      return SmyInt(args[0].length);
    });
    builtin('slice', (Frame f, List<SmyValue> args) {
      if (args.length != 3) throw 'TypeError: slice() takes 3 arguments (${args.length} given)';
      return SmyTuple(args);
    });
    builtin('del', (Frame f, List<SmyValue> args) {
      if (args.length != 2) throw 'TypeError: del() takes 2 arguments (${args.length} given)';
      final value = args[0];
      final index = args[1];
      if (value is SmyList) {
        if (index is SmyInt) {
          return value.values.removeAt(index.value);
        }
        if (index is SmyTuple) {
          final length = value.values.length;
          var start = index.values[0].isNone ? 0 : index.values[0].intValue;
          var end = index.values[1].isNone ? value.values.length : index.values[1].intValue;
          if (start < 0) start += length;
          if (end < 0) end += length;
          if (start >= end) return None;
          value.values.removeRange(start, end);
          return None;
        }
        throw 'TypeError: invalid index';
      }
      if (value is SmyDict) {
        return value.values.remove(index) ?? SmyValue.none;
      }
      throw 'TypeError: Unsupported item deletion';
    });
  }

  void builtin(String name, SmyValue Function(Frame, List<SmyValue>) func) {
    final bname = SmyString.intern(name);
    builtins[bname] = SmyBuiltin(bname, func);
  }

  void execute(String source) {
    parse(source).evaluate(Frame(null, globals, globals, builtins));
  }
}

const None = SmyValue.none;

/// Returns the Smython value for a Dart [value].
SmyValue make(dynamic value) {
  if (value == null) return SmyNone();
  if (value is bool) return SmyBool(value);
  if (value is int) return SmyInt(value);
  if (value is String) return SmyString(value);
  if (value is List<SmyValue>) return SmyList(value);
  if (value is Map<SmyValue, SmyValue>) return SmyDict(value);
  if (value is Set<SmyValue>) return SmySet(value);
  throw "TypeError: alien value '$value'";
}

/// Everything in Smython is a value.
///
/// - [SmyNone] represents `None`
/// - [SmyBool] represents `True` and `False`
/// - [SmyInt] represents integer numbers
/// - [SmyDouble] represents double numbers
/// - [SmyString] represents strings
/// - [SmyTuple] represents tuples (immutable fixed-size arrays)
/// - [SmyList] represents lists (mutable growable arrays)
/// - [SmyDict] represents dicts (mutable hash maps)
/// - [SmySet] represents sets (mutable hash sets)
/// - [SmyBultin] represents built-in functions
/// - [SmyFunc] represents user defined functions
/// - [SmyMethod] represents methods
/// - [SmyObject] represents objects
/// - [SmyClass] represents classes
///
/// Each value has an associated boolean value ([boolValue]).
/// Each value has a print string ([toString]).
/// Some values have associated [intValue] or [doubleValue].
/// Some values are callable ([call]).
/// Some values are iterable ([iterable]).
/// Those values also have an associated length.
/// Some values have attributes which can be get, set and/or deleted.
///
abstract class SmyValue {
  const SmyValue();

  bool get isNone => false;
  bool get boolValue => false;
  int get intValue => throw 'TypeError: Not an integer';
  String get stringValue => throw 'TypeError: Not a string';
  SmyValue call(Frame f, List<SmyValue> args) => throw 'TypeError: Not callable';

  Iterable<SmyValue> get iterable => throw 'TypeError: Not iterable';
  int get length => iterable.length;

  SmyValue getAttr(String name) => throw "AttributeError: No attribute '$name'";
  SmyValue setAttr(String name, SmyValue value) => throw "AttributeError: No attribute '$name'";
  SmyValue delAttr(String name) => throw "AttributeError: No attribute '$name'";

  Map<SmyValue, SmyValue> get mapValue => throw 'TypeError: Not a dict';

  static const SmyNone none = SmyNone._();
  static const SmyBool trueValue = SmyBool._(true);
  static const SmyBool falseValue = SmyBool._(false);
}

/// `None` (singleton, equatable, hashable)
class SmyNone extends SmyValue {
  factory SmyNone() => SmyValue.none;

  const SmyNone._();

  @override
  bool operator ==(dynamic other) => other is SmyNone;

  @override
  int get hashCode => 18736098234;

  @override
  String toString() => 'None';

  @override
  bool get isNone => true;

  @override
  bool get boolValue => false;
}

/// `True` or `False` (singletons, equatable, hashable)
class SmyBool extends SmyValue {
  factory SmyBool(bool value) => value ? SmyValue.trueValue : SmyValue.falseValue;

  const SmyBool._(this.value);

  final bool value;

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
  const SmyInt(this.value);
  final int value;

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
  const SmyString(this.value);
  final String value;

  static final Map<String, SmyString> _interns = {};
  static SmyString intern(String value) => _interns.putIfAbsent(value, () => SmyString(value));

  @override
  bool operator ==(dynamic other) => other is SmyString && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  @override
  bool get boolValue => value.isNotEmpty;

  @override
  String get stringValue => value;

  @override
  int get length => value.length;
}

/// `(expr, ...)`
class SmyTuple extends SmyValue {
  const SmyTuple(this.values);
  final List<SmyValue> values;

  @override
  String toString() {
    if (values.isEmpty) return '()';
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
  const SmyList(this.values);
  final List<SmyValue> values;

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
  const SmyDict(this.values);
  final Map<SmyValue, SmyValue> values;

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
  const SmySet(this.values);
  final Set<SmyValue> values;

  @override
  bool get boolValue => values.isNotEmpty;

  @override
  Iterable<SmyValue> get iterable => values;

  @override
  int get length => values.length;
}

/// `class name (super): ...`
class SmyClass extends SmyValue {
  SmyClass(this._name, this._superclass);

  final SmyString _name;
  final SmyClass? _superclass;
  final SmyDict _dict = SmyDict({});

  Map<SmyValue, SmyValue> get methods => _dict.values;

  SmyValue? findAttr(String name) {
    final n = SmyString(name);
    for (SmyClass? cls = this; cls != null; cls = cls._superclass) {
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
    final init = findAttr('__init__');
    if (init is SmyFunc) {
      init.call(f, <SmyValue>[object] + args);
    }
    return object;
  }

  @override
  SmyValue getAttr(String name) {
    if (name == '__name__') return _name;
    if (name == '__superclass__') return _superclass ?? SmyValue.none;
    if (name == '__dict__') return _dict;
    return super.getAttr(name);
  }
}

class SmyObject extends SmyValue {
  SmyObject(this._class);

  final SmyClass _class;
  final SmyDict _dict = SmyDict({});

  @override
  String toString() => '<${_class._name} object $hashCode>';

  @override
  SmyValue getAttr(String name) {
    if (name == '__class__') return _class;
    if (name == '__dict__') return _dict;

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
  SmyMethod(this.self, this.func);

  final SmyObject self;
  final SmyFunc func;

  @override
  SmyValue call(Frame f, List<SmyValue> args) {
    return func.call(f, <SmyValue>[self] + args);
  }
}

/// `def name(param, ...): ...`
class SmyFunc extends SmyValue {
  const SmyFunc(this.df, this.name, this.params, this.defExprs, this.suite);

  final Frame df;
  final SmyString name;
  final List<String> params;
  final List<Expr> defExprs;
  final Suite suite;

  @override
  String toString() => '<function $name>';

  @override
  SmyValue call(Frame cf, List<SmyValue> args) {
    final f = Frame(df, {}, df.globals, df.builtins);
    for (var i = 0, j = 0; i < params.length; i++) {
      f.locals[SmyString(params[i])] = i < args.length ? args[i] : defExprs[j++].evaluate(df);
    }
    return suite.evaluateAsFunc(f);
  }
}

/// builtin function like print or len
class SmyBuiltin extends SmyValue {
  const SmyBuiltin(this.name, this.func);

  final SmyString name;
  final SmyValue Function(Frame cf, List<SmyValue> args) func;

  @override
  String toString() => '<built-in function $name>';

  @override
  SmyValue call(Frame cf, List<SmyValue> args) => func(cf, args);
}

// -------- Runtime --------

class Frame {
  Frame(this.parent, this.locals, this.globals, this.builtins);

  final Frame? parent;
  final Map<SmyValue, SmyValue> locals;
  final Map<SmyValue, SmyValue> globals;
  final Map<SmyValue, SmyValue> builtins;

  /// Returns the value bound to [name] by first searching [locals],
  /// then searching [globals], and last but not least searching the
  /// [builtins]. Throws a `NameError` if [name] is unbound.
  SmyValue lookup(SmyString name) {
    if (locals.containsKey(name)) {
      return locals[name]!;
    }
    if (parent != null) {
      return parent!.lookup(name);
    }
    if (globals.containsKey(name)) {
      return globals[name]!;
    }
    if (builtins.containsKey(name)) {
      return builtins[name]!;
    }
    throw "NameError: name '$name' is not defined";
  }
}
