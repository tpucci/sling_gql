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
  Selection._(this.field, this.args, this.parent)
      : alias = _aliasFor(field, args);

  Selection.root(String operation) : this._(operation, const {}, null);

  final String field;
  final Map<String, Arg> args;
  final Selection? parent;

  /// Also the cache key for this field on its parent object.
  final String alias;

  final Map<String, Selection> _children = {};

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
      out.insert(0, node.alias);
      node = node.parent;
    }
    return out;
  }

  Selection child(String field, [Map<String, Arg> args = const {}]) {
    final alias = _aliasFor(field, args);
    return _children.putIfAbsent(alias, () => Selection._(field, args, this));
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

  Selection? childByAlias(String alias) => _children[alias];

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
      cursor = cursor.child(n.field, n.args).._adopt(n);
    }
    return cursor;
  }

  /// Deep-merges [other]'s subtree into this node.
  void mergeFrom(Selection other) {
    for (final c in other.children) {
      (child(c.field, c.args).._adopt(c)).mergeFrom(c);
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

/// Prints a selection tree as an operation document, collecting arguments as
/// variables.
class PrintedOperation {
  PrintedOperation(this.document, this.variables);

  final String document;
  final Map<String, Object?> variables;

  static PrintedOperation from(Selection root) {
    final variables = <String, Object?>{};
    final varDefs = <String>[];
    var counter = 0;

    String printNode(Selection node, int depth) {
      final indent = '  ' * depth;
      final buf = StringBuffer(indent);
      if (node.alias != node.field) buf.write('${node.alias}: ');
      buf.write(node.field);
      final args = node.args.entries.where((e) => e.value.value != null);
      if (args.isNotEmpty) {
        buf.write('(');
        buf.write(args.map((e) {
          final name = 'v${counter++}';
          variables[name] = e.value.value;
          varDefs.add('\$$name: ${e.value.graphqlType}');
          return '${e.key}: \$$name';
        }).join(', '));
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
