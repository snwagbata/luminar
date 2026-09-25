import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:luminar/ui/core/theme.dart';
import 'package:luminar/ui/features/activity_log/view_models/activity_log_view_model.dart';

/// Every PDU and event, for debugging with real bulbs.
class LogScreen extends StatefulWidget {
  final ActivityLogViewModel viewModel;
  const LogScreen({super.key, required this.viewModel});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  ActivityLogViewModel get vm => widget.viewModel;

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.bg,
        title: Text('Activity log', style: display(20)),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: vm.text));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Log copied')));
              }
            },
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: vm.text, subject: 'Luminar log')),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final entries = vm.entries;
          if (entries.isEmpty) {
            return Center(
              child: Text('Nothing yet.', style: TextStyle(color: p.muted)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText(
                entries[i].toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: entries[i].isError ? p.danger : p.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
