// Approbations — écrans Figma page 08.
// Niveau 1 (entité, périmètre autorisé) puis Niveau 2 (validation technique
// du Responsable des Studios, avec vérification des ressources).
// Un refus exige un motif et notifie immédiatement le demandeur.
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'studios.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    if (user == null ||
        (!user.canApproveL1 && !user.canApproveL2)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Approbations')),
        body: const PermissionDenied(
            'Seuls les approbateurs d’entité, le Responsable des Studios et l’administrateur accèdent aux files d’approbation.'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approbations'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Niveau 1 — Entité'),
            Tab(text: 'Niveau 2 — Studio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _LevelList(
              level: 1,
              items: appStore.pendingLevel1,
              emptyText:
                  'Aucune demande en attente entité dans votre périmètre.'),
          _LevelList(
              level: 2,
              items: appStore.pendingLevel2,
              emptyText:
                  'Aucune demande en attente studio pour validation technique.'),
        ],
      ),
    );
  }
}

class _LevelList extends StatelessWidget {
  final int level;
  final List<Booking> items;
  final String emptyText;
  const _LevelList(
      {required this.level, required this.items, required this.emptyText});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(title: 'File vide', subtitle: emptyText);
    }
    return ListView(
      children: [
        ConfirmNote(level == 1
            ? 'Niveau 1 · uniquement les demandes de votre périmètre autorisé. Approuver = passer en attente studio (ce n’est pas une validation finale).'
            : 'Validation technique · Responsable des Studios · périmètre autorisé. La validation re-vérifie le créneau, les blocs et les ressources.'),
        for (final b in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(b.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      StatusChip(b.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${spaceById(b.spaceId).name} · ${fmtDay(b.date)} · ${b.slotLabel}',
                      style: const TextStyle(color: AppColors.secondary)),
                  Text(
                      '${b.userName} · ${kRoles[b.userRole]!.label} · ${b.usage.label}',
                      style: const TextStyle(color: AppColors.secondary)),
                  if (b.equipment.isNotEmpty)
                    Text(
                        'Matériel : ${b.equipment.map((r) {
                          final item = appStore.equipment.firstWhere(
                              (e) => e.id == r.itemId,
                              orElse: () => EquipmentItem(
                                  id: r.itemId, name: r.itemId, category: '',
                                  totalQty: 0,
                                  status: EquipmentStatus.disponible,
                                  description: ''));
                          return '${item.name} × ${r.qty} · ${r.required ? 'requis' : 'optionnel'}';
                        }).join(', ')}',
                        style: const TextStyle(color: AppColors.secondary)),
                  if (level == 2) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final blockers = appStore.level2Blockers(b);
                      if (blockers.isEmpty) {
                        return const Text('✓ Ressources vérifiées : disponibles.',
                            style: TextStyle(
                                color: AppColors.ok,
                                fontWeight: FontWeight.w700));
                      }
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.rejectedBg,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                            'Validation bloquée :\n• ${blockers.join('\n• ')}',
                            style: const TextStyle(
                                color: AppColors.rejectedFg)),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            try {
                              if (level == 1) {
                                appStore.approveLevel1(b.id);
                              } else {
                                appStore.approveLevel2(b.id);
                              }
                              showOk(context,
                                  level == 1
                                      ? 'Demande transmise en attente studio.'
                                      : 'Demande validée techniquement.');
                            } on BookingException catch (e) {
                              showError(context, e.message);
                            }
                          },
                          child: Text(level == 1
                              ? 'Approuver — passer en attente studio'
                              : 'Valider techniquement'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.err,
                            side: const BorderSide(color: AppColors.err)),
                        onPressed: () async {
                          final reason = await reasonDialog(
                              context, 'Demande — Refus (motif)');
                          if (reason == null) {
                            if (context.mounted) {
                              showError(context,
                                  'Un refus exige un motif. Aucune décision n’a été enregistrée.');
                            }
                            return;
                          }
                          try {
                            appStore.refuse(b.id, reason, level: level);
                            if (context.mounted) {
                              showOk(context,
                                  'Refus enregistré et notifié au demandeur.');
                            }
                          } on BookingException catch (e) {
                            if (context.mounted) showError(context, e.message);
                          }
                        },
                        child: const Text('Refuser avec motif'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                BookingDetailScreen(booking: b))),
                    child: const Text('Voir le détail'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
