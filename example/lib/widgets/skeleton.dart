import 'package:flutter/cupertino.dart';

import '../theme.dart';

/// One shimmer for every placeholder below it: a highlight sweeping across
/// all [SkeletonBox]es in sync, driven by a single animation. It only runs
/// while at least one box is on screen, and not at all when the platform asks
/// for reduced motion. Without one above them, boxes are simply static.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int _boxes = 0;

  void _acquire() {
    if (_boxes++ == 0) _controller.repeat();
  }

  void _release() {
    if (--_boxes == 0) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShimmerScope(state: this, child: widget.child);
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.state, required super.child});
  final _SkeletonShimmerState state;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.state != state;
}

const _base = kColorSurface;
const _highlight = Color(0xFF2B3149);

/// A placeholder shape: a rounded bar (text), a circle (an icon), or any
/// box. Shimmers when a [SkeletonShimmer] is above it.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
    this.circle = false,
  });

  /// A circle of [size], where an icon or avatar will be.
  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = null,
      circle = true;

  final double width;
  final double height;

  /// Corner radius; half the height (a pill) by default.
  final double? radius;
  final bool circle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> {
  _SkeletonShimmerState? _shimmer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shimmer = reduceMotion
        ? null
        : context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.state;
    if (shimmer != _shimmer) {
      _shimmer?._release();
      _shimmer = shimmer?.._acquire();
    }
  }

  @override
  void dispose() {
    _shimmer?._release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = BoxDecoration(
      shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: widget.circle
          ? null
          : BorderRadius.circular(widget.radius ?? widget.height / 2),
    );
    final shimmer = _shimmer;
    if (shimmer == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: shape.copyWith(color: _base),
      );
    }
    return AnimatedBuilder(
      animation: shimmer._controller,
      builder: (context, _) {
        // The highlight band travels from left of the box to right of it;
        // every box shares the same phase, so they sweep together.
        final t = shimmer._controller.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: shape.copyWith(
            gradient: LinearGradient(
              colors: const [_base, _highlight, _base],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Renders [text], or a text-shaped placeholder when it is `null`.
///
/// This is the whole "loading state" story: a missing value is `null`,
/// nothing else to wire. The bar takes the height of a line of [style] (so
/// content does not jump when it arrives) and the text fades in over it.
class SkeletonText extends StatelessWidget {
  const SkeletonText(
    this.text, {
    super.key,
    required this.width,
    this.style,
    this.maxLines = 2,
  });
  final String? text;
  final double width;
  final TextStyle? style;

  /// `null` for no limit.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final Widget child;
    if (text == null) {
      final resolved = DefaultTextStyle.of(context).style.merge(style);
      final fontSize = resolved.fontSize ?? 15;
      final lineHeight = fontSize * (resolved.height ?? 1.3);
      final bar = fontSize * 0.75;
      child = Padding(
        key: const ValueKey('skeleton'),
        padding: EdgeInsets.symmetric(vertical: (lineHeight - bar) / 2),
        child: SkeletonBox(width: width, height: bar),
      );
    } else {
      child = Text(
        text,
        key: const ValueKey('text'),
        style: style,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

/// A width between 70 % and 115 % of [base], stable per [seed]: placeholder
/// rows of a list do not all look the same.
double variedWidth(double base, int seed) =>
    base * (0.7 + ((seed * 7 + 3) % 10) / 20);
