import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers.dart';
import 'theme.dart';

/// Follow system / light / dark, applied immediately and remembered.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.love,
        selectedForegroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 44),
      ),
      segments: const [
        ButtonSegment(value: ThemeMode.system, icon: Icon(Symbols.brightness_auto_rounded), label: Text('Sistem')),
        ButtonSegment(value: ThemeMode.light, icon: Icon(Symbols.light_mode_rounded), label: Text('Terang')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Symbols.dark_mode_rounded), label: Text('Gelap')),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => ref.read(themeModeProvider.notifier).set(selection.first),
    );
  }
}

Future<void> showThemePicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Tampilan', style: displayText(20, color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Pilih mode terang atau gelap, atau ikuti pengaturan HP.',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const ThemeModeSelector(),
            ]),
          ),
        );
      },
    );
