import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql_gen/sling_gql_gen.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('schema', help: 'Path to a GraphQL introspection JSON file.')
    ..addOption('endpoint', help: 'GraphQL endpoint URL to introspect instead of --schema.')
    ..addMultiOption('header', abbr: 'H', help: 'HTTP header for --endpoint, e.g. "Authorization: Bearer x".')
    ..addOption('out', help: 'Path of the Dart file to generate.', mandatory: true)
    ..addOption(
      'part-of-import',
      help: 'Override the sling_gql import '
          '(default: package:sling_gql/sling_gql.dart).',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (results['help'] as bool) {
    stdout.writeln('Usage: dart run sling_gql_gen (--schema <schema.json> | --endpoint <url>) --out <file.dart>');
    stdout.writeln(parser.usage);
    return;
  }

  final schemaPath = results['schema'] as String?;
  final endpoint = results['endpoint'] as String?;
  final outPath = results['out'] as String;
  final importPath = results['part-of-import'] as String? ?? 'package:sling_gql/sling_gql.dart';

  if ((schemaPath == null) == (endpoint == null)) {
    stderr.writeln('Pass exactly one of --schema or --endpoint.');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final Map<String, Object?> json;
  if (schemaPath != null) {
    final schemaFile = File(schemaPath);
    if (!schemaFile.existsSync()) {
      stderr.writeln('Schema file not found: $schemaPath');
      exitCode = 66;
      return;
    }
    json = jsonDecode(await schemaFile.readAsString()) as Map<String, Object?>;
  } else {
    final headers = {
      'content-type': 'application/json',
      for (final h in results['header'] as List<String>)
        h.substring(0, h.indexOf(':')).trim(): h.substring(h.indexOf(':') + 1).trim(),
    };
    final response = await http.post(
      Uri.parse(endpoint!),
      headers: headers,
      body: jsonEncode({'query': introspectionQuery}),
    );
    if (response.statusCode >= 400) {
      stderr.writeln('Introspection failed: HTTP ${response.statusCode}\n${response.body}');
      exitCode = 69;
      return;
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final data = body['data'] as Map<String, Object?>?;
    if (data == null) {
      stderr.writeln('Introspection failed: ${body['errors']}');
      exitCode = 69;
      return;
    }
    json = data;
    stdout.writeln('Introspected $endpoint');
  }
  final schema = IntrospectionSchema.fromJson(json);
  final code = generate(schema, importPath: importPath);

  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(code);
  stdout.writeln('Generated $outPath');

  try {
    final result = await Process.run('dart', ['format', outFile.path]);
    if (result.exitCode != 0) {
      stderr.writeln('dart format exited with ${result.exitCode} (output left unformatted):');
      stderr.writeln(result.stderr);
    }
  } on ProcessException catch (e) {
    stderr.writeln('Could not run `dart format` (output left unformatted): $e');
  }
}
