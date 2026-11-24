import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import 'theme.dart';

/// « 20:45 »
String formatHm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Sous le nom d'une chaîne : ce qui passe en ce moment, avec une petite barre d'avancement.
class EpgLine extends StatelessWidget {
  const EpgLine({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppState>().epgStore;
    final id = item.streamId;
    final number = item.number == null ? '' : '${item.number}  ';
    const style = TextStyle(fontSize: 12, color: Colors.white54);
    if (id == null || !store.available) {
      return number.isEmpty
          ? const SizedBox.shrink()
          : Text(number.trim(), style: style);
    }
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = store.onAir(id);
        if (now == null) {
          return Text(number.isEmpty ? ' ' : number.trim(), style: style);
        }
        return Row(
          children: [
            Expanded(
              child: Text(
                '$number${formatHm(now.start)}  ${now.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: LinearProgressIndicator(
                value: now.progress(DateTime.now()),
                minHeight: 3,
                color: Brand.pink,
                backgroundColor: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bandeau du plein écran : chaîne, émission en cours avec sa progression, et la suivante.
class NowNextBanner extends StatelessWidget {
  const NowNextBanner({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ListenableBuilder(
      listenable: state.epgStore,
      builder: (context, _) {
        final id = item.streamId;
        final list = id == null
            ? const <EpgEntry>[]
            : state.epgStore.upcoming(id);
        final now = list.isNotEmpty && list.first.isOnAir(DateTime.now())
            ? list.first
            : null;
        final next = list.skip(now == null ? 0 : 1).firstOrNull;
        return Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xD9101018),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: Brand.gradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.number == null
                          ? item.name
                          : '${item.number}  ${item.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (now != null) ...[
                const SizedBox(height: 10),
                Text(
                  now.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formatHm(now.start),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: now.progress(DateTime.now()),
                        minHeight: 4,
                        color: Brand.pink,
                        backgroundColor: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatHm(now.end),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
              if (next != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ensuite · ${formatHm(next.start)}  ${next.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Programme de la chaîne : la journée à venir, l'émission en cours en tête et mise en avant.
Future<void> showProgramme(BuildContext context, MediaItem item) {
  final store = context.read<AppState>().epgStore;
  final id = item.streamId;
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: Brand.pink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Programme · ${item.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<EpgEntry>>(
                future: id == null
                    ? Future.value(const [])
                    : store.programme(id),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final now = DateTime.now();
                  final entries = (snap.data ?? const <EpgEntry>[])
                      .where((e) => e.end.isAfter(now))
                      .toList();
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Text(
                        "Ton fournisseur ne donne pas de programme pour cette chaîne.",
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) =>
                        _ProgrammeTile(entry: entries[i], autofocus: i == 0),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProgrammeTile extends StatefulWidget {
  const _ProgrammeTile({required this.entry, required this.autofocus});
  final EpgEntry entry;
  final bool autofocus;

  @override
  State<_ProgrammeTile> createState() => _ProgrammeTileState();
}

class _ProgrammeTileState extends State<_ProgrammeTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final now = DateTime.now();
    final onAir = e.isOnAir(now);
    final hasText = e.description.isNotEmpty;
    return Material(
      color: onAir ? Brand.violet.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        autofocus: widget.autofocus,
        focusColor: Brand.focus,
        borderRadius: BorderRadius.circular(12),
        onTap: hasText ? () => setState(() => expanded = !expanded) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  formatHm(e.start),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: onAir ? Brand.pink : Colors.white70,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            style: TextStyle(
                              fontWeight: onAir
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (onAir)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'EN COURS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (onAir) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: e.progress(now),
                        minHeight: 3,
                        color: Brand.pink,
                        backgroundColor: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                    if (hasText) ...[
                      const SizedBox(height: 4),
                      Text(
                        e.description,
                        maxLines: expanded ? null : 1,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                    Text(
                      'jusqu\'à ${formatHm(e.end)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
