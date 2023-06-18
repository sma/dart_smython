/// The runtime system for Smython.
///
/// Create a new [Smython] instance to run code. It has a small but
/// extendable number of builtin function. Use [Smython.builtin] to add
/// your own. Use [Smython.execute] to run Smython code.
///
/// Example:
/// ```
/// Smython().execute('print(3+4)');
/// ```
///
/// To learn more about the supported syntax, see `parser.dart`.
///
/// See [SmyValue] for how Smython values are represented in Dart. Use
/// [make] to convert a Dart value into a [SmyValue] instance. This might
/// throw if there is no Smython value of tha given Dart value.
library smython;

import 'dart:io';
import 'dart:math';

import 'ast_eval.dart' show Expr, Suite;
import 'parser.dart' show parse;

export 'parser.dart' show parse;

typedef SmythonBuiltin = SmyValue Function(Frame f, List<SmyValue> args);

/// Main entry point.
class Smython {
  final builtins = <SmyValue, SmyValue>{};
  final globals = <SmyValue, SmyValue>{};
  final modules = <SmyValue, SmyValue>{};

  Smython() {
    builtin('print', (f, args) {
      print(args.map((v) => '$v').join(' '));
      return none;
    });
    builtin('len', (f, args) {
      if (args.length != 1) throw 'TypeError: len() takes 1 argument (${args.length} given)';
      return SmyNum(args[0].length);
    });
    builtin('slice', (f, args) {
      if (args.length != 3) throw 'TypeError: slice() takes 3 arguments (${args.length} given)';
      return SmyTuple(args);
    });
    builtin('del', (f, args) {
      if (args.length != 2) throw 'TypeError: del() takes 2 arguments (${args.length} given)';
      final value = args[0];
      final index = args[1];
      if (value is SmyList) {
        if (index is SmyNum) {
          return value.values.removeAt(index.index);
        }
        if (index is SmyTuple) {
          final length = value.values.length;
          var start = index.values[0].isNone ? 0 : index.values[0].index;
          var end = index.values[1].isNone ? value.values.length : index.values[1].index;
          if (start < 0) start += length;
          if (end < 0) end += length;
          if (start >= end) return none;
          value.values.removeRange(start, end);
          return none;
        }
        throw 'TypeError: invalid index';
      }
      if (value is SmyDict) {
        return value.values.remove(index) ?? SmyValue.none;
      }
      throw 'TypeError: Unsupported item deletion';
    });
    builtin('range', (f, args) {
      if (args.isEmpty) {
        throw 'TypeError: range expected at least 1 argument, got ${args.length}';
      }
      if (args.length > 3) {
        throw 'TypeError: range expected at most 3 arguments, got ${args.length}';
      }
      var begin = 0;
      var end = args[0].intValue;
      var step = 1;
      if (args.length == 2) {
        begin = end;
        end = args[1].intValue;
      }
      if (args.length == 3) {
        step = args[2].intValue;
      }
      if (step == 0) throw 'ValueError: range() arg 3 must not be zero';
      if (step < 0) {
        return SmyList([for (var i = begin; i > end; i += step) SmyNum(i)]);
      }
      return SmyList([for (var i = begin; i < end; i += step) SmyNum(i)]);
    });
    builtin('hasattr', (f, args) {
      if (args.length != 2) throw 'TypeError: hasattr() takes 2 arguments (${args.length} given)';
      final value = args[0];
      final key = args[1];
      if (value is SmyList) {
        return SmyBool(value.values.contains(key));
      }
      if (value is SmyDict) {
        return SmyBool(value.values.containsKey(key));
      }
      if (value is SmyModule) {
        return SmyBool(value.globals.values.containsKey(key));
      }
      throw 'TypeError: Unsupported hasattr()';
    });
    builtin('chr', (f, args) {
      if (args.length != 1) throw 'TypeError: chr() takes 1 argument (${args.length} given)';
      return SmyString(String.fromCharCode(args[0].intValue));
    });
    builtin('ord', (f, args) {
      if (args.length != 1) throw 'TypeError: ord() takes 1 argument (${args.length} given)';
      return SmyNum(args[0].stringValue.codeUnitAt(0));
    });
  }

  /// Adds [func] as a new builtin function [name] to the system.
  void builtin(String name, SmythonBuiltin func) {
    final bname = SmyString.intern(name);
    builtins[bname] = SmyBuiltin(bname, func);
  }

