import 'dart:convert';

import 'package:meta/meta.dart';

import 'cache/field_policy.dart';

/// A typed GraphQL argument. The [graphqlType] is the *GraphQL* type literal
/// (e.g. `Int`, `String!`, `LaunchFind`), used to declare the variable in the
/// operation document. Values are always sent as JSON variables, so enums and
/// input objects need no special serialization on the client side.
class Arg {
  /// An argument of GraphQL type [graphqlType] with JSON [value].
  const Arg(this.graphqlType, this.value);

  /// The GraphQL type literal the variable is declared with (`ID!`).
  final String graphqlType;

  /// The JSON value sent as the variable; `null` arguments are left out of
  /// the document (and of the alias).
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
/// side by side in one document *and* in the cache. A [FieldPolicy] can make
/// several argument sets share one cache entry: the [cacheKey] then hashes
/// only its key arguments, while each argument set keeps its own [alias] in
/// documents (see [PrintedOperation.toCacheKeys]).
///
/// Public because generated accessor constructors pass it through
/// (`Accessor.selection`); app code reads at most [field], [alias], [args],
/// [parent], [children] (debugging). Building and merging trees is the
/// runtime's business: those members are `@internal`.
class Selection {
  Selection._(this.field, this.args, this.parent, this.alias)
    : cacheKey = alias,
      typeCondition = null;

  Selection._fragment(String typename, this.parent)
    : field = typename,
      args = const {},
      alias = '... on $typename',
      cacheKey = '... on $typename',
      typeCondition = typename {
    isObject = true;
  }

  @internal
  Selection.root(String operation)
    : this._(operation, const {}, null, operation);

  /// The field name; for an inline fragment, the type condition.
  final String field;
  final Map<String, Arg> args;
  final Selection? parent;

  /// The response name this field is printed under; also its cache key
  /// unless a [policy] narrows it ([cacheKey]). Inline fragments use
  /// `... on Type`, which no field alias can spell.
  final String alias;

  /// Where this field is stored on its parent object: [alias], or for a
  /// field with a [FieldPolicy] the field name and a hash of its key
  /// arguments only (`launches(first: 20, after: c, filter: f)` and
  /// `launches(first: 20, filter: f)` both live at the cache key of
  /// `launches(filter: f)`).
  @internal
  String cacheKey;

  FieldPolicy? _policy;
  bool _policyBound = false;

  /// The policy of this field (see `SlingClient.typePolicies`), once bound.
  @internal
  FieldPolicy? get policy => _policy;

  /// [bindPolicy] ran (with or without a policy).
  @internal
  bool get policyBound => _policyBound;

  /// Sibling fields sharing a [cacheKey], per cache key (several argument
  /// sets of one policy field).
  Map<String, List<Selection>>? _entries;

  /// Set on a node of a pending request only fetched to fill fields a
  /// cached policy entry lacks ([ensureFillPath]): its response is written
  /// with [FieldPolicy.fill] instead of being merged as a page.
  @internal
  bool fillOnly = false;

  Map<String, Object?>? _argValues;

  /// The non-null argument values (JSON), as a policy sees them.
  @internal
  Map<String, Object?> get argValues => _argValues ??= {
    for (final e in args.entries)
      if (e.value.value != null) e.key: e.value.value,
  };

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
  @internal
  bool isObject = false;

  /// Set when the object type is normalizable: this field (`id`) is always
  /// printed alongside `__typename` so the response can be keyed.
  @internal
  String? keyField;

  Iterable<Selection> get children => _children.values;
  bool get isLeaf => _children.isEmpty;
  bool get isRoot => parent == null;

  /// Cache keys from the root (exclusive) down to this node (inclusive): the
  /// cache path of this field when no lookup redirected an object on the
  /// way (fragments skipped, like [aliasPath]).
  List<String> get cachePath {
    final out = <String>[];
    Selection? node = this;
    while (node != null && !node.isRoot) {
      if (!node.isFragment) out.insert(0, node.cacheKey);
      node = node.parent;
    }
    return out;
  }

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

  @internal
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
  @internal
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
  @internal
  Selection fragment(String typename, [String? keyField]) {
    final node = _children.putIfAbsent(
      '... on $typename',
      () => Selection._fragment(typename, this),
    );
    if (keyField != null) node.keyField = keyField;
    return node;
  }

  @internal
  Selection? childByAlias(String alias) => _children[alias];

  /// Gives this field its [policy] (`null`: none), deciding its [cacheKey].
  /// Done once, right after the node is created (by the accessor reading
  /// it, or when the node is copied into another tree), before it has
  /// children.
  @internal
  void bindPolicy(FieldPolicy? policy) {
    if (_policyBound) return;
    _policyBound = true;
    if (policy == null) return;
    _policy = policy;
    final keyArgs = <String, Arg>{
      for (final e in args.entries)
        if (policy.isKeyArg(e.key)) e.key: e.value,
    };
    cacheKey = keyArgs.length == args.length
        ? alias
        : _aliasFor(field, keyArgs);
    final parent = this.parent;
    if (parent != null) ((parent._entries ??= {})[cacheKey] ??= []).add(this);
  }

