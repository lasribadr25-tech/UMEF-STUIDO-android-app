// Sessions (Mes sessions) + Notifications + Recherche globale.
// Figma pages 03 (sessions), 06 (notifications) et 11 (recherche).
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'studios.dart';
import 'projects.dart';
import 'auth.dart';

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});
  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  BookingStatus? _filter;
  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    if (user == null || user.isGuest) {
      return const PermissionDenied(
          'Connectez-vous pour voir vos sessions. En invité, vous pouvez consulter les studios.');
    }
    var list = appStore.myBookings;
    if (_filter != null) {
      list = list.where((b) => b.status == _filter).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Mes sessions',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                  label: const Text('Toutes'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null)),
              const SizedBox(width: 8),
              for (final s in BookingStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                      label: Text(s.label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s)),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  title: 'Aucune session',
                  subtitle:
                      'Réservez un studio depuis l’onglet Studios pour voir vos demandes ici.')
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = [...appStore.notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => appStore.markAllNotificationsRead(),
            child: const Text('Tout marquer lu',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConfirmNote(
              'Les résultats de réservation restent obligatoires et ne peuvent pas être désactivés.'),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    title: 'Aucune notification',
                    subtitle: 'Les changements de statut apparaîtront ici.')
                : ListView(
                    children: [
                      for (final n in list)
                        Card(
                          color: n.read ? null : AppColors.validatedBg,
                          child: ListTile(
                            leading: Icon(
                                n.kind == 'réservation'
                                    ? Icons.calendar_month
                                    : n.kind == 'projet'
                                        ? Icons.folder
                                        : Icons.report_problem,
                                color: AppColors.primary),
                            title: Text(n.title,
                                style: TextStyle(
                                    fontWeight: n.read
                                        ? FontWeight.w500
                                        : FontWeight.w800)),
                            subtitle: Text(n.body),
                            trailing: n.read
                                ? null
                                : TextButton(
                                    onPressed: () =>
                                        appStore.markNotificationRead(n.id),
                                    child: const Text('Marquer comme lue'),
                                  ),
                            onTap: () {
                              appStore.markNotificationRead(n.id);
                              if (n.bookingId != null) {
                                final found = appStore.bookings
                                    .where((b) => b.id == n.bookingId)
                                    .toList();
                                if (found.isNotEmpty && context.mounted) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              BookingDetailScreen(
                                                  booking: found.first)));
                                }
                              } else if (n.projectId != null) {
                                final found = appStore.projects
                                    .where((p) => p.id == n.projectId)
                                    .toList();
                                if (found.isNotEmpty && context.mounted) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              ProjectDetailScreen(
                                                  project: found.first)));
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen())),
              child: const Text('Paramètres des notifications'),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  String _filter = 'Tous';
  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final studioResults = (_filter == 'Tous' || _filter == 'Studios')
        ? kSpaces
            .where((s) =>
                q.isEmpty || s.name.toLowerCase().contains(q))
            .toList()
        : const <StudioSpace>[];
    final projectResults = (_filter == 'Tous' || _filter == 'Projets')
        ? appStore.projects
            .where((p) => q.isEmpty || p.title.toLowerCase().contains(q))
            .toList()
        : const <Project>[];
    final sessionResults = (_filter == 'Tous' || _filter == 'Sessions')
        ? appStore.bookings
            .where((b) => q.isEmpty || b.title.toLowerCase().contains(q))
            .toList()
        : const <Booking>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Studios, projets, sessions…'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in ['Tous', 'Studios', 'Projets', 'Sessions'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f)),
                  ),
              ],
            ),
          ),
          const ConfirmNote(
              'Recherche / filtres en V1 : à confirmer. Ici : recherche simple, sans inventer de filtre avancé.'),
          Expanded(
            child: ListView(
              children: [
                for (final s in studioResults)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.video_camera_back_outlined),
                      title: Text(s.name),
                      subtitle: Text('Studio · ${s.tagline}'),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StudioDetailScreen(space: s))),
                    ),
                  ),
                for (final p in projectResults)
                  ProjectCard(p, onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(project: p)))),
                for (final b in sessionResults)
                  BookingCard(b, onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BookingDetailScreen(booking: b)))),
                if (studioResults.isEmpty &&
                    projectResults.isEmpty &&
                    sessionResults.isEmpty)
                  const EmptyState(
                      title: 'Aucun résultat',
                      subtitle: 'Essayez un autre mot-clé.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
