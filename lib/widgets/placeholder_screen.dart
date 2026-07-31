import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Temporary screen scaffold used by the skeleton. Replace each usage with the
/// real screen (see ТЗ §6.3). Demonstrates reading theme + role correctly.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.showAppBar = true,
  });

  final String title;
  final String? subtitle;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final role = ref.watch(roleThemeProvider);

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title, style: Theme.of(context).textTheme.headlineMedium),
              backgroundColor: c.surface,
            )
          : null,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(role.icon, size: 40, color: role.iconAccent),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 6),
            Text('TODO: реализовать по ТЗ §6.3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}
