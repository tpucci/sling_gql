import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import 'launch_screen.dart';

/// Mission control: schedule a launch, then watch it fly.
///
/// The form's pickers are a [QueryBuilder] like any other (`rockets`,
/// `launchpads` — one request, cached for next time). Submitting runs the
/// `scheduleLaunch` mutation; the mock server then runs the launch sequence
/// on its own (`SCHEDULED → IN_FLIGHT → SUCCESS | FAILURE`, a few seconds
/// apart), publishing `launchStatusChanged` at each step.
///
/// Submitting lands on the launch's detail screen, whose status icon follows
/// the sequence. Back on the list:
/// - the new row appears at the top through the `launchScheduled`
///   subscription event — the list's `_LiveList` prepends it with
///   `cacheScope.list(...)`, not the mutation response;
/// - its status icon then changes on its own (clock → rocket → ✓/✗) as
///   `launchStatusChanged` events are normalized into `Launch:<id>`;
/// - the network log shows the one mutation and nothing after it.
///
/// A name containing "fail" makes the mock fail the launch; the dice button
/// rolls another mission name.
class ScheduleLaunchScreen extends StatefulWidget {
  const ScheduleLaunchScreen({super.key});

  @override
  State<ScheduleLaunchScreen> createState() => _ScheduleLaunchScreenState();
}

/// Mission names, rolled at random. One in five is doomed ("fail").
const _adjectives = [
  'Wobbly',
  'Caffeinated',
  'Majestic',
  'Reluctant',
  'Turbo',
  'Sleepy',
  'Glorious',
  'Suspicious',
  'Overconfident',
  'Tiny',
  'Heroic',
  'Nervous',
];
const _nouns = [
  'Pigeon',
  'Toaster',
  'Llama',
  'Hamster',
  'Teapot',
  'Walrus',
  'Cactus',
  'Sandwich',
  'Penguin',
  'Kazoo',
  'Otter',
  'Waffle',
];
const _doomed = ['(will fail)', '— probably fails', '[FAIL SAFE OFF]'];

String randomMissionName([Random? random]) {
  final r = random ?? Random();
  final name =
      '${_adjectives[r.nextInt(_adjectives.length)]} '
      '${_nouns[r.nextInt(_nouns.length)]} ${r.nextInt(90) + 10}';
  return r.nextInt(5) == 0
      ? '$name ${_doomed[r.nextInt(_doomed.length)]}'
      : name;
}

class _ScheduleLaunchScreenState extends State<ScheduleLaunchScreen> {
  final _name = TextEditingController(text: randomMissionName());
  String? _rocketId;
  String? _launchpadId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Schedule a launch'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: QueryBuilder<Query>(
          builder: (context, query, state) {
            // Read everything first (see LaunchesScreen for why).
            // Read `id` *and* `name` of every row before any branching: a
            // skeleton row has a null id, and a `name` read only behind
            // `if (id != null)` would be a second round trip (the test
            // asserts one request here; the dev-mode warning names it).
            final rockets = [
              for (final r in query.rockets ?? const <Rocket>[])
                (id: r.id, name: r.name),
            ];
            final launchpads = [
              for (final p in query.launchpads ?? const <Launchpad>[])
                (id: p.id, name: p.name),
            ];
            final rocketOptions = {
              for (final r in rockets)
                if (r.id != null) r.id!: r.name ?? '…',
            };
            final padOptions = {
              for (final p in launchpads)
                if (p.id != null) p.id!: p.name ?? '…',
            };
            if (state.error != null) {
              return ErrorView(error: state.error!, onRetry: state.refetch);
            }
            final rocketId = _rocketId ?? rocketOptions.keys.firstOrNull;
            final launchpadId = _launchpadId ?? padOptions.keys.firstOrNull;
            final ready =
                !state.hasMissingData &&
                rocketId != null &&
                launchpadId != null;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Label('Mission name'),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        key: const ValueKey('schedule-name'),
                        controller: _name,
                        placeholder: 'Put "fail" in the name to crash it',
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('schedule-reroll'),
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: () => _name.text = randomMissionName(),
                      child: const Icon(CupertinoIcons.shuffle),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('Rocket'),
                _Picker(
                  options: rocketOptions,
                  value: rocketId,
                  onChanged: (v) => setState(() => _rocketId = v),
                ),
                const SizedBox(height: 16),
                const _Label('Launchpad'),
                _Picker(
                  options: padOptions,
                  value: launchpadId,
                  onChanged: (v) => setState(() => _launchpadId = v),
                ),
                const SizedBox(height: 32),
                MutationBuilder<Mutation>(
                  builder: (context, mutate, mutation) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CupertinoButton.filled(
                        key: const ValueKey('schedule-submit'),
                        onPressed: !ready || mutation.isLoading
                            ? null
                            : () async {
                                // Built once, outside the body: the body
                                // runs twice (record, then read the
                                // response from the cache) and its
                                // arguments are the cache key — a fresh
                                // `DateTime.now()` per run would never
                                // find what the first run sent.
                                final input = ScheduleLaunchInput(
                                  name: _name.text.trim(),
                                  rocketId: rocketId,
                                  launchpadId: launchpadId,
                                  // Ahead of every seeded launch, so
                                  // DATE_DESC puts it on top.
                                  date: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                final id = await mutate(
                                  (m) => m.scheduleLaunch(input: input)?.id,
                                );
                                // Straight to the launch: the detail
                                // screen reads the same Launch:<id> entity
                                // the sequence events are written into.
                                if (id != null && context.mounted) {
                                  Navigator.of(context).pushReplacement(
                                    CupertinoPageRoute<void>(
                                      builder: (_) => LaunchScreen(id: id),
                                    ),
                                  );
                                }
                              },
                        child: mutation.isLoading
                            ? const CupertinoActivityIndicator()
                            : const Text('Schedule & watch it fly'),
                      ),
                      if (mutation.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${mutation.error}',
                            style: const TextStyle(color: kColorCoral),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your launch appears at the top of the list, lifts off a '
                  'few seconds later and lands on its own (put "fail" in the '
                  'name to see one fail). Nothing refreshes: the server tells '
                  'the app as it happens.',
                  style: TextStyle(color: kColorTextSecondary, fontSize: 13),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: kColorTextSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// A row of choice chips; enough for a handful of rockets and pads.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in options.entries)
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          color: e.key == value ? kColorAccent : kColorSurface,
          onPressed: () => onChanged(e.key),
          child: Text(
            e.value,
            style: TextStyle(
              fontSize: 13,
              color: e.key == value ? kColorBackground : kColorTextPrimary,
            ),
          ),
        ),
    ],
  );
}
