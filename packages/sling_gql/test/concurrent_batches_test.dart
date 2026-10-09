import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A transport that answers only when told to, request by request.
class _Manual {
  final List<(String, Completer<http.Response>)> pending = [];

  Future<http.Response> send(http.Request request) {
    final response = Completer<http.Response>();
    pending.add((request.body, response));
    return response.future;
  }

  /// Answers the pending `user` request, or the pending `me` one.
  void answer({required bool user}) {
    final i = pending.indexWhere((p) => p.$1.contains('user(') == user);
    final (_, response) = pending.removeAt(i);
    final data = user
        ? {
            _userAlias: {'__typename': 'User', 'id': 'u', 'name': 'Bob'},
          }
        : {
            'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
          };
    response.complete(http.Response(jsonEncode({'data': data}), 200));
  }

  SlingClient<Query> client() => SlingClient<Query>(
    endpoint: testEndpoint,
    schema: slingSchema,
    transport: send,
    retry: RetryPolicy.none,
  );
}

/// The alias the client gives `user(id: "u")`.
final _userAlias = Selection.root('query')
    .child('user', {'id': Arg('ID!', 'u')})
    .alias;

Future<void> _ticks() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a batch landing does not wake the scopes waiting for another one, '
      'nor make them send their request again', () async {
    final transport = _Manual();
    final client = transport.client();
    final sent = <int>{};
    client.requests.listen((r) => sent.add(r.id));

    final home = client.createScope(onChanged: () {});
    void readHome() => home.run((q) => q.me.name);
    readHome();
    await _ticks();
    transport.answer(user: false);
    await home.whenSettled;

    var cardRebuilds = 0;
    late final QueryScope<Query> card;
    void readCard() => card.run((q) => q.user(id: 'u')?.name);
    card = client.createScope(
      onChanged: () {
        cardRebuilds++;
        readCard();
      },
    );
    readCard();
    await _ticks();
    expect(sent, hasLength(2), reason: 'the card asked for its user');

    unawaited(home.refetch());
    readCard(); // rebuilt in the same frame, its user still missing
    await _ticks();
    expect(
      sent,
      hasLength(3),
      reason: 'the home refetched while the card waits',
    );

    transport.answer(user: false);
    await _ticks();
    expect(cardRebuilds, 0, reason: "the home's batch is not the card's");
    expect(sent, hasLength(3), reason: 'no second request for the same user');

    transport.answer(user: true);
    await card.whenSettled;
    expect(card.run((q) => q.user(id: 'u')?.name), 'Bob');
    expect(sent, hasLength(3));
    expect(client.isIdle, isTrue);
  });

  test('a read covered by any request in flight joins it', () async {
    final transport = _Manual();
    final client = transport.client();
    final sent = <int>{};
    client.requests.listen((r) => sent.add(r.id));

    final first = client.createScope(onChanged: () {});
    first.run((q) => q.user(id: 'u')?.name);
    await _ticks();
    final second = client.createScope(onChanged: () {});
    second.run((q) => q.me.name);
    await _ticks();
    expect(sent, hasLength(2));

    final third = client.createScope(onChanged: () {});
    third.run((q) => q.user(id: 'u')?.name);
    await _ticks();
    expect(sent, hasLength(2), reason: 'the first request already covers it');

    transport.answer(user: true);
    await third.whenSettled;
    expect(third.run((q) => q.user(id: 'u')?.name), 'Bob');
    expect(client.isIdle, isFalse, reason: 'the me request is still out');
    transport.answer(user: false);
    await second.whenSettled;
    expect(client.isIdle, isTrue);
  });
}
