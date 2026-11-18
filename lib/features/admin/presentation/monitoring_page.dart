import 'package:material_ui/material_ui.dart';

import '../domain/monitoring.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

String _date(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// Pestaña Monitoreo: releases, señalización y `ecos.log`
/// (docs/specs/balance_admin.md § 6). Todo de solo lectura.
class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key, required this.c});
  final AdminController c;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final room = TextEditingController();

  AdminController get c => widget.c;

  @override
  void dispose() {
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Monitoreo', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      _releases(context),
      _signaling(context),
      _log(context),
      const SectionCard(
        title: 'Telemetría de balance (propuesta, no implementada)',
        child: Text(
            'Opt-in explícito en Ajustes, apagado por defecto. Solo agregados por '
            'batalla (versión, hash de balance, zona/nivel, clase, arma, habilidades '
            'usadas, turnos, victoria) sin nombres, códigos de sala ni ids del equipo; '
            'envío en lote por una Cloud Function con App Check y TTL de 90 días. '
            'Detalle y riesgos de privacidad en docs/specs/balance_admin.md § 7.'),
      ),
    ]);
  }

  Widget _releases(BuildContext context) {
    final list = c.releases;
    final total = list?.fold<int>(0, (n, r) => n + r.installerDownloads) ?? 0;
    return SectionCard(
      title: 'Releases en GitHub',
      actions: [
        if (c.releasesLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        IconButton(
            icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: c.refreshReleases),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (c.releasesError != null)
          Text(c.releasesError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (list == null && c.releasesError == null)
          const Text('API pública de GitHub (sin token). Tocá actualizar.'),
        if (list != null) ...[
          Text('${list.length} releases · $total descargas del instalador en total'),
          const SizedBox(height: 6),
          DataTable(
            headingRowHeight: 32,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 32,
            columns: const [
              DataColumn(label: Text('Versión')),
              DataColumn(label: Text('Publicado')),
              DataColumn(label: Text('Instalador'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: [
              for (final r in list)
                DataRow(cells: [
                  DataCell(Text('${r.tag}${r.prerelease ? ' (pre)' : ''}${r.draft ? ' (borrador)' : ''}')),
                  DataCell(Text(_date(r.publishedAt))),
                  DataCell(Text('${r.installerDownloads}')),
                  DataCell(Text('${r.downloads}')),
                ]),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _signaling(BuildContext context) {
    final count = c.roomCount;
    final info = c.roomInfo;
    final err = Theme.of(context).colorScheme.error;
    return SectionCard(
      title: 'Señalización P2P (Firestore ${c.firestoreProjectId.isEmpty ? 'sin configurar' : c.firestoreProjectId})',
      actions: [
        if (c.roomsLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OutlinedButton.icon(
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Contar salas'),
              onPressed: c.countRooms),
          const SizedBox(width: 12),
          if (count?.count != null) Text('${count!.count} salas en Firestore (incluye vencidas)'),
          if (count?.error != null) Text(count!.error!, style: TextStyle(color: err)),
        ]),
        if (count?.denied ?? false) ...[
          const SizedBox(height: 6),
          Text('Firestore respondió 403: las reglas no permiten listar salas.',
              style: TextStyle(color: err)),
          const SizedBox(height: 4),
          const Text(kRoomCountRulesHelp),
        ],
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 160,
            child: TextField(
              controller: room,
              decoration: const InputDecoration(labelText: 'Código de sala', isDense: true),
              onSubmitted: c.lookupRoom,
            ),
          ),
          TextButton(onPressed: () => c.lookupRoom(room.text), child: const Text('Buscar')),
        ]),
        if (c.roomError != null) Text(c.roomError!, style: TextStyle(color: err)),
        if (info != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(info.exists
                ? 'Sala ${info.code}: creada ${_date(info.createdAt)}, vence ${_date(info.expiresAt)}'
                    '${info.expiredAt(DateTime.now()) ? ' (vencida)' : ''}, ${info.peers} pares, v${info.version ?? '?'}'
                : 'Sala ${info.code}: no existe.'),
          ),
      ]),
    );
  }

  Widget _log(BuildContext context) {
    final lines = c.visibleLog;
    final s = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'ecos.log (solo lectura)',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Recargar', onPressed: c.loadLog),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (c.logStatus != null) Text(c.logStatus!, style: Theme.of(context).textTheme.bodySmall),
        Row(children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_alt_outlined), hintText: 'Filtrar', isDense: true),
              onChanged: (v) => c.setLogFilter(text: v),
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Solo errores'),
            selected: c.logErrorsOnly,
            onSelected: (v) => c.setLogFilter(errorsOnly: v),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 260,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: s.surfaceContainerLowest,
          child: lines.isEmpty
              ? const Text('Sin líneas.')
              : ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (_, i) {
                    final l = lines[i];
                    return Text(
                      l.raw,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: l.level == 'ERROR' ? s.error : s.onSurface,
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
