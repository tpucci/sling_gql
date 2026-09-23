import 'package:flutter/cupertino.dart';

/// Grey box placeholder, used while the accessor returns `null` for a field
/// that has not been fetched yet.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey4.resolveFrom(context),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// Renders [text], or a skeleton box of [width] when `null`.
///
/// This is the whole "loading state" story: a missing value is `null`,
/// nothing else to wire.
class SkeletonText extends StatelessWidget {
  const SkeletonText(this.text, {super.key, required this.width, this.style});
  final String? text;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    if (text == null) {
      final fontSize = style?.fontSize ?? 15;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: fontSize * 0.15),
        child: SkeletonBox(width: width, height: fontSize),
      );
    }
    return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
  }
}
