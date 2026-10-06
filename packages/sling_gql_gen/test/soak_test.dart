import 'dart:io';

import 'package:sling_gql_gen/sling_gql_gen.dart';
import 'package:test/test.dart';

import 'soak/soak_introspection.dart';

/// The generator on a large schema (`soak/soak_introspection.dart`: ~200
/// types, ~2 000 fields, 150 lookups, a 150-member interface). Its output
/// is committed as `sling_gql_sqflite/test/soak/soak_schema.dart`, which the
/// runtime soak test compiles and runs on.
void main() {
  final schema = IntrospectionSchema.fromJson(soakIntrospection());

  test('the synthetic schema is large', () {
    final named = schema.types.where((t) => !t.name.startsWith('__'));
    expect(named.length, greaterThanOrEqualTo(200));
    final fields = named.fold<int>(
      0,
      (n, t) => n + t.fields.length + t.inputFields.length,
    );
    expect(fields, greaterThanOrEqualTo(2000));
  });

  test('generates every type, deterministically, in seconds', () {
    final watch = Stopwatch()..start();
    final code = generate(schema);
    final elapsed = watch.elapsed;
    expect(elapsed, lessThan(const Duration(seconds: 5)));
    expect(generate(schema), code, reason: 'same input, same output');

    int count(String pattern) => RegExp(pattern).allMatches(code).length;
    expect(count(r'class Thing\d{3} extends Accessor'), soakThings);
    expect(count(r'enum State\d{2} \{'), soakEnums);
    expect(count(r'class Detail\d{2} extends Accessor'), soakEnums);
    expect(count(r'class Group\d extends Accessor'), soakUnions);
    expect(count(r'class Filter\d \{'), soakInputs);
    expect(count(r"lookup: 'Thing\d{3}'"), soakThings);
    expect(count(r'Thing\d{3}\? get asThing\d{3} =>'), soakThings * 2);
    expect(count(r'  Thing\d{3}\? rename\d{3}\('), soakThings);
    expect(count(r'Thing\d{3}\? thing\d{3}\(String id\) =>'), soakThings);
  });

  test('the committed soak schema is up to date', () async {
    final committed = File(soakSchemaPath);
    expect(committed.existsSync(), isTrue, reason: soakSchemaPath);
    expect(
      await generateSoakSchema(),
      committed.readAsStringSync(),
      reason:
          '$soakSchemaPath is stale: run `melos run generate:soak '
          '--no-select` (or `dart run tool/generate_soak_schema.dart` in '
          'packages/sling_gql_gen)',
    );
  });
}
