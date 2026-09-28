/// A minimal GraphQL document parser: enough for the operations sling_gql
/// prints (one anonymous operation, aliases, arguments as variables or
/// literals, nested selections) and for hand-written documents of the same
/// shape. Fragments and directives are not supported.
library;

/// One parsed operation: `query`, `mutation` or `subscription`.
class ParsedOperation {
  ParsedOperation(this.type, this.name, this.fields);

  /// `query` / `mutation` / `subscription`.
  final String type;

  /// The operation name, if any.
  final String? name;

  /// Root fields, in document order.
  final List<ParsedField> fields;
}

/// One field of a selection set, with its arguments already resolved
/// (variables substituted) and its sub-selection.
class ParsedField {
  ParsedField(this.name, this.alias, this.args, this.selection);

  final String name;

  /// The response key: the alias when the field has one, else [name].
  final String alias;

  /// Argument values, variables substituted from the request.
  final Map<String, Object?> args;

  /// Sub-selection; empty for scalars.
  final List<ParsedField> selection;

  @override
  String toString() => alias == name ? name : '$alias: $name';
}

/// Thrown when a document cannot be parsed.
class GraphQLSyntaxError implements Exception {
  GraphQLSyntaxError(this.message);
  final String message;
  @override
  String toString() => 'GraphQLSyntaxError: $message';
}

/// Parses [document], substituting `$name` arguments from [variables].
ParsedOperation parseOperation(
  String document, [
  Map<String, Object?> variables = const {},
]) => _Parser(document, variables).operation();

class _Parser {
  _Parser(String source, this.variables) : _tokens = _tokenize(source);

  final Map<String, Object?> variables;
  final List<String> _tokens;
  int _i = 0;

  String get _peek => _i < _tokens.length ? _tokens[_i] : '';
  String _next() {
    if (_i >= _tokens.length) throw GraphQLSyntaxError('unexpected end');
    return _tokens[_i++];
  }

  void _expect(String t) {
    final got = _next();
    if (got != t) throw GraphQLSyntaxError('expected "$t", got "$got"');
  }

  ParsedOperation operation() {
    var type = 'query';
    String? name;
    if (_peek == '{') {
      // Anonymous query shorthand.
    } else {
      type = _next();
      if (!const {'query', 'mutation', 'subscription'}.contains(type)) {
        throw GraphQLSyntaxError('unknown operation type "$type"');
      }
      if (_peek != '(' && _peek != '{') name = _next();
      if (_peek == '(') _skipVariableDefinitions();
    }
    final fields = _selectionSet();
    if (_i != _tokens.length) {
      throw GraphQLSyntaxError('trailing tokens after the operation');
    }
    return ParsedOperation(type, name, fields);
  }

  void _skipVariableDefinitions() {
    _expect('(');
    var depth = 1;
    while (depth > 0) {
      final t = _next();
      if (t == '(') depth++;
      if (t == ')') depth--;
    }
  }

  List<ParsedField> _selectionSet() {
    _expect('{');
    final fields = <ParsedField>[];
    while (_peek != '}') {
      if (_peek == '...') {
        throw GraphQLSyntaxError('fragments are not supported');
      }
      fields.add(_field());
    }
    _expect('}');
    return fields;
  }

  ParsedField _field() {
    var name = _name();
    var alias = name;
    if (_peek == ':') {
      _next();
      name = _name();
    }
    final args = <String, Object?>{};
    if (_peek == '(') {
      _next();
      while (_peek != ')') {
        final argName = _name();
        _expect(':');
        args[argName] = _value();
      }
      _next();
    }
    if (_peek == '@') {
      throw GraphQLSyntaxError('directives are not supported');
    }
    final selection = _peek == '{' ? _selectionSet() : const <ParsedField>[];
    return ParsedField(name, alias, args, selection);
  }

  String _name() {
    final t = _next();
    if (!_isName(t)) throw GraphQLSyntaxError('expected a name, got "$t"');
    return t;
  }

  Object? _value() {
    final t = _next();
    switch (t) {
      case r'$':
        final name = _name();
        if (!variables.containsKey(name)) {
          throw GraphQLSyntaxError('variable \$$name is not provided');
        }
        return variables[name];
      case '[':
        final list = <Object?>[];
        while (_peek != ']') {
          list.add(_value());
        }
        _next();
        return list;
      case '{':
        final map = <String, Object?>{};
        while (_peek != '}') {
          final k = _name();
          _expect(':');
          map[k] = _value();
        }
        _next();
        return map;
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
        return null;
    }
    if (t.startsWith('"')) return _unquote(t);
    final number = num.tryParse(t);
    if (number != null) return number;
    if (_isName(t)) return t; // enum literal
    throw GraphQLSyntaxError('unexpected "$t"');
  }

  static bool _isName(String t) =>
      RegExp(r'^[_A-Za-z][_0-9A-Za-z]*$').hasMatch(t);

  static String _unquote(String t) {
    final inner = t.substring(1, t.length - 1);
    return inner.replaceAllMapped(
      RegExp(r'\\(u[0-9a-fA-F]{4}|.)'),
      (m) => switch (m.group(1)!) {
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        'b' => '\b',
        'f' => '\f',
        final e when e.startsWith('u') => String.fromCharCode(
          int.parse(e.substring(1), radix: 16),
        ),
        final e => e,
      },
    );
  }

  static List<String> _tokenize(String source) {
    final tokens = <String>[];
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == ',') {
        i++;
        continue;
      }
      if (c == '#') {
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }
      if (source.startsWith('...', i)) {
        tokens.add('...');
        i += 3;
        continue;
      }
      if ('{}():[]!@\$='.contains(c)) {
        tokens.add(c);
        i++;
        continue;
      }
      if (c == '"') {
        final start = i;
        i++;
        while (i < source.length && source[i] != '"') {
          if (source[i] == r'\') i++;
          i++;
        }
        if (i >= source.length) throw GraphQLSyntaxError('unterminated string');
        i++;
        tokens.add(source.substring(start, i));
        continue;
      }
      final m = RegExp(
        r'^(-?\d+(\.\d+)?([eE][+-]?\d+)?|[_A-Za-z][_0-9A-Za-z]*)',
      ).firstMatch(source.substring(i));
      if (m == null) throw GraphQLSyntaxError('unexpected character "$c"');
      tokens.add(m.group(0)!);
      i += m.end;
    }
    return tokens;
  }
}