  /// The fields under this node's parent stored at the same [cacheKey]
  /// (this one included): the argument sets of one policy entry.
  @internal
  Iterable<Selection> get sameEntry => parent?._entries?[cacheKey] ?? [this];

  /// [args] with the policy's page arguments set to [page]'s values
  /// (absent ones `null`): the same entry's page [page].
  Map<String, Arg> _argsForPage(Map<String, Object?> page) {
    final pageArgs = _policy?.pageArgs ?? const <String>{};
    return {
      for (final e in args.entries)
        e.key: pageArgs.contains(e.key)
            ? Arg(e.value.graphqlType, page[e.key])
            : e.value,
    };
  }

  /// True when [policy] is a paged one and this field asks for a page other
  /// than the first.
  bool get _isLaterPage {
    final policy = _policy;
    if (policy == null) return false;
    for (final name in policy.pageArgs) {
      if (args[name]?.value != null) return true;
    }
    return false;
  }

  /// The node in this tree corresponding to [other] (a child of a node
  /// matching [other]'s parent), created when absent.
  Selection _counterpart(Selection other) =>
      (other.isFragment
            ? fragment(other.typeCondition!)
            : child(other.field, other.args))
        .._adopt(other);

  /// Ensures every node of [other]'s path from its root exists under this
  /// root, and returns the corresponding node in this tree. With
  /// [firstPages], a policy field on the path asking for a later page is
  /// mapped to its entry's first page, as in [mergeFrom].
  @internal
  Selection ensurePath(Selection other, {bool firstPages = false}) {
    final chain = <Selection>[];
    Selection? node = other;
    while (node != null && !node.isRoot) {
      chain.insert(0, node);
      node = node.parent;
    }
    var cursor = this;
    for (final n in chain) {
      cursor = firstPages && n._isLaterPage
          ? (cursor.child(n.field, n._argsForPage(const {})).._adopt(n))
          : cursor._counterpart(n);
    }
    return cursor;
  }

  /// Deep-merges [other]'s subtree into this node. With [firstPages], a
  /// policy field asking for a later page (`after: c`) is merged as its
  /// entry's first page instead: what a fetch of a whole selection sends,
  /// so a refresh starts a paged entry over (see [FieldPolicy.pageArgs]).
  @internal
  void mergeFrom(Selection other, {bool firstPages = false}) {
    for (final c in other.children) {
      final mine = firstPages && c._isLaterPage
          ? (child(c.field, c._argsForPage(const {})).._adopt(c))
          : _counterpart(c);
      // A fetch of the field itself, not a fill.
      if (c._policy != null) mine.fillOnly = false;
      mine.mergeFrom(c, firstPages: firstPages);
    }
  }

  /// [ensurePath] for a field read *inside* a cached policy entry: each
  /// policy ancestor for which [pagesOf] returns the pages its entry holds
  /// is branched into one sibling per page (the ancestor itself for an
  /// empty list), created as [fillOnly] — the response only fills what the
  /// entry lacks, for every page it holds, and never resets it. [pagesOf]
  /// returns `null` for an ancestor that is itself being fetched (a page
  /// not cached yet): it is followed as in [ensurePath].
  @internal
  void ensureFillPath(
    Selection other,
    List<Map<String, Object?>>? Function(Selection ancestor) pagesOf,
  ) {
    final chain = <Selection>[];
    Selection? node = other;
    while (node != null && !node.isRoot) {
      chain.insert(0, node);
      node = node.parent;
    }
    var cursors = <Selection>[this];
    for (var i = 0; i < chain.length; i++) {
      final n = chain[i];
      final pages = i < chain.length - 1 && (n._policy?.merges ?? false)
          ? pagesOf(n)
          : null;
      final next = <Selection>[];
      for (final cursor in cursors) {
        if (pages == null) {
          next.add(cursor._counterpart(n));
          continue;
        }
        for (final page in pages.isEmpty ? [null] : pages) {
          final args = page == null ? n.args : n._argsForPage(page);
          final alias = args.isEmpty ? n.field : _aliasFor(n.field, args);
          final existed = cursor._children.containsKey(alias);
          final variant = cursor.child(n.field, args).._adopt(n);
          if (!existed) variant.fillOnly = true;
          next.add(variant);
        }
      }
      cursors = next;
    }
  }

  void _adopt(Selection other) {
    isObject |= other.isObject;
    keyField ??= other.keyField;
    if (other._policyBound) bindPolicy(other._policy);
  }

