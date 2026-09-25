import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:luminar/config/dependencies.dart';
import 'package:luminar/domain/models/nearby_bulb.dart';
import 'package:luminar/ui/core/theme.dart';
import 'package:luminar/ui/features/add_light/view_models/add_light_view_model.dart';

/// Lists bulbs ready to add; [onPicked] runs once the sheet has closed.
Future<void> showAddLightSheet(
  BuildContext context, {
  required Future<bool> Function(NearbyBulb bulb) onPicked,
}) async {
  final vm = context.read<Dependencies>().addLightViewModel();
  final picked = await showModalBottomSheet<NearbyBulb>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddLightSheet(viewModel: vm),
  );
  await vm.stop();
  vm.dispose();
  if (picked != null) await onPicked(picked);
}

class _AddLightSheet extends StatefulWidget {
  final AddLightViewModel viewModel;
  const _AddLightSheet({required this.viewModel});
  @override
  State<_AddLightSheet> createState() => _AddLightSheetState();
}

class _AddLightSheetState extends State<_AddLightSheet> {
  AddLightViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.scan();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: vm, builder: _build);

  Widget _build(BuildContext context, Widget? _) {
    final p = Palette.of(context);
    final scanning = vm.scanning, error = vm.error, found = vm.found;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a light', style: display(22)),
              const SizedBox(height: 10),
              const Text(
                'First reset the bulb: with it on, turn it off and on five times quickly until it flashes.',
              ),
              const SizedBox(height: 6),
              const Text('Then pick it below. It blinks while it is being set up.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    scanning ? 'Looking for bulbs…' : 'Bulbs ready to add',
                    style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (scanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(onPressed: vm.scan, child: const Text('Scan again')),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error, style: TextStyle(color: p.danger)),
                ),
              if (found.isEmpty && error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    scanning
                        ? 'Nothing yet. Keep the phone near the bulb.'
                        : 'No bulbs found. Reset the bulb and scan again.',
                    style: TextStyle(color: p.muted),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final b in found)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lightbulb_outline, color: p.text),
                        title: Text(
                          AddLightViewModel.title(b),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          AddLightViewModel.subtitle(b),
                          style: TextStyle(color: p.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, b),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
