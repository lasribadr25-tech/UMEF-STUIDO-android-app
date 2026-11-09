// Widgets partagés — composants Figma (page 01) traduits en Flutter natif :
// cartes, puces, états globaux (chargement / vide / erreur / permission),
// pilule de session flottante, FAB « Réserver / Créer ».
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Onglet courant de la coquille (Accueil / Studios / Projets / Sessions).
final ValueNotifier<int> shellTabNotifier = ValueNotifier(0);

void goToTab(int index) => shellTabNotifier.value = index;

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.err),
  );
}

void showOk(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.ok),
  );
}

/// Note « à confirmer par UEMF » — rappel systématique, jamais une règle inventée.
class ConfirmNote extends StatelessWidget {
  final String text;
  const ConfirmNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.entityBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.entityFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.entityFg)),
            ),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const EmptyState(
      {super.key, required this.title, required this.subtitle, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.secondary)),
            ],
          ),
        ),
      );
}

class PermissionDenied extends StatelessWidget {
  final String message;
  const PermissionDenied(this.message, {super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
        title: 'Accès non autorisé',
        subtitle: message,
        icon: Icons.lock_outline,
      );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
}

/// Carte réservation (composant « Card / Reservation card » de Figma).
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;
  const BookingCard(this.booking, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final space = spaceById(booking.spaceId);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(booking.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  StatusChip(booking.status),
                ],
              ),
              const SizedBox(height: 6),
              Text('${space.name} · ${fmtDay(booking.date)} · ${booking.slotLabel}',
                  style: const TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 4),
              Text('${booking.usage.label} · ${booking.userName}',
                  style: const TextStyle(
                      color: AppColors.secondary, fontSize: 13)),
              if (booking.refusalReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.rejectedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Motif du refus : ${booking.refusalReason}',
                      style: const TextStyle(
                          color: AppColors.rejectedFg, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte projet (composant « Card / Project card » de Figma).
class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;
  const ProjectCard(this.project, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${project.type.label} · ${project.stage.label}${project.archived ? ' · Archivé' : ''}',
                        style: const TextStyle(color: AppColors.secondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.studioBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(project.stepLabel,
                    style: const TextStyle(
                        color: AppColors.studioFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte studio (composant « Card / Studio card » de Figma).
class StudioCard extends StatelessWidget {
  final StudioSpace space;
  final VoidCallback? onTap;
  const StudioCard(this.space, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (space.image != null)
              Image.asset(space.image!,
                  height: 150, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 150, color: AppColors.studioBg,
                      child: const Icon(Icons.videocam, size: 48))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(space.name,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      if (!space.bookable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.neutralBg,
                              borderRadius: BorderRadius.circular(999)),
                          child: const Text('Support',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(space.tagline,
                      style: const TextStyle(color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      starsRow(space.isolation),
                      const SizedBox(width: 8),
                      const Text('Réservabilité à confirmer',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilule de session flottante (Figma : « Prochaine session · 12 nov. 10:00 → »).
class NextSessionPill extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const NextSessionPill(this.booking, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        'Prochaine session · ${fmtDayShort(booking.date)} ${booking.startHour.toString().padLeft(2, '0')}:00 — ${booking.title}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.arrow_forward,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
}

Future<bool> confirmDialog(BuildContext context, String title, String body,
    {String confirmLabel = 'Confirmer'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> reasonDialog(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        decoration: const InputDecoration(
            labelText: 'Motif (obligatoire)',
            hintText: 'Expliquez la raison du refus…'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser')),
      ],
    ),
  );
  if (ok != true) return null;
  return ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
}
