import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

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
          style: const TextStyle(
            color: AppColors.primary,
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

  const ListingTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.requiredField = false,
    this.numeric = false,
    this.maxLines = 1,
    this.suffix,
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
                selectedColor: AppColors.primaryLight,
                side: BorderSide(
                  color: active ? AppColors.primary : AppColors.divider,
                ),
                labelStyle: TextStyle(
                  color:
                      active ? AppColors.primaryDark : AppColors.textSecondary,
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
          color: value ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(
            color: value ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: value ? AppColors.primary : AppColors.divider,
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
