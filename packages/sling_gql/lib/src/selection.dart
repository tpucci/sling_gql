import 'dart:convert';

/// A typed GraphQL argument. The [graphqlType] is the *GraphQL* type literal
/// (e.g. `Int`, `String!`, `LaunchFind`), used to declare the variable in the
/// operation document. Values are always sent as JSON variables, so enums and
/// input objects need no special serialization on the client side.
class Arg {
  const Arg(this.graphqlType, this.value);

  final String graphqlType;
  final Object? value;
}

/// A node in a selection tree.
///
/// The tree mirrors the shape of a GraphQL operation: every node is a field
/// (with optional arguments) and its children are the sub-selection. Lists are
/// transparent — a list field has the element's fields as children.
///
/// The [alias] is derived from the field name and a stable hash of the
/// arguments so that the same field queried with different arguments can live
/// side by side in one document *and* in the cache.
class Selection {
  Selection._(this.field, this.args, this.parent, [String? alias])
    : alias = alias ?? _aliasFor(field, args),
      typeCondition = null;

  Selection._fragment(String typename, this.parent)
    : field = typename,
      args = const {},
      alias = '... on $typename',
      typeCondition = typename {
    isObject = true;
  }

  Selection.root(String operation) : this._(operation, const {}, null);

  /// The field name; for an inline fragment, the type condition.
  final String field;
  final Map<String, Arg> args;
  final Selection? parent;

  /// Also the cache key for this field on its parent object. Inline
  /// fragments use `... on Type`, which no field alias can spell.
  final String alias;

  /// Set on an inline fragment node (`... on Launch { … }`): its children are
  /// fields of that concrete type, read at the *parent's* cache location. A
  /// fragment adds nothing to cache paths ([aliasPath] skips it).
  final String? typeCondition;

  bool get isFragment => typeCondition != null;

  final Map<String, Selection> _children = {};

  /// Arg-bearing children by structural value of their (non-null) arguments,
  /// so a rebuild finds `launches(first: 10)` again without re-running
  /// `jsonEncode` + FNV on a freshly allocated args map (#18).
  Map<_ArgsKey, Selection>? _byArgs;

  /// Set when the field was accessed as an object or list of objects. Such a
  /// node must be printed with braces even if no sub-field was read yet.
  bool isObject = false;

  /// Set when the object type is normalizable: this field (`id`) is always
  /// printed alongside `__typename` so the response can be keyed.
  String? keyField;

  Iterable<Selection> get children => _children.values;
  bool get isLeaf => _children.isEmpty;
  bool get isRoot => parent == null;

  /// Aliases from the root (exclusive) down to this node (inclusive).
  List<String> get aliasPath {
    final out = <String>[];
    Selection? node = this;
    while (node != null && !node.isRoot) {
      if (!node.isFragment) out.insert(0, node.alias);
      node = node.parent;
    }
    return out;
  }

  Selection child(String field, [Map<String, Arg> args = const {}]) {
    if (args.isEmpty) {
      return _children[field] ??= Selection._(field, args, this, field);
    }
    final key = _ArgsKey(field, args);
    final byArgs = _byArgs ??= {};
    final known = byArgs[key];
    if (known != null) return known;
    final alias = _aliasFor(field, args);
    return byArgs[key] = _children.putIfAbsent(
      alias,
      () => Selection._(field, args, this, alias),
    );
  }

  /// Like [child], flagged as an object selection. [keyField] marks the
  /// object as an entity whose key field must always be fetched.
  Selection objectChild(
    String field, [
    Map<String, Arg> args = const {},
    String? keyField,
  ]) {
    final node = child(field, args)..isObject = true;
    if (keyField != null) node.keyField = keyField;
    return node;
  }

  /// The inline fragment `... on [typename]` under this (abstract-typed)
  /// object node. [keyField] as in [objectChild], for keyed member types.
  Selection fragment(String typename, [String? keyField]) {
    final node = _children.putIfAbsent(
      '... on $typename',
      () => Selection._fragment(typename, this),
    );
    if (keyField != null) node.keyField = keyField;
    return node;
  }

  Selection? childByAlias(String alias) => _children[alias];

  /// The node in this tree corresponding to [other] (a child of a node
  /// matching [other]'s parent), created when absent.
  Selection _counterpart(Selection other) =>
      (other.isFragment
            ? fragment(other.typeCondition!)
            : child(other.field, other.args))
        .._adopt(other);

  /// Ensures every node of [other]'s path from its root exists under this
  /// root, and returns the corresponding node in this tree.
  Selection ensurePath(Selection other) {
    final chain = <Selection>[];
    Selection? node = other;
    while (node != null && !node.isRoot) {
      chain.insert(0, node);
      node = node.parent;
    }
    var cursor = this;
    for (final n in chain) {
      cursor = cursor._counterpart(n);
    }
    return cursor;
  }

  /// Deep-merges [other]'s subtree into this node.
  void mergeFrom(Selection other) {
    for (final c in other.children) {
      _counterpart(c).mergeFrom(c);
    }
  }

  void _adopt(Selection other) {
    isObject |= other.isObject;
    keyField ??= other.keyField;
  }

  /// True if every leaf of [other] is present in this tree.
  bool covers(Selection other) {
    for (final c in other.children) {
      final mine = _children[c.alias];
      if (mine == null || !mine.covers(c)) return false;
    }
    return true;
  }

  /// Aliases of the direct children (top-level fields for a root).
  Set<String> get childAliases => _children.keys.toSet();