  SmyModule? import(String moduleName) {
    final name = SmyString.intern(moduleName);
    final module = modules[name];
    if (module is SmyModule) return module;

    if (moduleName == 'sys') {
      return modules[name] = SmyModule(
        name,
        SmyDict({
          SmyString('modules'): SmyDict(modules),
        }),
      );
    }

    if (moduleName == 'os') {
      return modules[name] = SmyModule(
        name,
        SmyDict({
          SmyString('getlogin'): SmyBuiltin(SmyString('getlogin'), (cf, args) {
            return SmyString(Platform.environment['USER'] ?? '');
          }),
          SmyString('getpid'): SmyBuiltin(SmyString('getpid'), (cf, args) {
            return SmyNum(pid);
          }),
        }),
      );
    }

    if (moduleName == 'random') {
      var random = Random();
      return modules[name] = SmyModule(
        name,
        SmyDict({
          SmyString('seed'): SmyBuiltin(SmyString('seed'), (cf, args) {
            random = Random(args[0].intValue);
            return none;
          }),
          SmyString('randint'): SmyBuiltin(SmyString('randint'), (cf, args) {
            final min = args[0].intValue;
            final max = args[1].intValue;
            return SmyNum(random.nextInt(max - min) + min);
          }),
        }),
      );
    }

    String source;
    if (moduleName == 'curses') {
      source = '''
class Curses:
    def clear(self): pass
    def clrtoeol(self): pass
    def getkey(self): return '?'
    def move(self, row, col): pass
    def inch(self, row, col): return 0
    def refresh(self): pass
    def standout(self): pass
    def standend(self): pass
    def addch(self, *args): pass
    def addstr(self, *args): pass
def cbreak(): pass
def noecho(): pass
def nonl(): pass
def endwin(): pass
def beep(): pass
def initscr(): return Curses()
''';
    } else if (moduleName == 'atexit') {
      source = '''
def register(func): pass
''';
    } else if (moduleName == 'copy') {
      source = '''
def copy(obj): return obj
''';
    } else if (moduleName == 'time') {
      source = '''
''';
    } else {
      final file = File('pyrogue/$moduleName.py');
      if (!file.existsSync()) return null;
      source = file.readAsStringSync();
    }
    final globals = <SmyValue, SmyValue>{};
    modules[name] = SmyModule(name, SmyDict(globals));
    parse(source).evaluate(Frame(null, globals, globals, builtins, this));
    return modules[name] as SmyModule;
  }

  /// Runs [source].
  void execute(String source) {
    parse(source).evaluate(Frame(null, globals, globals, builtins, this));
  }
}

/// The global value representing no other value.
const none = SmyValue.none;

/// Returns the Smython value for a Dart [value].
SmyValue make(Object? value) {
  if (value == null) return SmyNone();
  if (value is SmyValue) return value;
  if (value is bool) return SmyBool(value);
  if (value is num) return SmyNum(value);
  if (value is String) return SmyString(value);
  if (value is List<SmyValue>) return SmyList(value);
  if (value is List) return make([...value.map(make)]);
  if (value is Map<SmyValue, SmyValue>) return SmyDict(value);
  if (value is Map) return make(value.map((dynamic key, dynamic value) => MapEntry(make(key), make(value))));
  if (value is Set<SmyValue>) return SmySet(value);
  if (value is Set) return make(value.map(make).toSet());
  throw "TypeError: alien value '$value'";
}

/// Everything in Smython is a value.
///
/// There are a lot of subclasses:
/// - [SmyNone] represents `None`
/// - [SmyBool] represents `True` and `False`
/// - [SmyNum] represents integer and double numbers
/// - [SmyString] represents strings
/// - [SmyTuple] represents tuples (immutable fixed-size arrays)
/// - [SmyList] represents lists (mutable growable arrays)
/// - [SmyDict] represents dicts (mutable hash maps)
/// - [SmySet] represents sets (mutable hash sets)
/// - [SmyClass] represents classes
/// - [SmyObject] represents objects (instances of classes)
/// - [SmyMethod] represents methods (functions bound to instances)
/// - [SmyFunc] represents user defined functions
/// - [SmyBuiltin] represents built-in functions
///
/// Each value knows whether it is the [none] singleton.
/// Each value has an associated boolean value ([boolValue]).
/// Each value has a print string ([toString]).
/// Some values have associated [intValue] or [doubleValue].
/// Some values are even strings ([stringValue]).
/// Some values are callable ([call]).
/// Some values are iterable ([iterable]).
/// Those values also have an associated [length].
/// Some values have attributes which can be get, set and/or deleted.
/// Some values are representable as a Dart map ([mapValue]).
/// Some values can be used as a list index ([index]).
///
/// For efficency, [SmyString.intern] can be used to create unique strings,
/// so called symbols which are used in [Frame] objects to lookup values.
///
/// There are threee singletons: [none], [trueValue], and [falseValue].
sealed class SmyValue {
  const SmyValue();

