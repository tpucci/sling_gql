import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sling_gql/internal.dart' show debugOwnerLabel;

/// Debug-mode name for a hook's scope: the type of the [HookWidget] calling
/// the hook (`LaunchTile`), without type arguments — or, inside a
/// [HookBuilder], the enclosing app widget like the builders'
/// `debugOwnerLabel`. `null` in release builds, where type names are
/// minified.
String? debugHookOwnerLabel(BuildContext context) {
  String? label;
  assert(() {
    if (context.widget is HookBuilder) {
      label = debugOwnerLabel(context);
      return true;
    }
    final name = '${context.widget.runtimeType}';
    final generic = name.indexOf('<');
    label = generic < 0 ? name : name.substring(0, generic);
    return true;
  }());
  return label;
}
