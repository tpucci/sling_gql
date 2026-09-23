import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:sling_gql_gen/sling_gql_gen.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('schema', help: 'Path to a GraphQL introspection JSON file.', mandatory: true)
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
    stdout.writeln('Usage: dart run sling_gql_gen --schema <schema.json> --out <file.dart>');
    stdout.writeln(parser.usage);
    return;
  }

  final schemaPath = results['schema'] as String;
  final outPath = results['out'] as String;
  final importPath = results['part-of-import'] as String? ?? 'package:sling_gql/sling_gql.dart';

  final schemaFile = File(schemaPath);
  if (!schemaFile.existsSync()) {
    stderr.writeln('Schema file not found: $schemaPath');
    exitCode = 66;
    return;
  }

  final json = jsonDecode(await schemaFile.readAsString()) as Map<String, Object?>;
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
