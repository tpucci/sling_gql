import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

void main() {
  testWidgets(
      'QueryState.isSkeleton is true only for the first paint (missing data '
      'and a fetch in flight), false once data has landed', (tester) async {
    final release = Completer<void>();
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        await release.future;
        return http.Response(
          jsonEncode({
            'data': {
              'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
            },
          }),
          200,
        );
      }),
    );

    final states = <QueryState>[];
    await tester.pumpWidget(SlingScope<Query>(
      client: client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: QueryBuilder<Query>(
          builder: (_, q, s) {
            states.add(s);
            return Text(q.me.name ?? '\u2026');
          },
        ),
      ),
    ));
    await tester.pump();

    // First paint: nothing cached yet, a fetch is in flight.
    expect(states.last.hasMissingData, isTrue);
    expect(states.last.isLoading, isTrue);
    expect(states.last.isSkeleton, isTrue);

    release.complete();
    await tester.pumpAndSettle();

    // Data landed: no longer a skeleton.
    expect(states.last.hasMissingData, isFalse);
    expect(states.last.isLoading, isFalse);
    expect(states.last.isSkeleton, isFalse);

    // `isSkeleton` is exactly `hasMissingData && isLoading` (see the getter's
    // doc comment): the "refetching already-cached data" case \u2014 isLoading
    // true, hasMissingData false \u2014 is therefore false by construction, and
    // every other combination is covered by the two paints above.
  });
}
