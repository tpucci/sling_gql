import 'package:flutter/widgets.dart';

/// Debug-mode name for a hook's scope: the type of the [HookWidget] calling
/// the hook (`LaunchTile`), without type arguments. `null` in release builds,
/// where type names are minified.
String? debugHookOwnerLabel(BuildContext context) {
  String? label;
  assert(() {
    final name = '${context.widget.runtimeType}';
    final generic = name.indexOf('<');
    label = generic < 0 ? name : name.substring(0, generic);
    return true;
  }());
  return label;
}
