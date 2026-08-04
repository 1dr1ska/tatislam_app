import 'package:flutter/material.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';

/// A predefined background image option.
class BackgroundOption {
  final String label;
  final String assetPath;

  const BackgroundOption({required this.label, required this.assetPath});
}

/// Predefined list of available background images.
const List<BackgroundOption> backgroundOptions = [
  BackgroundOption(
    label: 'Здание',
    assetPath: 'assets/images/backgrounds/building.png',
  ),
  BackgroundOption(
    label: 'Горы',
    assetPath: 'assets/images/backgrounds/mountains.png',
  ),
  BackgroundOption(
    label: 'Лес',
    assetPath: 'assets/images/backgrounds/forest.png',
  ),
  BackgroundOption(
    label: 'Библиотека',
    assetPath: 'assets/images/backgrounds/library.png',
  ),
  BackgroundOption(
    label: 'Ночное небо',
    assetPath: 'assets/images/backgrounds/night_sky.png',
  ),
];

/// A selector widget with previews for choosing a background image.
///
/// [value] — the currently selected asset path, or null for none.
/// [onChanged] — called when a new option is selected (null means no background).
class BackgroundSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const BackgroundSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фоновое изображение',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        // "None" option
        _buildOption(
          context: context,
          option: null,
          label: 'Нет (фон по умолчанию)',
          selected: value == null,
        ),
        const SizedBox(height: 8),
        // All background options
        ...backgroundOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildOption(
              context: context,
              option: option,
              label: option.label,
              selected: value == option.assetPath,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required BackgroundOption? option,
    required String label,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => onChanged(option?.assetPath),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Preview image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(11),
              ),
              child: SizedBox(
                width: 80,
                height: 56,
                child: option != null
                    ? Image.asset(
                        option.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.image_not_supported, size: 24),
                            ),
                      )
                    : const Center(
                        child: Icon(Icons.do_not_disturb_alt, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Radio indicator
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
