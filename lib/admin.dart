// Administration — écrans Figma page 10.
// Planning global (recherche/filtres), équipement + blocs maintenance,
// rapports & journal des actions privilégiées, configuration (quotas,
// seuil de fraîcheur). Analyses avancées et modifications en masse : hors V1.
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'studios.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const PermissionDenied(
            'L’administration est réservée à l’administrateur des studios.'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Planning'),
            Tab(text: 'Équipement & blocs'),
            Tab(text: 'Rapports & journal'),
            Tab(text: 'Configuration'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _PlanningTab(query: _query, onQuery: (v) => setState(() => _query = v)),
          const _EquipmentAdminTab(),
          const _ReportsTab(),
          const _ConfigTab(),
        ],
      ),
    );
  }
}

class _PlanningTab extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQuery;
  const _PlanningTab({required this.query, required this.onQuery});
  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final list = appStore.bookings.where((b) {
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          spaceById(b.spaceId).name.toLowerCase().contains(q) ||
          b.userName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return Column(
      children: [
        const ConfirmNote(
            'Administrateur · actions selon périmètre et habilitations. Recherche et filtres sur réservations, projets, matériel et incidents. Historique des actions privilégiées. Analyses avancées et modifications en masse : hors V1.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher une réservation, un projet…'),
            onChanged: onQuery,
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  title: 'Aucune réservation',
                  subtitle: 'Aucun résultat pour cette recherche.')
              : ListView(
                  children: [
                    for (final b in list)
                      BookingCard(b, onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    BookingDetailScreen(booking: b)));
                      }),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EquipmentAdminTab extends StatefulWidget {
  const _EquipmentAdminTab();
  @override
  State<_EquipmentAdminTab> createState() => _EquipmentAdminTabState();
}

class _EquipmentAdminTabState extends State<_EquipmentAdminTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('Équipement'),
        for (final e in appStore.equipment)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(e.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Text(e.status.label,
                          style: TextStyle(
                              color: e.status == EquipmentStatus.disponible
                                  ? AppColors.ok
                                  : AppColors.err,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Quantité totale : '),
                      DropdownButton<int>(
                        value: e.totalQty,
                        items: [
                          for (var n = 1; n <= 10; n++)
                            DropdownMenuItem(value: n, child: Text('$n'))
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            appStore.setEquipmentQty(e.id, v);
                            setState(() {});
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          appStore.setEquipmentStatus(
                              e.id,
                              e.status == EquipmentStatus.disponible
                                  ? EquipmentStatus.bloque
                                  : EquipmentStatus.disponible);
                          setState(() {});
                        },
                        child: Text(e.status == EquipmentStatus.disponible
                            ? 'Bloquer'
                            : 'Débloquer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SectionTitle('Blocs maintenance / administratifs'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
              'Un blocage participe à la même règle que les réservations : pas de réservation sur la période bloquée.',
              style: TextStyle(color: AppColors.secondary)),
        ),
        for (final bl in appStore.blocks)
          Card(
            child: ListTile(
              title: Text(
                  '${spaceById(bl.spaceId).name} · ${fmtDay(bl.date)} ${bl.startHour}h–${bl.endHour}h'),
              subtitle: Text(bl.reason),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.err),
                onPressed: () {
                  appStore.removeBlock(bl.id);
                  setState(() {});
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _addBlock(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer un bloc maintenance'),
          ),
        ),
      ],
    );
  }

  void _addBlock(BuildContext context) async {
    var spaceId = 'podcast';
    var date = DateTime.now().add(const Duration(days: 1));
    date = DateTime(date.year, date.month, date.day);
    var start = 10;
    var duration = 2;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Bloc maintenance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: spaceId,
                  isExpanded: true,
                  items: [
                    for (final s in kSpaces)
                      DropdownMenuItem(value: s.id, child: Text(s.name))
                  ],
                  onChanged: (v) => setD(() => spaceId = v!),
                ),
                ListTile(
                  title: Text(fmtDay(date)),
                  leading: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) {
                      setD(() => date = DateTime(
                          picked.year, picked.month, picked.day));
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: start,
                        isExpanded: true,
                        items: [
                          for (final h in kSlotHours)
                            DropdownMenuItem(
                                value: h,
                                child: Text(
                                    '${h.toString().padLeft(2, '0')}:00'))
                        ],
                        onChanged: (v) => setD(() => start = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: duration,
                        isExpanded: true,
                        items: [
                          for (var d = 1; d <= 4; d++)
                            DropdownMenuItem(value: d, child: Text('$d h'))
                        ],
                        onChanged: (v) => setD(() => duration = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                      labelText: 'Raison du bloc *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok == true && reason.text.trim().isNotEmpty) {
      appStore.addBlock(MaintenanceBlock(
        id: appStore.newId('BL'),
        spaceId: spaceId,
        date: date,
        startHour: start,
        durationHours: duration,
        reason: reason.text.trim(),
        createdBy: appStore.user?.name ?? '—',
      ));
      setState(() {});
      if (context.mounted) showOk(context, 'Bloc maintenance créé.');
    }
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context) {
    final total = appStore.bookings.length;
    final validated =
        appStore.bookings.where((b) => b.status == BookingStatus.validee).length;
    final refused =
        appStore.bookings.where((b) => b.status == BookingStatus.refusee).length;
    final openIncidents = appStore.incidents
        .where((i) =>
            i.status == IncidentStatus.signale ||
            i.status == IncidentStatus.enExamen ||
            i.status == IncidentStatus.enCours)
        .length;
    return ListView(
      children: [
        const SectionTitle('Rapports (données locales)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
                'Réservations : $total · Validées : $validated · Refusées : $refused\nProjets : ${appStore.projects.length} · Incidents ouverts : $openIncidents'),
          ),
        ),
        const SectionTitle('Journal des actions privilégiées'),
        for (final a in appStore.audit)
          Card(
            child: ListTile(
              title: Text(a.action),
              subtitle: Text('${a.detail}\nPar ${a.actor} · ${fmtDay(a.createdAt)}'),
              isThreeLine: true,
            ),
          ),
        if (appStore.audit.isEmpty)
          const EmptyState(
              title: 'Journal vide',
              subtitle: 'Les validations, refus et changements de configuration apparaîtront ici.'),
      ],
    );
  }
}

class _ConfigTab extends StatefulWidget {
  const _ConfigTab();
  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('Quotas hebdomadaires (configurables)'),
        const ConfirmNote(
            'Valeurs d’exemple — à confirmer par UEMF. Le Cahier cite « 2 h / semaine pour un étudiant » à titre d’exemple ; la spec interdit de le figer comme règle définitive. Modifiez les valeurs ici : elles s’appliquent immédiatement.'),
        for (final role in [
          AppRole.etudiant,
          AppRole.professeur,
          AppRole.communication,
          AppRole.club,
          AppRole.externe,
        ])
          Card(
            child: ListTile(
              title: Text(kRoles[role]!.label),
              trailing: DropdownButton<int?>(
                value: appStore.config.quotas[role],
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Illimité')),
                  for (var h = 1; h <= 20; h++)
                    DropdownMenuItem(value: h, child: Text('$h h')),
                ],
                onChanged: (v) {
                  appStore.setQuota(role, v);
                  setState(() {});
                },
              ),
            ),
          ),
        const SectionTitle('Occupation — seuil de fraîcheur'),
        const ConfirmNote(
            'Seuil configurable : une information plus ancienne devient « Inconnu ». Il n’est pas figé à 15 minutes (spec : à valider par l’UEMF).'),
        Card(
          child: ListTile(
            title: const Text('Seuil de fraîcheur (minutes)'),
            trailing: DropdownButton<int>(
              value: appStore.config.freshnessMinutes,
              items: const [
                DropdownMenuItem(value: 15, child: Text('15')),
                DropdownMenuItem(value: 30, child: Text('30')),
                DropdownMenuItem(value: 60, child: Text('60')),
                DropdownMenuItem(value: 120, child: Text('120')),
              ],
              onChanged: (v) {
                if (v != null) {
                  appStore.setFreshness(v);
                  setState(() {});
                }
              },
            ),
          ),
        ),
        const SectionTitle('Utilisateurs & rôles (démo)'),
        for (final a in kDemoAccounts)
          Card(
            child: ListTile(
              title: Text(a.name),
              subtitle: Text(kRoles[a.role]!.label),
            ),
          ),
        const ConfirmNote(
            'Gestion réelle des comptes (création, habilitations, révocation) : hors périmètre de cette version locale — elle relèvera de l’annuaire UEMF.'),
      ],
    );
  }
}
