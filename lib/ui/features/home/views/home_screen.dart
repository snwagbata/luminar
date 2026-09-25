import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';

import 'package:luminar/config/dependencies.dart';
import 'package:luminar/domain/models/connection.dart';
import 'package:luminar/ui/features/add_light/views/add_light_sheet.dart';
import 'package:luminar/ui/features/home/view_models/home_view_model.dart';
import 'package:luminar/ui/features/home/views/light_row.dart';
import 'package:luminar/ui/features/activity_log/views/log_screen.dart';
import 'package:luminar/ui/core/theme.dart';
import 'package:luminar/ui/core/widgets.dart';

class HomeScreen extends StatefulWidget {
  final HomeViewModel viewModel;
  const HomeScreen({super.key, required this.viewModel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeViewModel get c => widget.viewModel;
  int? _open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.lifecycleChanged(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                  children: _children(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _children(BuildContext context) {
    final p = Palette.of(context);
    final ready = c.ready;
    final level = c.allLevel, kelvin = c.allKelvin;
    return [
      Row(
        children: [
          Expanded(child: Text('Luminar', style: display(26))),
          _ConnPill(viewModel: c),
        ],
      ),
      Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            c.status,
            style: TextStyle(color: c.statusIsError ? p.danger : p.muted, fontSize: 14.5),
          ),
        ),
      ),
      if (ready.isNotEmpty) ...[
        const SizedBox(height: 28),
        LampButton(
          onCount: c.onCount,
          total: ready.length,
          glow: kelvinColor(kelvin),
          level: level / 100,
          onTap: c.toggleAll,
        ),
        const SizedBox(height: 20),
        LightSliders(
          level: level,
          kelvin: kelvin,
          showWarmth: ready.any((l) => l.hasCtl),
          onLevel: (v) => c.setAll(level: v),
          onKelvin: (v) => c.setAll(kelvin: v),
        ),
        const SizedBox(height: 12),
        PresetChips(onTap: c.applyPreset),
        if (c.showScenes) _Scenes(viewModel: c),
      ],
      const SizedBox(height: 32),
      Text('Your lights', style: display(19)),
      const SizedBox(height: 8),
      Divider(height: 1, color: p.line),
      if (c.lights.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No lights yet. Tap Add a light to set up your first bulb.',
            style: TextStyle(color: p.muted),
          ),
        ),
      for (final l in c.lights)
        LightRow(
          key: ValueKey(l.addr),
          viewModel: c,
          light: l,
          expanded: _open == l.addr,
          onToggleExpand: () => setState(() => _open = _open == l.addr ? null : l.addr),
        ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: c.busy ? null : () => showAddLightSheet(context, onPicked: c.addLight),
          child: const Text('Add a light'),
        ),
      ),
      const SizedBox(height: 36),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _FootButton('Back up lights', () => _backup(context)),
          _FootButton('Restore from backup', () => _restore(context)),
          _FootButton(
            'Activity log',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    LogScreen(viewModel: context.read<Dependencies>().activityLogViewModel()),
              ),
            ),
          ),
          _FootButton('Start over', () => _startOver(context)),
        ],
      ),
    ];
  }

  Future<void> _backup(BuildContext context) async {
    final code = c.backupCode();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Backup code', style: display(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keep this code somewhere private, like a password manager. It lets you restore your lights on this or another phone, and it also works in the Lamplight web app.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Palette.of(ctx).bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (ctx.mounted) Navigator.pop(ctx);
              c.backupCopied();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: code, subject: 'Luminar backup code')),
            child: const Text('Share'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final text = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore from backup', style: display(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your backup code. This replaces the lights listed here.'),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'LAMPLIGHT1:…',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await c.restore(text.text);
  }

  Future<void> _startOver(BuildContext context) async {
    final ok = await confirm(
      context,
      'Start over?',
      'Luminar forgets all your lights. Each bulb will need a reset before you can add it again.',
      action: 'Start over',
      danger: true,
    );
    if (ok) await c.startOver();
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  required String action,
  bool danger = false,
}) async {
  final p = Palette.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: display(20)),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: TextStyle(color: danger ? p.danger : null)),
        ),
      ],
    ),
  );
  return r == true;
}

class _FootButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FootButton(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: Palette.of(context).muted),
    child: Text(label, style: const TextStyle(decoration: TextDecoration.underline, fontSize: 14)),
  );
}

class _ConnPill extends StatelessWidget {
  final HomeViewModel viewModel;
  const _ConnPill({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = viewModel;
    final (dot, label) = switch (c.connection) {
      Connection.on => (p.on, 'Connected'),
      Connection.connecting => (const Color(0xFFE0A526), 'Connecting'),
      Connection.off => (p.off, 'Connect'),
    };
    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: c.connection == Connection.connecting ? null : c.toggleConnection,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saved scenes: recall with a tap, save the current look, long-press to delete.
class _Scenes extends StatelessWidget {
  final HomeViewModel viewModel;
  const _Scenes({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = viewModel;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scenes', style: display(17)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in c.scenes.entries)
                GestureDetector(
                  onLongPress: () async {
                    if (await confirm(
                      context,
                      'Delete ${e.value}?',
                      'The scene is removed from every light.',
                      action: 'Delete',
                      danger: true,
                    )) {
                      await c.forgetScene(e.key);
                    }
                  },
                  child: ActionChip(
                    onPressed: () => c.recallScene(e.key),
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.line),
                    shape: const StadiumBorder(),
                    label: Text(e.value),
                  ),
                ),
              ActionChip(
                onPressed: () => _save(context),
                avatar: Icon(Icons.add, size: 18, color: p.text),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: p.line),
                shape: const StadiumBorder(),
                label: const Text('Save current'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = TextEditingController(text: 'Scene ${viewModel.scenes.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save scene', style: display(20)),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await viewModel.saveScene(name.text);
  }
}
