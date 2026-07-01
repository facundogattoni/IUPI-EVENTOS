import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/event.dart';

/// Fila compacta de un evento para listas y agenda del día.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onTap});

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = event.status.color(scheme);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.childAge != null
                          ? '${event.childName} (${event.childAge})'
                          : event.childName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(event.timeRange,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                        if (event.kidsCount != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.child_care,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${event.kidsCount}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(color: statusColor, label: event.status.label),
                  const SizedBox(height: 4),
                  if (event.balanceDue > 0)
                    Text('Debe ${Fmt.money(event.balanceDue)}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.error))
                  else if (event.price > 0)
                    Text('Pagado',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
