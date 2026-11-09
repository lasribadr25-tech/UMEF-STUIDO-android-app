// Opérations — écrans Figma pages 05 (équipement), 07 (incidents &
// maintenance) et 09 (studio operations / régisseur).
// Occupation : Libre / Occupé / Inconnu + dernière mise à jour ; une
// information trop ancienne devient Inconnu (seuil configurable).
// Incidents : Signalé → En examen → En cours → Résolu → Fermé ; gravité
// Basse / Moyenne / Haute ; un incident grave bloque la ressource.
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class RegieScreen extends StatelessWidget {
  const RegieScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    if (user == null || !user.canRegie) {
      return Scaffold(
        appBar: AppBar(title: const Text('Régie — Occupation')),
        body: const PermissionDenied(
            'La régie est réservée à l’équipe technique et à l’administrateur.'),
      );
    }
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return Scaffold(
      appBar: AppBar(title: const Text('Occupation des studios')),
      body: ListView(
        children: [
          const ConfirmNote(
              'L’occupation physique ne prouve pas la disponibilité à réserver. Une information trop ancienne devient Inconnu. Seuil de fraîcheur configurable, à confirmer. Fonction opérationnelle · données de démonstration.'),
          for (final occ in appStore.occupancy)
            Card(
              child: ListTile(
                title: Text(spaceById(occ.spaceId).name),
                subtitle: Text(
                    'État : ${appStore.displayedOccupancy(occ).label} · mis à jour le ${occ.updatedAt.hour.toString().padLeft(2, '0')}:${occ.updatedAt.minute.toString().padLeft(2, '0')} · ${appStore.bookingsOn(day).where((b) => b.spaceId == occ.spaceId).length} réservation(s) aujourd’hui'),
                trailing: DropdownButton<OccupancyState>(
                  value: appStore.displayedOccupancy(occ),
                  items: const [
                    DropdownMenuItem(
                        value: OccupancyState.libre, child: Text('Libre')),
                    DropdownMenuItem(
                        value: OccupancyState.occupe, child: Text('Occupé')),
                    DropdownMenuItem(
                        value: OccupancyState.inconnu,
                        child: Text('Inconnu')),
                  ],
                  onChanged: (v) {
                    if (v != null) appStore.setOccupancy(occ.spaceId, v);
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const IncidentsScreen())),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Voir les incidents à traiter'),
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [...appStore.incidents]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Incidents à traiter')),
      body: Column(
        children: [
          const ConfirmNote(
              'File de triage : Signalé → En examen → En cours → Résolu → Fermé. Gravité : Basse / Moyenne / Haute. Pas de délai, SLA ou réouverture en V1. Un problème grave bloque la ressource.'),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    title: 'Aucun incident',
                    subtitle: 'Les signalements de fin de session apparaîtront ici.')
                : ListView(
                    children: [
                      for (final inc in list)
                        Card(
                          child: ListTile(
                            title: Text(inc.title),
                            subtitle: Text(
                                '${inc.status.label} · ${inc.severity.label}${inc.blocksResource ? ' — ressource bloquée' : ''} · ${inc.reporterName}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        IncidentDetailScreen(incident: inc))),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportIncidentScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Signaler un incident'),
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentDetailScreen extends StatefulWidget {
  final Incident incident;
  const IncidentDetailScreen({super.key, required this.incident});
  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  Incident get inc => appStore.incidents
      .firstWhere((x) => x.id == widget.incident.id, orElse: () => widget.incident);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(inc.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${spaceById(inc.spaceId).name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(inc.description, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Text('Signalé par ${inc.reporterName} · ${fmtDay(inc.createdAt)}',
              style: const TextStyle(color: AppColors.secondary)),
          if (inc.bookingId != null)
            Text('Session liée : ${inc.bookingId}',
                style: const TextStyle(color: AppColors.secondary)),
          if (inc.blocksResource)
            const ConfirmNote(
                'Ce problème grave bloque la ressource en attendant l’examen / la résolution autorisée.'),
          const SizedBox(height: 16),
          const Text('Statut', style: TextStyle(fontWeight: FontWeight.w800)),
          DropdownButton<IncidentStatus>(
            value: inc.status,
            isExpanded: true,
            items: [
              for (final s in IncidentStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label))
            ],
            onChanged: (v) {
              if (v != null) {
                appStore.setIncidentStatus(inc.id, v);
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 8),
          const Text('Gravité (attribuée au triage, pas par le déclarant)',
              style: TextStyle(fontWeight: FontWeight.w800)),
          DropdownButton<Severity>(
            value: inc.severity,
            isExpanded: true,
            items: [
              for (final s in Severity.values)
                DropdownMenuItem(value: s, child: Text(s.label))
            ],
            onChanged: (v) {
              if (v != null) {
                appStore.setIncidentSeverity(inc.id, v);
                setState(() {});
              }
            },
          ),
          const Text(
              'Flux : Signalé → En examen → En cours → Résolu → Fermé. La réouverture d’un incident fermé n’est pas prévue en V1 : créez un nouveau signalement si le problème réapparaît.',
              style: TextStyle(color: AppColors.secondary)),
        ],
      ),
    );
  }
}

class ReportIncidentScreen extends StatefulWidget {
  final Booking? booking;
  const ReportIncidentScreen({super.key, this.booking});
  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  String _spaceId = 'podcast';
  String? _equipmentId;
  final _title = TextEditingController();
  final _desc = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) _spaceId = widget.booking!.spaceId;
  }

  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un incident')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Signaler un\nincident',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const Text(
              'En fin de session, ou dès que vous le constatez.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          const Text('Studio / espace concerné',
              style: TextStyle(fontWeight: FontWeight.w800)),
          DropdownButton<String>(
            value: _spaceId,
            isExpanded: true,
            items: [
              for (final s in kSpaces)
                DropdownMenuItem(value: s.id, child: Text(s.name))
            ],
            onChanged: (v) => setState(() => _spaceId = v!),
          ),
          const SizedBox(height: 8),
          const Text('Équipement concerné (si connu)',
              style: TextStyle(fontWeight: FontWeight.w800)),
          DropdownButton<String?>(
            value: _equipmentId,
            isExpanded: true,
            hint: const Text('Mobilier / espace (aucun équipement)'),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Mobilier / espace')),
              for (final e in appStore.equipment)
                DropdownMenuItem(value: e.id, child: Text(e.name)),
            ],
            onChanged: (v) => setState(() => _equipmentId = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
                labelText: 'Problème constaté *',
                hintText: 'Ex. : Le micro grésille dès…'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Décrivez le problème, le moment, les conséquences…'),
          ),
          const ConfirmNote(
              'La gravité est attribuée lors du triage, pas par le déclarant. Un problème grave bloque la ressource. Photos et confirmation du déclarant : différés (hors V1).'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: user == null
                ? null
                : () {
                    try {
                      appStore.addIncident(Incident(
                        id: appStore.newId('I'),
                        spaceId: _spaceId,
                        equipmentId: _equipmentId,
                        title: _title.text.trim().isEmpty
                            ? 'Incident signalé — ${spaceById(_spaceId).name}'
                            : _title.text.trim(),
                        description: _desc.text.trim(),
                        reporterName: user.name,
                        bookingId: widget.booking?.id,
                        severity: Severity.moyenne,
                        status: IncidentStatus.signale,
                        createdAt: DateTime.now(),
                      ));
                      Navigator.pop(context);
                      showOk(context,
                          'Incident signalé — visible par l’équipe technique.');
                    } on BookingException catch (e) {
                      showError(context, e.message);
                    }
                  },
            child: const Text('Envoyer le signalement'),
          ),
        ],
      ),
    );
  }
}

class EquipmentTab extends StatelessWidget {
  const EquipmentTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('Équipement'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
              'Catalogue — disponibilité opérationnelle. Un blocage participe à la même règle que les réservations : pas de réservation sur la période bloquée.',
              style: TextStyle(color: AppColors.secondary)),
        ),
        for (final e in appStore.equipment)
          Card(
            child: ListTile(
              title: Text(e.name),
              subtitle: Text(
                  '${e.category} · ${e.status.label} · ${e.totalQty} au total'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EquipmentDetailScreen(item: e))),
            ),
          ),
        const ConfirmNote(
            'Gestion complète de la maintenance : hors V1. Ici : catalogue, disponibilité et blocage.'),
      ],
    );
  }
}

class EquipmentDetailScreen extends StatelessWidget {
  final EquipmentItem item;
  const EquipmentDetailScreen({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final e = appStore.equipment.firstWhere((x) => x.id == item.id,
        orElse: () => item);
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(e.category,
              style: const TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 8),
          Text(e.description, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Text('Disponibilité : ${e.status.label}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: e.status == EquipmentStatus.disponible
                      ? AppColors.ok
                      : AppColors.err)),
          Text('Quantité totale : ${e.totalQty} (à confirmer par UEMF).'),
          const SizedBox(height: 12),
          const Text('Demande dans une réservation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Obligatoire indisponible → la validation technique est bloquée. Optionnel indisponible → il est noté indisponible, ou un substitut approuvé est choisi — jamais supprimé en silence.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              goToTab(1);
            },
            child: const Text('Réserver un studio avec ce matériel'),
          ),
        ],
      ),
    );
  }
}
