import 'package:flutter/material.dart';

import '../models/app_data_models.dart';
import '../models/location_category_helpers.dart';
import '../models/location_status_and_functions.dart';
import '../ui/icon_badge_catalog.dart';
import '../ui/info_card.dart' as info_card;
import '../ui/section_visual_helpers.dart';
import '../utils/operational_dates.dart';

class ScheduleCardFull extends StatelessWidget {
  final WorkSchedule schedule;
  final List<Location> locations;
  final List<LocationCategory> categories;
  final List<CentralizerRecord> records;
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(ScheduleItem) onRemove;
  final void Function(int, int) onReorder;

  const ScheduleCardFull({
    required this.schedule,
    required this.locations,
    required this.categories,
    required this.records,
    required this.canEdit,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final proposedOrderTitle =
        'Ordine propusă · încredere ${(schedule.learningConfidence * 100).round()}%';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Zi grafic · ${formatDate(schedule.date)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canEdit && !schedule.closed)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Adaugă locații'),
                  ),
              ],
            ),
            if (schedule.autoProposed)
              info_card.InfoCard(
                icon: Icons.auto_graph,
                title: proposedOrderTitle,
                text: schedule.learningExplanation.trim().isEmpty
                    ? 'Ordinea este informativă. Echipa poate executa locațiile în orice ordine.'
                    : schedule.learningExplanation,
                accent: sectionAccent(proposedOrderTitle),
              ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedule.items.length,
              itemBuilder: (context, index) {
                final item = schedule.items[index];
                final done = records.any((record) =>
                    record.teamId == schedule.teamId &&
                    record.locationId == item.locationId &&
                    record.completed);
                final color = categoryColor(
                  categories,
                  item.categoryIdSnapshot,
                  fallbackType: item.typeSnapshot,
                );

                return Card(
                  key: ValueKey('${item.locationId}_$index'),
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        categoryBrandWidget(
                          item.categoryIdSnapshot,
                          size: 38,
                          fallbackColor: color,
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(item.locationNameSnapshot),
                    subtitle: Text(
                      '${item.addressSnapshot} · ${done ? 'Finalizată' : 'Rămasă'}',
                    ),
                    trailing: canEdit && !schedule.closed
                        ? IconButton(
                            onPressed: () => onRemove(item),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
                );
              },
              onReorder: canEdit && !schedule.closed ? onReorder : null,
            ),
          ],
        ),
      ),
    );
  }
}
