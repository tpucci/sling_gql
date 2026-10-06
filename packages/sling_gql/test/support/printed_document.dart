import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// One field of a document printed by `PrintedOperation`: what a test
/// server needs to answer it under the right response key.
class PrintedField {
  PrintedField(this.name, this.key, this.args, {this.typeCondition});

  final String name;

  /// The response key (alias, or the name when unaliased).
  final String key;

  /// Argument name → variable value.
  final Map<String, Object?> args;

  /// Set on an inline fragment (`... on Team`).
  final String? typeCondition;

  final List<PrintedField> children = [];
}

/// Parses the selection of a document `PrintedOperation` printed (one field
/// per line, `alias: field(arg: $var) {`, `... on Type {`, `}`), resolving
/// variables from [variables].
List<PrintedField> parsePrinted(String document, Map<String, Object?> vars) {
  final root = PrintedField('', '', const {});
  final stack = [root];
  final field = RegExp(r'^(?:(\w+): )?(\w+)(?:\((.*)\))?( \{)?$');
  for (final raw in const LineSplitter().convert(document).skip(1)) {
    final line = raw.trim();
    if (line == '}') {
      if (stack.length > 1) stack.removeLast();
      continue;
    }
    if (line.startsWith('... on ')) {
      final f = PrintedField(
        '',
        '',
        const {},
        typeCondition: line.substring(7, line.length - 2),
      );
      stack.last.children.add(f);
      stack.add(f);
      continue;
    }
    final m = field.firstMatch(line)!;
    final args = <String, Object?>{
      for (final a in (m.group(3) ?? '').split(', ').where((a) => a.isNotEmpty))
        a.split(': ')[0]: vars[a.split(': ')[1].substring(1)],
    };
    final f = PrintedField(m.group(2)!, m.group(1) ?? m.group(2)!, args);
    stack.last.children.add(f);
    if (m.group(4) != null) stack.add(f);
  }
  return root.children;
}

/// Answers [fields] from [value]: a map per object (a field's value may be
/// a function of its arguments), lists element by element; fragments apply
/// when `__typename` matches.
Object? project(Object? value, List<PrintedField> fields) {
  if (value is List) return [for (final e in value) project(e, fields)];
  if (value is! Map || fields.isEmpty) return value;
  final out = <String, Object?>{};
  for (final f in fields) {
    if (f.typeCondition != null) {
      if (value['__typename'] == f.typeCondition) {
        out.addAll(project(value, f.children) as Map<String, Object?>);
      }
      continue;
    }
    var v = value[f.name];
    if (v is Function) v = Function.apply(v, [f.args]);
    out[f.key] = project(v, f.children);
  }
  return out;
}

/// A mock endpoint answering every query from [root] (see [project]);
/// [onRequest] sees each document first and may return a response instead
/// (an error, a mutation result).
http.Client printedDocumentServer(
  Map<String, Object?> Function() root, {
  http.Response? Function(String document, Map<String, Object?> vars)?
  onRequest,
  Future<void> Function()? gate,
}) => MockClient((req) async {
  final body = jsonDecode(req.body) as Map<String, Object?>;
  final document = body['query'] as String;
  final vars = (body['variables'] as Map).cast<String, Object?>();
  await gate?.call();
  final custom = onRequest?.call(document, vars);
  if (custom != null) return custom;
  final data = project(root(), parsePrinted(document, vars));
  return http.Response(jsonEncode({'data': data}), 200);
});
