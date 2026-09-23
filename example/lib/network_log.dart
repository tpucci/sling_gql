import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

/// Keeps every GraphQL document the client sent, newest first. The whole point
/// of the PoC is to *see* what queries the widgets produce.
class NetworkLog extends ChangeNotifier {
  final List<PrintedOperation> entries = [];

  void add(PrintedOperation op) {
    entries.insert(0, op);
    debugPrint('[sling_gql] request #${entries.length}\n${op.document}\n${op.variables}');
    notifyListeners();
  }

  void clear() {
    entries.clear();
    notifyListeners();
  }
}

class NetworkLogScope extends InheritedNotifier<NetworkLog> {
  const NetworkLogScope({super.key, required NetworkLog log, required super.child})
      : super(notifier: log);

  static NetworkLog of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NetworkLogScope>()!.notifier!;
}

/// Nav-bar button showing the request count; taps open the log.
class NetworkLogButton extends StatelessWidget {
  const NetworkLogButton({super.key});

  @override
  Widget build(BuildContext context) {
    final log = NetworkLogScope.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => const NetworkLogScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 20),
          const SizedBox(width: 4),
          Text('${log.entries.length}'),
        ],
      ),
    );
  }
}

class NetworkLogScreen extends StatelessWidget {
  const NetworkLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = NetworkLogScope.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('${log.entries.length} request(s)'),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: log.entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final op = log.entries[i];
            final n = log.entries.length - i;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$n', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _Code(op.document),
                if (op.variables.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _Code('variables: ${op.variables}'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
        ),
      );
}
