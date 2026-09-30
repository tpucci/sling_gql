import 'package:flutter/cupertino.dart';

import '../generated/schema.dart';
import '../theme.dart';

/// One icon per [LaunchStatus], shared by the list rows and the detail
/// screen so a status change from a subscription looks the same everywhere.
class StatusIcon extends StatelessWidget {
  const StatusIcon(this.status, {super.key, this.size});
  final LaunchStatus? status;
  final double? size;

  @override
  Widget build(BuildContext context) =>
      Icon(statusIcon(status), color: statusColor(status), size: size);
}

/// What the icon means, in words (list rows show it next to the date).
String statusLabel(LaunchStatus? status) => switch (status) {
  LaunchStatus.success => 'Success',
  LaunchStatus.failure => 'Failure',
  LaunchStatus.partialFailure => 'Partial failure',
  LaunchStatus.scrubbed => 'Scrubbed',
  LaunchStatus.scheduled => 'Scheduled',
  LaunchStatus.inFlight => 'In flight',
  LaunchStatus.unknown || null => 'Unknown',
};

IconData statusIcon(LaunchStatus? status) => switch (status) {
  LaunchStatus.success => CupertinoIcons.checkmark_circle_fill,
  LaunchStatus.failure => CupertinoIcons.xmark_circle_fill,
  LaunchStatus.partialFailure => CupertinoIcons.exclamationmark_circle_fill,
  LaunchStatus.scrubbed => CupertinoIcons.pause_circle_fill,
  LaunchStatus.scheduled => CupertinoIcons.clock_fill,
  LaunchStatus.inFlight => CupertinoIcons.rocket_fill,
  LaunchStatus.unknown || null => CupertinoIcons.question_circle,
};

Color statusColor(LaunchStatus? status) => switch (status) {
  LaunchStatus.success => CupertinoColors.systemGreen,
  LaunchStatus.failure => CupertinoColors.systemRed,
  LaunchStatus.partialFailure => CupertinoColors.systemOrange,
  LaunchStatus.scheduled => CupertinoColors.systemBlue,
  LaunchStatus.inFlight => kColorAccent,
  LaunchStatus.scrubbed ||
  LaunchStatus.unknown ||
  null => CupertinoColors.systemGrey,
};
