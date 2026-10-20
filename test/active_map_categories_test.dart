import 'package:flutter_test/flutter_test.dart';
import 'package:andi_carpeta/map/active_map_categories.dart';

class _Category {
  const _Category(this.name, this.active);

  final String name;
  final bool active;
}

void main() {
  group('activeMapCategoriesSorted', () {
    test('filters inactive entries and sorts names without case sensitivity', () {
      const categories = <_Category>[
        _Category('zebra', true),
        _Category('Alpha', true),
        _Category('hidden', false),
        _Category('beta', true),
      ];

      final result = activeMapCategoriesSorted(
        categories,
        isActive: (category) => category.active,
        nameOf: (category) => category.name,
      );

      expect(result.map((category) => category.name), ['Alpha', 'beta', 'zebra']);
      expect(categories.map((category) => category.name),
          ['zebra', 'Alpha', 'hidden', 'beta']);
    });

    test('returns an empty list when no category is active', () {
      final result = activeMapCategoriesSorted(
        const <_Category>[_Category('hidden', false)],
        isActive: (category) => category.active,
        nameOf: (category) => category.name,
      );

      expect(result, isEmpty);
    });
  });
}
