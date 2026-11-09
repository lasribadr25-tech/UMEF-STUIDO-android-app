// Onglet Accueil — écran Figma « 01 · Accueil ».
// Structure Figma : marque UEMF, hero « Vos idées prennent vie en studio. »,
// 4 actions rapides (Studios / Réserver / Projets / Sessions), prochaine
// session, poursuite du projet (pipeline 1/4). La mise en page absolue de
// Figma est traduite en layout Flutter natif (défilement vertical).
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'studios.dart';
import 'projects.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSearch;
  const HomeTab({
    super.key,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    final name = user?.name ?? 'Invité';
    final next = appStore.nextSession;
    final myProject = appStore.projects.isEmpty ? null : appStore.projects.first;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UEMF',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandBlue)),
                  Text('EUROMED STUDIOS',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 1.2)),
                ],
              ),
              const Spacer(),
              IconButton(
                  tooltip: 'Rechercher',
                  onPressed: onOpenSearch,
                  icon: const Icon(Icons.search)),
              IconButton(
                  tooltip: 'Notifications',
                  onPressed: onOpenNotifications,
                  icon: Badge(
                    isLabelVisible: appStore.unreadCount > 0,
                    label: Text('${appStore.unreadCount}'),
                    child: const Icon(Icons.notifications_outlined),
                  )),
              GestureDetector(
                onTap: onOpenProfile,
                child: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(name.isEmpty ? '?' : name[0],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vos idées\nprennent vie',
                  style: TextStyle(
                      fontSize: 35, fontWeight: FontWeight.w800, height: 1.1)),
              const Text('en studio.',
                  style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      height: 1.1)),
              const SizedBox(height: 12),
              Text('Bonjour $name,\npréparez votre prochaine création. Tout commence par une idée.',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.secondary, height: 1.4)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _QuickAction(
                  icon: Icons.video_camera_back_outlined,
                  label: 'Studios',
                  sub: 'Trouvez votre espace',
                  color: AppColors.studioBg,
                  onTap: () => goToTab(1)),
              _QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'Réserver',
                  sub: 'Préparez votre session',
                  color: AppColors.validatedBg,
                  onTap: () {
                    if (user == null || user.isGuest) {
                      showOk(context,
                          'La réservation exige un compte : connectez-vous depuis votre profil.');
                      return;
                    }
                    goToTab(1);
                  }),
              _QuickAction(
                  icon: Icons.folder_outlined,
                  label: 'Projets',
                  sub: 'De l’idée à la production',
                  color: const Color(0xFFEAF2FF),
                  onTap: () => goToTab(2)),
              _QuickAction(
                  icon: Icons.play_circle_outline,
                  label: 'Sessions',
                  sub: 'Vos créneaux et accès',
                  color: const Color(0xFFEFECFF),
                  onTap: () => goToTab(3)),
            ],
          ),
        ),
        if (next != null) ...[
          const SectionTitle('Votre prochaine session',
              actionLabel: 'Voir tout'),
          NextSessionPill(next, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: next)));
          }),
        ],
        if (myProject != null) ...[
          const SectionTitle('Continuer mon projet'),
          ProjectCard(myProject, onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(project: myProject)));
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
                '${myProject.stage.letter} · ${myProject.stage.label} — ${myProject.stepLabel}',
                style: const TextStyle(color: AppColors.secondary)),
          ),
        ],
        const SectionTitle('Studios à découvrir'),
        for (final s in kSpaces.where((s) => s.bookable).take(3))
          StudioCard(s, onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => StudioDetailScreen(space: s)));
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.secondary)),
              ],
            ),
          ),
        ),
      );
}
