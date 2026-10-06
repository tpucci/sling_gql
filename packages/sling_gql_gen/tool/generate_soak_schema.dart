// Regenerates `packages/sling_gql_sqflite/test/soak/soak_schema.dart` from
// the synthetic schema in `test/soak/soak_introspection.dart`:
//
//   dart run tool/generate_soak_schema.dart   (in packages/sling_gql_gen)
//   melos run generate:soak --no-select       (from the repo root)
//
// `test/soak_test.dart` fails when the committed file is stale.
import 'dart:io';

import '../test/soak/soak_introspection.dart';

Future<void> main() async {
  final out = File(soakSchemaPath);
  await out.parent.create(recursive: true);
  await out.writeAsString(await generateSoakSchema());
  stdout.writeln('Generated ${out.path}');
}
