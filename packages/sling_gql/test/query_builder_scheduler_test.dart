import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

void main() {
  testWidgets('QueryBuilder flushes through its scheduler', (tester) async {
    var requests = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        requests++;
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

    final pending = <void Function()>[];
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: QueryBuilder<Query>(
            scheduler: pending.add,
            builder: (_, q, s) => Text(q.me.name ?? '\u2026'),
          ),
        ),
      ),
    );
    // Frames pass, but nothing is sent until the scheduler runs the flush.
    await tester.pump();
    await tester.pump();
    expect(pending, hasLength(1));
    expect(requests, 0);

    await tester.runAsync(() async {
      pending.single();
      await client.whenIdle;
    });
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Ada'), findsOneWidget);
  });
}