  static String _aliasFor(String field, Map<String, Arg> args) {
    final present = <String, Object?>{
      for (final e in args.entries)
        if (e.value.value != null) e.key: e.value.value,
    };
    if (present.isEmpty) return field;
    final keys = present.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: present[k]});
    return '${field}_${_fnv1a(canonical)}';
  }

  static String _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(36);
  }

  @override
  String toString() => 'Selection($alias, children: ${_children.keys})';
}

/// Lookup key for an arg-bearing child: the field name plus the non-null
/// argument values, compared deeply (JSON-like values: maps, lists, scalars).
/// Argument order does not matter; `null` arguments are ignored, as in the
/// alias.
class _ArgsKey {
  _ArgsKey(this.field, this.args) : hashCode = _hashArgs(field, args);

  final String field;
  final Map<String, Arg> args;

  @override
  final int hashCode;

  static int _hashArgs(String field, Map<String, Arg> args) {
    var h = 0;
    for (final e in args.entries) {
      final v = e.value.value;
      // Order-independent over entries.
      if (v != null) h = (h + Object.hash(e.key, _deepHash(v))) & 0x3fffffff;
    }
    return Object.hash(field, h);
  }

  static int _deepHash(Object? v) => switch (v) {
    List() => Object.hashAll(v.map(_deepHash)),
    Map() => v.entries.fold(
      0,
      (h, e) => (h + Object.hash(e.key, _deepHash(e.value))) & 0x3fffffff,
    ),
    _ => v.hashCode,
  };

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !_deepEquals(e.value, b[e.key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List || a is Map || b is List || b is Map) return false;
    // `1 == 1.0` in Dart but they print differently in JSON (and alias
    // differently): keep them apart.
    if (a is num && b is num) return a == b && (a is int) == (b is int);
    return a == b;
  }

  @override
  bool operator ==(Object other) {
    if (other is! _ArgsKey || other.hashCode != hashCode) return false;
    if (other.field != field) return false;
    var count = 0;
    for (final e in args.entries) {
      final v = e.value.value;
      if (v == null) continue;
      count++;
      if (!_deepEquals(v, other.args[e.key]?.value)) return false;
    }
    var otherCount = 0;
    for (final a in other.args.values) {
      if (a.value != null) otherCount++;
    }
    return count == otherCount;
  }
}

/// Prints a selection tree as an operation document, collecting arguments as
/// variables.
class PrintedOperation {
  PrintedOperation(this.document, this.variables);

  final String document;
  final Map<String, Object?> variables;

  static PrintedOperation from(Selection root) {
    final variables = <String, Object?>{};
    final varDefs = <String>[];
    // Variable names default to the argument name ('$first', '$after').
    // Two arguments with the same name but a different value (e.g. the same
    // field queried twice with a different `id`) get a numeric suffix on the
    // second and later distinct value ('$first', '$first2'); the same name
    // with the *same* value (by canonical JSON) reuses one variable.
    final namesByArg = <String, Map<String, String>>{};
    final suffixByArg = <String, int>{};

    String nameFor(String argName, Object? value, String graphqlType) {
      final canonical = jsonEncode(value);
      final byValue = namesByArg.putIfAbsent(argName, () => {});
      final existing = byValue[canonical];
      if (existing != null) return existing;
      final suffix = suffixByArg[argName] ?? 1;
      suffixByArg[argName] = suffix + 1;
      final name = suffix == 1 ? argName : '$argName$suffix';
      byValue[canonical] = name;
      variables[name] = value;
      varDefs.add('\$$name: $graphqlType');
      return name;
    }

    String printNode(Selection node, int depth) {
      final indent = '  ' * depth;
      final buf = StringBuffer(indent);
      if (node.isFragment) {
        // `__typename` is already selected on the enclosing object.
        buf.writeln('... on ${node.typeCondition} {');
        final keyField = node.keyField;
        if (keyField != null) buf.writeln('$indent  $keyField');
        for (final c in node.children) {
          if (c.field == keyField && c.args.isEmpty) continue;
          buf.writeln(printNode(c, depth + 1));
        }
        if (node.isLeaf && keyField == null) {
          buf.writeln('$indent  __typename'); // no empty selection sets
        }
        buf.write('$indent}');
        return buf.toString();
      }
      if (node.alias != node.field) buf.write('${node.alias}: ');
      buf.write(node.field);
      final args = node.args.entries.where((e) => e.value.value != null);
      if (args.isNotEmpty) {
        buf.write('(');
        buf.write(
          args
              .map((e) {
                final name = nameFor(e.key, e.value.value, e.value.graphqlType);
                return '${e.key}: \$$name';
              })
              .join(', '),
        );
        buf.write(')');
      }
      if (!node.isLeaf || node.isObject) {
        buf.writeln(' {');
        buf.writeln('$indent  __typename');
        final keyField = node.keyField;
        if (keyField != null) buf.writeln('$indent  $keyField');
        for (final c in node.children) {
          // The key field is already printed above; skip a plain duplicate.
          if (c.field == keyField && c.args.isEmpty) continue;
          buf.writeln(printNode(c, depth + 1));
        }
        buf.write('$indent}');
      }
      return buf.toString();
    }

    final body = root.children.map((c) => printNode(c, 1)).join('\n');
    final header = varDefs.isEmpty
        ? root.field
        : '${root.field} (${varDefs.join(', ')})';
    return PrintedOperation('$header {\n$body\n}', variables);
  }
}
