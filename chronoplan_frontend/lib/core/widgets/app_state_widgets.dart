import 'package:flutter/material.dart';

import '../utils/error_message.dart';

class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool scrollable;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return _AppStateLayout(
      scrollable: scrollable,
      icon: icon,
      iconColor: Theme.of(context).colorScheme.primary,
      title: title,
      message: message,
      action: action,
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final String fallback;
  final VoidCallback? onRetry;
  final bool scrollable;

  const AppErrorState({
    super.key,
    required this.title,
    this.error,
    this.fallback = 'Wystąpił błąd',
    this.onRetry,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final message = error == null
        ? fallback
        : AppErrorMessage.from(error!, fallback: fallback);

    return _AppStateLayout(
      scrollable: scrollable,
      icon: Icons.error_outline,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Spróbuj ponownie'),
            ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class AppConstrainedContent extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final CrossAxisAlignment crossAxisAlignment;

  const AppConstrainedContent({
    super.key,
    required this.children,
    this.maxWidth = 920,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      ),
    );
  }
}

class _AppStateLayout extends StatelessWidget {
  final bool scrollable;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  const _AppStateLayout({
    required this.scrollable,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: iconColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );

    if (!scrollable) {
      return Center(child: content);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 72),
      children: [content],
    );
  }
}