  /// True if every leaf of [other] is present in this tree.
  @internal
  bool covers(Selection other) {
    for (final c in other.children) {
      final mine = _children[c.alias];
      if (mine == null || !mine.covers(c)) return false;
    }
    return true;
  }

  /// Aliases of the direct children (top-level fields for a root).
  @internal
  Set<String> get childAliases => _children.keys.toSet();

  static String _aliasFor(String field, Map<String, Arg> args) {
    final present = <String, Object?>{
      for (final e in args.entries)
        if (e.value.value != null) e.key: e.value.value,
    };
    if (present.isEmpty) return field;
    final keys = present.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: present[k]});
    return '${field}_${fnv1a64(canonical)}';
  }

  /// 64-bit FNV-1a of [s]'s UTF-16 code units, base 36 (#33: with 32 bits,
  /// a few thousand `launch(id:)` aliases in one app lifetime already had a
  /// ~1% chance of two arg sets silently sharing a cache entry).
  ///
  /// Computed on two 32-bit halves with arithmetic that stays below 2^53, so
  /// it gives the same result on the web (JS numbers, 32-bit bitwise ops) as
  /// on native.
  @internal
  static String fnv1a64(String s) {
    const two32 = 0x100000000;
    // Offset basis 0xcbf29ce484222325, prime 0x100000001b3 = 2^40 + 0x1b3.
    var hi = 0xcbf29ce4, lo = 0x84222325;
    for (final unit in s.codeUnits) {
      // lo ^= unit, on the low 16 bits only (units are < 2^16).
      final low16 = lo % 0x10000;
      lo = lo - low16 + (low16 ^ unit);
      // (hi·2^32 + lo) · (2^40 + 0x1b3) mod 2^64.
      final loProduct = lo * 0x1b3;
      final carry = loProduct ~/ two32;
      final hiProduct = hi * 0x1b3 + carry + (lo % 0x1000000) * 0x100;
      lo = loProduct % two32;
      hi = hiProduct % two32;
    }
    return hi.toRadixString(36) + lo.toRadixString(36).padLeft(7, '0');
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
///
/// A field is printed under its [Selection.alias] (its cache key, unless a
/// policy shares one entry between argument sets — see
/// [Selection.cacheKey]) except
/// when the same alias is selected in two inline fragments of one object, or
/// in a fragment and directly on the object: GraphQL requires fields sharing
/// a response name to have the same shape (FieldsInSetCanMerge), and
/// `... on Launch { status }` (an enum) next to `... on Launchpad { status }`
/// (a `String`) does not. Each fragment occurrence is then printed as
/// `<alias>__<Type>: field`, and [toCacheKeys] maps the response back to the
/// aliases before it is cached, so the entity field is still `status`.
class PrintedOperation {
  PrintedOperation(this.document, this.variables) : _keys = null;

  PrintedOperation._(this.document, this.variables, this._keys);

  final String document;
  final Map<String, Object?> variables;

  /// Response keys that differ from their cache alias, per object; `null`
  /// when the document prints every field under its alias.
  final _ResponseKeys? _keys;

  /// True when some field is printed under a response key other than its
  /// cache alias (see the class comment).
  @internal
  bool get renamesFields => _keys != null;

  /// [data] (a response's `data`, with the document's response keys) with
  /// every renamed key mapped back to its cache alias. Returns [data] itself
  /// when nothing was renamed. Values selected both directly and through a
  /// renamed fragment field are merged.
  @internal
  Map<String, Object?> toCacheKeys(Map<String, Object?> data) {
    final keys = _keys;
    return keys == null ? data : _remapObject(data, keys);
  }

  static Object? _remapValue(Object? value, _ResponseKeys? keys) => keys == null
      ? value
      : switch (value) {
          Map() => _remapObject(value, keys),
          List() => [for (final e in value) _remapValue(e, keys)],
          _ => value,
        };

  static Map<String, Object?> _remapObject(Map data, _ResponseKeys keys) {
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in data.entries) {
      final k = key as String;
      final mapped = keys.fields[k];
      final alias = mapped?.alias ?? k;
      final v = mapped == null ? value : _remapValue(value, mapped.sub);
      if (mapped?.page case final page?) {
        // Every page of a merging policy field goes to its entry, merged
        // there by the cache, in document order.
        final write = switch (out[alias]) {
          final PolicyWrite write => write,
          _ => out[alias] = PolicyWrite(page.policy, page.field),
        };
        write.pages.add((args: page.args, value: v, fill: page.fill));
        continue;
      }
      out[alias] = out.containsKey(alias) ? _merge(out[alias], v) : v;
    }
    return out;
  }

  /// Deep merge of two responses for the same field (one selected directly,
  /// one through a renamed fragment field): same objects, different subsets
  /// of fields.
  static Object? _merge(Object? a, Object? b) {
    if (a is Map && b is Map) {
      final out = <String, Object?>{...a.cast<String, Object?>()};
      for (final MapEntry(:key, :value) in b.entries) {
        final k = key as String;
        out[k] = out.containsKey(k) ? _merge(out[k], value) : value;
      }
      return out;
    }
    if (a is List && b is List && a.length == b.length) {
      return [for (var i = 0; i < a.length; i++) _merge(a[i], b[i])];
    }
    return b ?? a;
  }

  /// Fields inside the fragments of [object] that must be printed under a
  /// type-qualified response key: their alias is also selected directly on
  /// [object] or in another fragment. The key field a keyed fragment prints
  /// and `__typename` are never renamed (the cache needs them verbatim).
  static Map<Selection, String> _fragmentKeys(Selection object) {
    final direct = <String>{'__typename', ?object.keyField};
    final counts = <String, int>{};
    final fields = <(Selection, String)>[];
    var hasFragments = false;
    void walk(Selection node, String? typename) {
      if (typename != null) {
        hasFragments = true;
        if (node.keyField case final k?) counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final c in node.children) {
        if (c.isFragment) {
          walk(c, c.typeCondition);
        } else if (typename == null) {
          direct.add(c.alias);
        } else if (c.field != '__typename' &&
            !(c.field == node.keyField && c.args.isEmpty)) {
          fields.add((c, typename));
          counts[c.alias] = (counts[c.alias] ?? 0) + 1;
        }
      }
    }

    walk(object, null);
    if (!hasFragments) return const {};
    return {
      for (final (c, typename) in fields)
        if (direct.contains(c.alias) || counts[c.alias]! > 1)
          c: '${c.alias}__$typename',
    };
  }

  @internal
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

    final out = StringBuffer();
    late final _ResponseKeys? Function(Selection, int, String) printField;

    _ResponseKeys? printSet(Selection object, int depth) {
      final renames = _fragmentKeys(object);
      _ResponseKeys? keys;

      void body(Selection node, int depth) {
        final indent = '  ' * depth;
        // A fragment's `__typename` is already selected on the object.
        if (!node.isFragment && !node.isRoot) {
          out.writeln('${indent}__typename');
        }
        final keyField = node.keyField;
        if (keyField != null) out.writeln('$indent$keyField');
        for (final c in node.children) {
          // The key field is already printed above; skip a plain duplicate.
          if (c.field == keyField && c.args.isEmpty) continue;
          if (c.isFragment) {
            out.writeln('$indent... on ${c.typeCondition} {');
            body(c, depth + 1);
            if (c.isLeaf && c.keyField == null) {
              out.writeln('$indent  __typename'); // no empty selection sets
            }
            out.writeln('$indent}');
            continue;
          }
          final key = renames[c] ?? c.alias;
          final sub = printField(c, depth, key);
          final policy = c.policy;
          final page = policy != null && policy.merges
              ? (
                  policy: policy,
                  field: c.field,
                  args: c.argValues,
                  fill: c.fillOnly,
                )
              : null;
          if (key != c.cacheKey || sub != null || page != null) {
            (keys ??= _ResponseKeys()).fields[key] = (
              alias: c.cacheKey,
              sub: sub,
              page: page,
            );
          }
        }
      }

      body(object, depth);
      return keys;
    }

    printField = (Selection node, int depth, String key) {
      final indent = '  ' * depth;
      out.write(indent);
      if (key != node.field) out.write('$key: ');
      out.write(node.field);
      final args = node.args.entries.where((e) => e.value.value != null);
      if (args.isNotEmpty) {
        out.write('(');
        out.write(
          args
              .map((e) {
                final name = nameFor(e.key, e.value.value, e.value.graphqlType);
                return '${e.key}: \$$name';
              })
              .join(', '),
        );
        out.write(')');
      }
      if (node.isLeaf && !node.isObject) {
        out.writeln();
        return null;
      }
      out.writeln(' {');
      final sub = printSet(node, depth + 1);
      out.writeln('$indent}');
      return sub;
    };

    final keys = printSet(root, 1);
    final body = out.toString().trimRight();
    final header = varDefs.isEmpty
        ? root.field
        : '${root.field} (${varDefs.join(', ')})';
    return PrintedOperation._('$header {\n$body\n}', variables, keys);
  }
}

/// Response keys of one object's fields that need remapping: renamed ones
/// (see [PrintedOperation]) and object fields with renames further down.
final class _ResponseKeys {
  /// Per response key: the cache key it is stored under, the remapping of
  /// its value, and for a merging policy field the page it is.
  final Map<
    String,
    ({
      String alias,
      _ResponseKeys? sub,
      ({
        FieldPolicy policy,
        String field,
        Map<String, Object?> args,
        bool fill,
      })?
      page,
    })
  >
  fields = {};
}
