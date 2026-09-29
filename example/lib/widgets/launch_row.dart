import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../date_format.dart';
import '../generated/schema.dart';
import '../screens/launch_screen.dart';
import '../theme.dart';
import 'skeleton.dart';
import 'status_icon.dart';

/// A single row in the launch list, reused by both the Launches and Me tabs.
///
/// All fields are read unconditionally so a single build records every
/// dependency (no waterfall).
///
/// The row is a [SlingRow]: its reads are fetched in the list's request, but
/// they are *its* dependencies — favouriting one launch (or a live status
/// event) rebuilds that row only, not the whole list.
class LaunchRow extends StatelessWidget {
  const LaunchRow(this.launch, {super.key});
  final Launch launch;

  @override
  Widget build(BuildContext context) =>
      SlingRow(launch, ctor: Launch.new, builder: _build);

  Widget _build(BuildContext context, Launch launch) {
    final status = launch.status;
    final date = launch.date;
    final rocketName = launch.rocket?.name;
    // Read here so the row depends on `Launch:<id>.favorite` and rebuilds
    // when the detail screen's mutation updates the entity.
    final favorite = launch.favorite ?? false;

    return CupertinoListTile(
      leading: launch.isSkeleton
          ? const SkeletonBox(width: 28, height: 28)
          : StatusIcon(status),
      title: SkeletonText(launch.name, width: 160),
      subtitle: SkeletonText(
        date == null ? null : '${formatDate(date)} · $rocketName',
        width: 200,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (favorite)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                CupertinoIcons.heart_fill,
                color: kColorCoral,
                size: 18,
              ),
            ),
          const CupertinoListTileChevron(),
        ],
      ),
      onTap: launch.id == null
          ? null
          : () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => LaunchScreen(id: launch.id!),
              ),
            ),
    );
  }
}
