import 'package:flutter/cupertino.dart';

import 'screens/launches_screen.dart';
import 'screens/me_screen.dart';
import 'theme.dart';

/// Root widget — a dark-themed Cupertino app with two tabs:
/// "Launches" and "Me".
///
/// Each tab is a [CupertinoTabView] with its own navigation stack, so opening
/// a launch from the list keeps the tab bar visible and the Me tab's stack
/// untouched. Tabs are built lazily: the Me tab's query runs the first time
/// it is selected, never before (the widget test asserts this).
class SlingApp extends StatelessWidget {
  const SlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'sling_gql',
      theme: slingTheme(),
      home: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.rocket),
              label: 'Launches',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_crop_circle),
              label: 'Me',
            ),
          ],
        ),
        tabBuilder: (context, index) => CupertinoTabView(
          builder: (_) => switch (index) {
            0 => const LaunchesScreen(),
            1 => const MeScreen(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}
