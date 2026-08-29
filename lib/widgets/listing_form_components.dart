import 'package:flutter/material.dart';
import 'package:house_rent/widgets/glass_surface.dart';

class ListingQualityGuide extends StatelessWidget {
  final int score;
  final List<String> improvements;

  const ListingQualityGuide({
    super.key,
    required this.score,
    required this.improvements,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strong = score >= 80;
    return ListingSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: strong ? colors.primary : colors.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text('$score',
                style: TextStyle(
                    color:
                        strong ? colors.onPrimary : colors.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated listing quality',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                improvements.isEmpty
                    ? 'Excellent—every quality signal is complete.'
                    : 'Complete these suggestions to improve visibility.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ]),
        if (improvements.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...improvements.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_circle_up_rounded,
                          size: 17, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(item,
                              style: Theme.of(context).textTheme.bodySmall)),
                    ]),
              )),
        ],
        const SizedBox(height: 4),
        Text('Each completed quality signal adds 14 points.',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.onSurfaceVariant)),
      ]),
    );
  }
}

class ListingSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;

  const ListingSectionHeader({
    Key? key,
    required this.eyebrow,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class ListingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool requiredField;
  final bool numeric;
  final int maxLines;
  final String? suffix;
  final bool enabled;

  const ListingTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.requiredField = false,
    this.numeric = false,
    this.maxLines = 1,
    this.suffix,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label${requiredField ? ' *' : ''}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: false)
                : maxLines > 1
                    ? TextInputType.multiline
                    : TextInputType.text,
            maxLines: maxLines,
            textInputAction:
                maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            decoration: InputDecoration(
              hintText: hint,
              suffixText: suffix,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (requiredField && text.isEmpty) return '$label is required';
              if (numeric && text.isNotEmpty) {
                final number = int.tryParse(text);
                if (number == null || number < 0) {
                  return 'Enter a valid non-negative number';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class ListingChoice extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const ListingChoice({
    Key? key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final active = option == selected;
              return ChoiceChip(
                label: Text(option),
                selected: active,
                onSelected: (_) => onChanged(option),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: active
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class AmenityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AmenityTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
            color: value
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class ListingSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ListingSurface({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MediaPreparationIndicator extends StatelessWidget {
  final double progress;

  const MediaPreparationIndicator({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = progress.clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.movie_filter_outlined, color: colors.primary, size: 20),
          const SizedBox(width: 9),
          const Expanded(
            child: Text('Preparing video',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('${(value * 100).round()}%',
              style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value > 0 ? value : null,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 7),
        Text('Optimizing only when needed while keeping the clearest version.',
            style: TextStyle(
                color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                fontSize: 11.5)),
      ]),
    );
  }
}
