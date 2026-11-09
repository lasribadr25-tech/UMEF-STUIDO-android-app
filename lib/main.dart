// Euromed Studios — point d'entrée.
// Coquille Figma (page 02) : navigation inférieure à 4 onglets
// (Accueil · Studios · Projets · Sessions) + menu ⋮ pour les fonctions
// par rôle (Validations, Régie, Administration, Équipement, Incidents,
// Recherche, Aide, Profil) + FAB « Réserver / Créer ».
// Brouillon local privé : aucune donnée ne quitte le téléphone, aucune
// écriture GitHub, aucune modification du fichier Figma.
import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'auth.dart';
import 'home.dart';
import 'studios.dart';
import 'sessions.dart';
import 'projects.dart';
import 'approvals.dart';
import 'ops.dart';
import 'admin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appStore.init();
  runApp(const EuromedApp());
}

class EuromedApp extends StatelessWidget {
  const EuromedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Euromed Studios',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          if (!appStore.loaded) {
            return const Scaffold(body: LoadingState());
          }
          if (appStore.user == null) return const WelcomeScreen();
          return const HomeShell();
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    appStore.refreshStatuses(notify: false);
    shellTabNotifier.addListener(_onTab);
  }

  void _onTab() => setState(() {});

  @override
  void dispose() {
    shellTabNotifier.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = appStore.user!;
    final index = shellTabNotifier.value.clamp(0, 3);
    final tabs = <Widget>[
      HomeTab(
        onOpenProfile: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen())),
        onOpenNotifications: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        onOpenSearch: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchScreen())),
      ),
      const StudiosTab(),
      const ProjectsTab(),
      const SessionsTab(),
    ];
    return Scaffold(
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) => IndexedStack(index: index, children: tabs),
      ),
      floatingActionButton: user.isGuest
          ? null
          : FloatingActionButton(
              tooltip: 'Réserver / Créer',
              onPressed: () => _showCreateMenu(context),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => goToTab(i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.video_camera_back_outlined),
              selectedIcon: Icon(Icons.video_camera_back),
              label: 'Studios'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Projets'),
          NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle),
              label: 'Sessions'),
        ],
      ),
      appBar: AppBar(
        title: const Text('EUROMED STUDIOS'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: appStore.unreadCount > 0,
              label: Text('${appStore.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen())),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            onSelected: (v) => _onMenu(context, v),
            itemBuilder: (_) => [
              if (user.canApproveL1 || user.canApproveL2)
                const PopupMenuItem(
                    value: 'validations', child: Text('Validations')),
              if (user.canRegie)
                const PopupMenuItem(
                    value: 'regie', child: Text('Régie — Occupation')),
              if (user.isAdmin)
                const PopupMenuItem(
                    value: 'admin', child: Text('Administration')),
              const PopupMenuItem(
                  value: 'equipement', child: Text('Équipement')),
              const PopupMenuItem(
                  value: 'incidents', child: Text('Incidents')),
              const PopupMenuItem(
                  value: 'recherche', child: Text('Recherche globale')),
              const PopupMenuItem(value: 'aide', child: Text('Aide & Contact')),
              const PopupMenuItem(value: 'profil', child: Text('Profil')),
            ],
          ),
        ],
      ),
    );
  }

  void _onMenu(BuildContext context, String value) {
    switch (value) {
      case 'validations':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ApprovalsScreen()));
        break;
      case 'regie':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RegieScreen()));
        break;
      case 'admin':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminScreen()));
        break;
      case 'equipement':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const _EquipmentPage()));
        break;
      case 'incidents':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const IncidentsScreen()));
        break;
      case 'recherche':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchScreen()));
        break;
      case 'aide':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HelpScreen()));
        break;
      case 'profil':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()));
        break;
    }
  }

  void _showCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Réserver un studio'),
              onTap: () {
                Navigator.pop(ctx);
                goToTab(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Créer un projet'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NewProjectScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined),
              title: const Text('Signaler un incident'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ReportIncidentScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentPage extends StatelessWidget {
  const _EquipmentPage();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Équipement')),
        body: const EquipmentTab(),
      );
}
