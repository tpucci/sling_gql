import 'package:flutter/cupertino.dart';

import '../generated/schema.dart';
import '../screens/launch_screen.dart';
import '../theme.dart';
import 'skeleton.dart';

/// A single row in the launch list, reused by both the Launches and Me tabs.
///
/// All fields are read unconditionally so a single build records every
/// dependency (no waterfall).
class LaunchRow extends StatelessWidget {
  const LaunchRow(this.launch, {super.key});
  final Launch launch;

  @override
  Widget build(BuildContext context) {
    final status = launch.status;
    final date = launch.date;
    final rocketName = launch.rocket?.name;
    // Read here so the row depends on `Launch:<id>.favorite` and rebuilds
    // when the detail screen's mutation updates the entity.
    final favorite = launch.favorite ?? false;

    return CupertinoListTile(
      leading: launch.isSkeleton
          ? const SkeletonBox(width: 28, height: 28)
          : Icon(_statusIcon(status), color: _statusColor(status)),
      title: SkeletonText(launch.name, width: 160),
      subtitle: SkeletonText(
        date == null ? null : '${date.substring(0, 10)} · $rocketName',
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

IconData _statusIcon(LaunchStatus? status) => switch (status) {
      LaunchStatus.success => CupertinoIcons.checkmark_circle_fill,
      LaunchStatus.failure => CupertinoIcons.xmark_circle_fill,
      LaunchStatus.partialFailure =>
        CupertinoIcons.exclamationmark_circle_fill,
      LaunchStatus.scrubbed => CupertinoIcons.pause_circle_fill,
      LaunchStatus.scheduled => CupertinoIcons.clock_fill,
      LaunchStatus.unknown || null => CupertinoIcons.question_circle,
    };

Color _statusColor(LaunchStatus? status) => switch (status) {
      LaunchStatus.success => CupertinoColors.systemGreen,
      LaunchStatus.failure => CupertinoColors.systemRed,
      LaunchStatus.partialFailure => CupertinoColors.systemOrange,
      LaunchStatus.scheduled => CupertinoColors.systemBlue,
      LaunchStatus.scrubbed || LaunchStatus.unknown || null => CupertinoColors.systemGrey,
    };