  bool get isNone => false;
  bool get boolValue => false;
  num get numValue => throw 'TypeError: Not a number';
  int get intValue => numValue.toInt();
  double get doubleValue => numValue.toDouble();
  String get stringValue => throw 'TypeError: Not a string';
  SmyValue call(Frame cf, List<SmyValue> args) => throw 'TypeError: Not callable';
  Iterable<SmyValue> get iterable => throw 'TypeError: Not iterable';
  int get length => iterable.length;

  Never attributeError(String name) => throw "AttributeError: No attribute '$name'";
  SmyValue getAttr(String name) => attributeError(name);
  SmyValue setAttr(String name, SmyValue value) => attributeError(name);
  SmyValue delAttr(String name) => attributeError(name);

  Map<SmyValue, SmyValue> get mapValue => throw 'TypeError: Not a dict';

  int get index => throw 'TypeError: list indices must be integers';

  static const SmyNone none = SmyNone._();
  static const SmyBool trueValue = SmyBool._(true);
  static const SmyBool falseValue = SmyBool._(false);
}

/// `None` (singleton, equatable, hashable)
final class SmyNone extends SmyValue {
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
final class SmyBool extends SmyValue {
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
final class SmyNum extends SmyValue {
  const SmyNum(this.value);
  final num value;

  @override
  bool operator ==(dynamic other) => other is SmyNum && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';

  @override
  bool get boolValue => value != 0;

  @override
  num get numValue => value;

  @override
  int get index {
    return intValue.toInt();
  }
}

/// `STRING` (equatable, hashable)
final class SmyString extends SmyValue {
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

  SmyString format(SmyValue args) {
    if (args is SmyTuple) {
      var index = 0;
      return SmyString(stringValue.replaceAllMapped(RegExp(r'%%|%(\d+)?([sd])'), (match) {
        if (match[0] == '%%') return '%';
        String value;
        if (match[2] == 's') {
          value = '${args.values[index++]}';
        } else {
          value = '${args.values[index++].intValue}';
        }
        if (match[1] != null) {
          final width = int.parse(match[1]!);
          value = value.padLeft(width);
        }
        return value;
      }));
    }
    if (args is SmyList) return format(SmyTuple(args.values));
    return format(SmyTuple([args]));
  }
}

/// `(expr, ...)`
final class SmyTuple extends SmyValue {
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
final class SmyList extends SmyValue {
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

  @override
  SmyValue getAttr(String name) {
    if (name == 'append') {
      return SmyMethod(
        this,
        SmyBuiltin(SmyString.intern('append'), (f, args) {
          if (args.length != 2) throw 'TypeError: list.append() takes exactly one argument (${args.length - 1} given)';
          values.add(args[1]);
          return none;
        }),
      );
    }
    return super.getAttr(name);
  }
}

/// `{expr: expr, ...}`
final class SmyDict extends SmyValue {
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
  Map<SmyValue, SmyValue> get mapValue => values;

  @override
  Iterable<SmyValue> get iterable => values.entries.map((e) => SmyTuple([e.key, e.value]));

  @override
  int get length => values.length;

  @override
  SmyValue getAttr(String name) {
    if (name == 'values') {
      return SmyMethod(
        this,
        SmyBuiltin(SmyString.intern('values'), (f, args) {
          if (args.length != 1) throw 'TypeError: dict.values() takes no arguments (${args.length - 1} given)';
          return SmyList(values.values.toList());
        }),
      );
    }
    if (name == 'update') {
      return SmyMethod(
        this,
        SmyBuiltin(SmyString.intern('update'), (f, args) {
          if (args.length != 2) throw 'TypeError: dict.update() takes one argument (${args.length - 1} given)';
          values.addAll(args[1].mapValue);
          return none;
        }),
      );
    }
    return super.getAttr(name);
  }
}

/// `{expr, ...}`
final class SmySet extends SmyValue {
  const SmySet(this.values);
  final Set<SmyValue> values;

  @override
  String toString() {
    if (values.isEmpty) return 'set()';
    return '{${values.join(', ')}}';
  }

