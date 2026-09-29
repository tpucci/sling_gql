import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// #28: `MutationState.data` is the last successful result; `mutate` never
/// throws; overlapping calls report the latest one only.
void main() {
  late List<Completer<http.Response>> responses;
  late SlingClient<Query> client;
  late MutationState state;
  late Mutate<Mutation> mutate;

  // Answers `rename` with the requested name once the test completes the
  // request's completer.
  Future<http.Response> handle(http.Request req) {
    final body = jsonDecode(req.body) as Map<String, Object?>;
    final query = body['query'] as String;
    final vars = (body['variables'] as Map).cast<String, Object?>();
    final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
    final c = Completer<http.Response>();
    responses.add(c);
    return c.future.then(
      (ok) => ok.statusCode != 200
          ? ok
          : http.Response(
              jsonEncode({
                'data': {
                  alias: {
                    '__typename': 'User',
                    'id': vars['id'],
                    'name': vars['name'],
                  },
                },
              }),
              200,
            ),
    );
  }

  final ok = http.Response('', 200);
  final down = http.Response('down', 503);

  Future<void> pump(WidgetTester tester) async {
    responses = [];
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: MockClient(handle),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: MutationBuilder<Mutation>(
          builder: (context, m, s) {
            mutate = m;
            state = s;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Future<String?> rename(String name) =>
      mutate<String?>((m) => m.rename(id: '1', name: name)?.name);

  // Lets the mock see the request, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('data is the last successful result, kept while loading', (
    tester,
  ) async {
    await pump(tester);
    expect(state.data, isNull);

    final first = rename('Ada');
    await settle(tester);
    expect(state.isLoading, isTrue);
    responses.single.complete(ok);
    await tester.runAsync(() => first);
    await tester.pump();
    expect(state.isLoading, isFalse);
    expect(state.data, 'Ada');
    expect(await first, 'Ada');

    final second = rename('Bob');
    await settle(tester);
    // No flicker: the previous result stays while the next call is loading.
    expect(state.isLoading, isTrue);
    expect(state.data, 'Ada');
    responses.last.complete(ok);
    await tester.runAsync(() => second);
    await tester.pump();
    expect(state.data, 'Bob');
  });

  testWidgets('a failure resolves mutate to null, sets error, clears data', (
    tester,
  ) async {
    await pump(tester);
    final first = rename('Ada');
    await settle(tester);
    responses.single.complete(ok);
    await tester.runAsync(() => first);

    final failed = rename('Bob');
    await settle(tester);
    responses.last.complete(down);
    // Never throws.
    expect(await tester.runAsync(() => failed), isNull);
    await tester.pump();
    expect(state.isLoading, isFalse);
    expect(state.error, isNotNull);
    expect(state.data, isNull);
  });

  testWidgets('an older call finishing late does not overwrite a newer one', (
    tester,
  ) async {
    await pump(tester);
    final older = rename('Old');
    await settle(tester);
    final newer = rename('New');
    await settle(tester);
    expect(responses, hasLength(2));

    responses[1].complete(ok);
    await tester.runAsync(() => newer);
    await tester.pump();
    expect(state.data, 'New');
    expect(state.isLoading, isFalse);

    responses[0].complete(down);
    // Its own future still reports its own outcome...
    expect(await tester.runAsync(() => older), isNull);
    await tester.pump();
    // ...but the state keeps describing the latest call.
    expect(state.error, isNull);
    expect(state.data, 'New');
  });
}
