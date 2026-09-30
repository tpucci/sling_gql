import 'package:flutter/cupertino.dart';

import '../theme.dart';
import '../widgets/skeleton.dart';
import 'batching_demo.dart';
import 'caching_demo.dart';
import 'errors_demo.dart';
import 'fetch_policies_demo.dart';
import 'optimistic_demo.dart';
import 'pagination_demo.dart';
import 'prepare_demo.dart';
import 'subscriptions_demo.dart';

/// The concept demos embedded in the website's guides, by name
/// (`?demo=<name>` on the web build). `null` for an unknown name.
Widget? demoFor(String name) => switch (name) {
  'batching' => const BatchingDemo(),
  'fetch-policies' => const FetchPoliciesDemo(),
  'optimistic' => const OptimisticDemo(),
  'prepare' => const PrepareDemo(),
  'errors' => const ErrorsDemo(),
  'pagination' => const PaginationDemo(),
  'caching' => const CachingDemo(),
  'subscriptions' => const SubscriptionsDemo(),
  _ => null,
};

/// The app shell of a single demo.
class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.demo});
  final Widget demo;

  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'sling_gql demo',
    theme: slingTheme(),
    debugShowCheckedModeBanner: false,
    builder: (context, child) => SkeletonShimmer(child: child!),
    home: demo,
  );
}