  @override
  bool get boolValue => values.isNotEmpty;

  @override
  Iterable<SmyValue> get iterable => values;

  @override
  int get length => values.length;
}

/// `class name (super): ...`
final class SmyClass extends SmyValue {
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

  /// Calling a class creates a new instance of that class.
  @override
  SmyValue call(Frame cf, List<SmyValue> args) {
    final object = SmyObject(this);
    final init = findAttr('__init__');
    if (init is SmyFunc) {
      init.call(cf, <SmyValue>[object] + args);
    }
    return object;
  }

  @override
  SmyValue getAttr(String name) {
    if (name == '__name__') return _name;
    if (name == '__superclass__') return _superclass ?? SmyValue.none;
    if (name == '__dict__') return _dict;
    final value = _dict.values[SmyString(name)];
    if (value != null) return value;
    return super.getAttr(name);
  }

  @override
  SmyValue setAttr(String name, SmyValue value) {
    return _dict.values[SmyString(name)] = value;
  }
}

/// class instance
final class SmyObject extends SmyValue {
  SmyObject(this._class);

  final SmyClass _class;
  final SmyDict _dict = SmyDict({});

  @override
  String toString() => '<${_class._name} object $hashCode>';

  @override
  SmyValue getAttr(String name) {
    if (name == '__class__') return _class;
    if (name == '__dict__') return _dict;
    // returns a user-defined property
    final value1 = _dict.values[SmyString(name)];
    if (value1 != null) return value1;
    // returns a class property and bind functions as methods
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

/// instance method
final class SmyMethod extends SmyValue {
  SmyMethod(this.self, this.func);

  final SmyValue self;
  final SmyValue func;

  @override
  SmyValue call(Frame cf, List<SmyValue> args) {
    return func.call(cf, <SmyValue>[self] + args);
  }
}

/// `def name(param, ...): ...`
final class SmyFunc extends SmyValue {
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
    final f = Frame(df, {}, df.globals, df.builtins, df.system);
    for (var i = 0, j = 0; i < params.length; i++) {
      final param = params[i];
      if (param.startsWith('*')) {
        f.locals[SmyString.intern(param.substring(1))] = SmyTuple(args.sublist(i));
        break;
      }
      f.locals[SmyString.intern(param)] = i < args.length ? args[i] : defExprs[j++].evaluate(df);
    }
    return suite.evaluateAsFunc(f);
  }
}

/// Builtin function like `print` or `len`.
final class SmyBuiltin extends SmyValue {
  const SmyBuiltin(this.name, this.func);

  final SmyString name;
  final SmythonBuiltin func;

  @override
  String toString() => '<built-in function $name>';

  @override
  SmyValue call(Frame cf, List<SmyValue> args) => func(cf, args);
}

final class SmyModule extends SmyValue {
  const SmyModule(this.name, this.globals);

  final SmyString name;
  final SmyDict globals;

  @override
  String toString() => '<module $name>';

  @override
  SmyValue getAttr(String name) {
    if (name == '__name__') return this.name;
    if (name == '__dict__') return globals;
    final value = globals.values[SmyString(name)];
    if (value != null) return value;
    return super.getAttr(name);
  }
}

// -------- Runtime --------

/// Runtime state passed to all AST nodes while evaluating them.
final class Frame {
  Frame(this.parent, this.locals, this.globals, this.builtins, this.system);

  /// Links to the parent frame, a.k.a. sender.
  final Frame? parent;

  /// Private bindings local to this frame, a.k.a. local variables.
  final Map<SmyValue, SmyValue> locals;

  /// Shared bindings global to this frame, a.k.a. global variables.
  final Map<SmyValue, SmyValue> globals;

  /// Shared bindings global to this frame, not overwritable.
  final Map<SmyValue, SmyValue> builtins;

  /// Shared reference to the runtime system.
  final Smython system;

  /// Returns the value bound to [name] by first searching [locals],
  /// then searching [globals], and last but not least searching the
  /// [builtins]. Throws a `NameError` if [name] is unbound.
  SmyValue lookup(SmyString name) {
    return locals[name] ??
        parent?.lookup(name) ??
        globals[name] ??
        builtins[name] ??
        (throw "NameError: name '$name' is not defined");
  }

  SmyValue set(SmyString name, SmyValue value) {
    for (Frame? f = this; f != null; f = f.parent) {
      if (f.locals.containsKey(name)) {
        return f.locals[name] = value;
      }
    }
    return locals[name] = value;
  }
}
