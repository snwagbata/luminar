import 'package:flutter/material.dart';

import 'package:luminar/domain/models/light.dart';
import 'package:luminar/ui/features/home/view_models/home_view_model.dart';
import 'package:luminar/ui/features/home/views/home_screen.dart';
import 'package:luminar/ui/core/theme.dart';
import 'package:luminar/ui/core/widgets.dart';

/// One light in the list. Tap to expand its sliders and actions.
class LightRow extends StatelessWidget {
  final HomeViewModel viewModel;
  final Light light;
  final bool expanded;
  final VoidCallback onToggleExpand;
  const LightRow({
    super.key,
    required this.viewModel,
    required this.light,
    required this.expanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = viewModel, l = light;
    final s = c.stateOf(l);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Orb(
                    lit: l.configured && s.on,
                    color: kelvinColor(l.kelvin),
                    level: l.level / 100,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          c.statusLine(l),
                          style: TextStyle(fontSize: 13, color: l.usable ? p.muted : p.danger),
                        ),
                      ],
                    ),
                  ),
                  if (l.wasReset)
                    OutlinedButton(
                      onPressed: c.busy ? null : () => c.setUpAgain(l),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Set up again'),
                    )
                  else if (l.configured)
                    Switch(value: s.on, onChanged: (v) => c.setPower(l, v))
                  else
                    OutlinedButton(
                      onPressed: c.busy ? null : () => c.finishSetup(l),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Finish setup'),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 0, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (l.configured && (l.hasCtl || l.hasLightness))
                          LightSliders(
                            level: l.level,
                            kelvin: l.kelvin,
                            showWarmth: l.hasCtl,
                            onLevel: (v) => c.setLight(l, level: v),
                            onKelvin: (v) => c.setLight(l, kelvin: v),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton(
                              onPressed: () => _rename(context),
                              child: const Text('Rename'),
                            ),
                            if (l.configured && l.has('ctlSetup'))
                              OutlinedButton(
                                onPressed: () => _setDefault(context),
                                child: const Text('Use as default'),
                              ),
                            OutlinedButton(
                              onPressed: () => _remove(context),
                              style: OutlinedButton.styleFrom(foregroundColor: p.danger),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final t = TextEditingController(text: light.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Name this light', style: display(20)),
        content: TextField(
          controller: t,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) await viewModel.rename(light, t.text);
  }

  Future<void> _setDefault(BuildContext context) => viewModel.useAsDefault(light);

  Future<void> _remove(BuildContext context) async {
    final c = viewModel;
    final ok = await confirm(
      context,
      'Remove ${light.name}?',
      c.isConnected ? 'The bulb will be reset so it can be added again later.' : 'Luminar is not connected, so the bulb keeps its setup. Reset it afterwards (five quick off/on cycles) if you want to add it again.',
      action: 'Remove',
      danger: true,
    );
    if (ok) await c.remove(light);
  }
}
