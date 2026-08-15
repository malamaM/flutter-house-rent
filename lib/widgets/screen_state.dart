import 'package:flutter/material.dart';

class ScreenState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ScreenState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 30),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                    onPressed: onAction, child: Text(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PropertyListSkeleton extends StatelessWidget {
  const PropertyListSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => Container(
        height: 138,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
