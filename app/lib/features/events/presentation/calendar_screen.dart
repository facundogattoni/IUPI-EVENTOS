import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/utils/formatters.dart';
import '../../profiles/data/profile_repository.dart';
import '../application/events_providers.dart';
import 'widgets/event_tile.dart';

/// Pantalla principal del salón: calendario con vistas mes / semana / día y la
/// agenda del día seleccionado debajo.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(calendarFormatProvider);
    final focused = ref.watch(focusedDayProvider);
    final selected = ref.watch(selectedDayProvider);
    final monthAsync = ref.watch(monthEventsProvider);
    final dayEvents = ref.watch(eventsOfDayProvider(selected));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            tooltip: 'Hoy',
            icon: const Icon(Icons.today),
            onPressed: () {
              final now = DateTime.now();
              ref.read(focusedDayProvider.notifier).state = now;
              ref.read(selectedDayProvider.notifier).state = dayKey(now);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(monthEventsProvider),
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TableCalendar(
                    locale: 'es_AR',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: focused,
                    calendarFormat: format,
                    // Vista mensual, quincenal y semanal. La vista "diaria" es la
                    // agenda del día seleccionado que se muestra debajo.
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mes',
                      CalendarFormat.twoWeeks: 'Quincena',
                      CalendarFormat.week: 'Semana',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    selectedDayPredicate: (d) => isSameDay(d, selected),
                    eventLoader: (day) =>
                        ref.read(eventsOfDayProvider(day)),
                    onDaySelected: (selectedDay, focusedDay) {
                      ref.read(selectedDayProvider.notifier).state =
                          dayKey(selectedDay);
                      ref.read(focusedDayProvider.notifier).state = focusedDay;
                    },
                    onFormatChanged: (f) =>
                        ref.read(calendarFormatProvider.notifier).state = f,
                    onPageChanged: (focusedDay) =>
                        ref.read(focusedDayProvider.notifier).state = focusedDay,
                    calendarStyle: CalendarStyle(
                      markersMaxCount: 3,
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonShowsNext: false,
                      titleCentered: true,
                    ),
                  ),
                  if (monthAsync.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    Fmt.dayMonth(selected),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('${dayEvents.length} evento(s)',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (monthAsync.hasError)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No se pudieron cargar los eventos.\n${monthAsync.error}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              )
            else if (dayEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Center(child: Text('Sin cumpleaños este día.')),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    for (final e in dayEvents)
                      EventTile(
                        event: e,
                        onTap: () => context.push('/events/${e.id}'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: (ref
                  .watch(currentProfileProvider)
                  .valueOrNull
                  ?.role
                  .canManageEvents ??
              false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                '/events/new?date=${selected.toIso8601String()}',
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            )
          : null,
    );
  }
}
