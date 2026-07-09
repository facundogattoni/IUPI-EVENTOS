import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../profiles/data/profile_repository.dart';
import '../application/events_providers.dart';
import 'widgets/event_tile.dart';

/// Calendario con vistas mes / quincena / semana y la agenda del día debajo.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(calendarFormatProvider);
    final focused = ref.watch(focusedDayProvider);
    final selected = ref.watch(selectedDayProvider);
    final monthAsync = ref.watch(monthEventsProvider);
    final dayEvents = ref.watch(eventsOfDayProvider(selected));
    final canManage = ref
            .watch(currentProfileProvider)
            .valueOrNull
            ?.role
            .canManageEvents ??
        false;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(monthEventsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Barra de acciones
          Row(
            children: [
              if (canManage)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.push(
                      '/events/new?date=${selected.toIso8601String()}',
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuevo cumpleaños'),
                  ),
                ),
              if (canManage) const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () {
                  final now = DateTime.now();
                  ref.read(focusedDayProvider.notifier).state = now;
                  ref.read(selectedDayProvider.notifier).state = dayKey(now);
                },
                icon: const Icon(Icons.today_rounded),
                label: const Text('Hoy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CalendarCard(
            format: format,
            focused: focused,
            selected: selected,
            loading: monthAsync.isLoading,
            eventLoader: (day) => ref.read(eventsOfDayProvider(day)),
            onDaySelected: (selectedDay, focusedDay) {
              ref.read(selectedDayProvider.notifier).state = dayKey(selectedDay);
              ref.read(focusedDayProvider.notifier).state = focusedDay;
            },
            onFormatChanged: (f) =>
                ref.read(calendarFormatProvider.notifier).state = f,
            onPageChanged: (focusedDay) =>
                ref.read(focusedDayProvider.notifier).state = focusedDay,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(Fmt.dayMonth(selected),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${dayEvents.length} evento(s)',
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (monthAsync.hasError)
            Text('No se pudieron cargar los eventos.\n${monthAsync.error}',
                style: const TextStyle(color: AppColors.danger))
          else if (dayEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Sin cumpleaños este día.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            for (final e in dayEvents)
              EventTile(event: e, onTap: () => context.push('/events/${e.id}')),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.format,
    required this.focused,
    required this.selected,
    required this.loading,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  final CalendarFormat format;
  final DateTime focused;
  final DateTime selected;
  final bool loading;
  final List<Object?> Function(DateTime) eventLoader;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(CalendarFormat) onFormatChanged;
  final void Function(DateTime) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          TableCalendar<Object?>(
            locale: 'es_AR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focused,
            calendarFormat: format,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mes',
              CalendarFormat.twoWeeks: 'Quincena',
              CalendarFormat.week: 'Semana',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (d) => isSameDay(d, selected),
            eventLoader: eventLoader,
            onDaySelected: onDaySelected,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              weekendStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            calendarStyle: CalendarStyle(
              markersMaxCount: 3,
              defaultTextStyle: const TextStyle(color: AppColors.textStrong),
              weekendTextStyle: const TextStyle(color: AppColors.textStrong),
              outsideTextStyle: const TextStyle(color: AppColors.textMuted),
              markerDecoration: const BoxDecoration(
                  color: AppColors.kids, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                  color: AppColors.brand, shape: BoxShape.circle),
            ),
            headerStyle: HeaderStyle(
              formatButtonShowsNext: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              formatButtonDecoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle:
                  const TextStyle(color: AppColors.textStrong, fontSize: 12),
              leftChevronIcon: const Icon(Icons.chevron_left,
                  color: AppColors.textMuted),
              rightChevronIcon: const Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
