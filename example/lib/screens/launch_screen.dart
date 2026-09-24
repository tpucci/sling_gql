import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../widgets/skeleton.dart';

/// Launch detail.
///
/// - `prepare` selects everything the screen will need up front (including
///   the collapsed payload section), so opening it later costs no request.
/// - `name`/`date`/`status`/`rocket.name` are NOT fetched again: the list
///   already wrote `Launch:<id>` and `Rocket:<id>` entities, and `launch(id:)`
///   is a `lookup` field that resolves straight to the entity. Only the fields
///   the list never selected go over the wire (open the network log).
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, required this.id});
  final String id;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  bool _showPayloads = false;

  /// Reusable selection ("fragment").
  static void prepare(Launch launch) {
    launch
      ..name
      ..date
      ..status
      ..details
      ..flightNumber;
    launch.rocket
      ?..name
      ..description
      ..height?.meters
      ..mass?.kg
      ..successRatePct;
    launch.launchpad
      ?..fullName
      ..locality;
    for (final p in launch.payloads ?? const <Payload>[]) {
      p
        ..name
        ..type$
        ..orbit
        ..massKg
        ..customers;
    }
    for (final a in launch.crew ?? const <Astronaut>[]) {
      a
        ..name
        ..agency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Launch'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: QueryBuilder<Query>(
          prepare: (query) {
            final launch = query.launch(id: widget.id);
            if (launch != null) prepare(launch);
          },
          builder: (context, query, state) {
            final launch = query.launch(id: widget.id);
            if (launch == null) return const Center(child: Text('Not found'));
            final rocket = launch.rocket;
            final crew = launch.crew ?? const <Astronaut>[];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SkeletonText(
                  launch.name,
                  width: 220,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SkeletonText(
                  launch.date?.let((d) => 'Flight #${launch.flightNumber} · $d · ${launch.status}'),
                  width: 260,
                  style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (launch.isSkeleton || launch.details != null)
                  SkeletonText(launch.details, width: double.infinity),
                const SizedBox(height: 24),
                const _Section('Rocket'),
                _Row('Name', rocket?.name),
                SkeletonText(rocket?.description, width: double.infinity),
                _Row('Height', rocket?.height?.meters?.let((v) => '$v m')),
                _Row('Mass', rocket?.mass?.kg?.let((v) => '$v kg')),
                _Row('Success rate', rocket?.successRatePct?.let((v) => '$v %')),
                const SizedBox(height: 24),
                const _Section('Launchpad'),
                _Row('Site', launch.launchpad?.fullName),
                _Row('Locality', launch.launchpad?.locality),
                if (crew.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _Section('Crew'),
                  for (final a in crew) _Row(a.agency, a.name),
                ],
                const SizedBox(height: 24),
                CupertinoButton(
                  onPressed: () => setState(() => _showPayloads = !_showPayloads),
                  child: Text(
                    '${_showPayloads ? 'Hide' : 'Show'} payloads '
                    '(${launch.payloads?.length ?? '…'}) — no request, thanks to prepare',
                  ),
                ),
                if (_showPayloads)
                  for (final p in launch.payloads ?? const <Payload>[])
                    CupertinoListTile(
                      title: Text(p.name ?? '…'),
                      subtitle: Text(
                        '${p.type$} · ${p.orbit} · ${p.massKg ?? '?'} kg · '
                        '${p.customers?.join(', ')}',
                      ),
                    ),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CupertinoActivityIndicator(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String? label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: SkeletonText(
                label,
                width: 60,
                style: const TextStyle(color: CupertinoColors.systemGrey),
              ),
            ),
            Expanded(child: SkeletonText(value, width: 140)),
          ],
        ),
      );
}

extension<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}
