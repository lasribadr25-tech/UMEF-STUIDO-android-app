// Authentification / profil / aide — écrans Figma page 02 (Home & App Shell).
// Démo locale : choix d'un compte de démonstration, sans mot de passe.
// L'authentification réelle UEMF (compte institutionnel, mot de passe oublié…)
// relève du backend et n'est pas simulée ici au-delà de l'écran de connexion.
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('UEMF',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue)),
              const Text('EUROMED STUDIOS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: 1.5)),
              const SizedBox(height: 24),
              const Text('Vos idées\nprennent vie\nen studio.',
                  style: TextStyle(
                      fontSize: 35, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 16),
              const Text(
                  'Réservez un studio, suivez votre projet, et accédez à votre session par QR.',
                  style: TextStyle(fontSize: 15, color: AppColors.secondary)),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Se connecter'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18)
                    ]),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  appStore.loginGuest();
                },
                child: const Text('Découvrir les studios sans compte →'),
              ),
              const Text(
                  'La réservation, elle, exige un compte.',
                  style: TextStyle(color: AppColors.secondary, fontSize: 13)),
              const SizedBox(height: 12),
              const Center(
                  child: Text('Euromed Studios — UEMF · Fès',
                      style: TextStyle(
                          color: AppColors.secondary, fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  DemoAccount? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Bon retour',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Connectez-vous avec votre compte UEMF.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            decoration: const InputDecoration(
                labelText: 'Email UEMF', hintText: 'prenom.nom@…'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Mot de passe'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showOk(context,
                  'Démo locale : la réinitialisation du mot de passe dépendra du compte UEMF réel (backend, hors périmètre).'),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          const ConfirmNote(
              'Version de démonstration locale : choisissez un compte ci-dessous. Aucun mot de passe n’est vérifié et aucune donnée ne quitte le téléphone.'),
          const SizedBox(height: 8),
          const Text('Comptes de démonstration',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          for (final a in kDemoAccounts)
            Card(
              child: RadioListTile<DemoAccount>(
                value: a,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Text(a.name),
                subtitle: Text(kRoles[a.role]!.label),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () {
                    appStore.login(_selected!.name, _selected!.role);
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
            child: const Text('Entrer dans l’application'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              appStore.loginGuest();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: const Text('Continuer sans compte (invité)'),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = appStore.user!;
    final info = kRoles[user.role]!;
    final quota = appStore.quotaFor(user.role);
    final used = appStore.weeklyHoursUsed(user.name, user.role, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                      user.name.isEmpty ? '?' : user.name[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${info.label} · ${info.org}',
                          style: const TextStyle(
                              color: AppColors.secondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quota applicable',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(quota == null
                      ? 'Illimité pour ce profil.'
                      : '$used h utilisées cette semaine / $quota h (valeur d’exemple).'),
                  const Text(
                      'Valeurs et modalités à confirmer par UEMF.',
                      style: TextStyle(
                          color: AppColors.secondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: quota == null
                        ? 0
                        : (used / quota).clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mes droits et parcours',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(info.note),
                  const SizedBox(height: 8),
                  const Text(
                      'Approbation en 2 niveaux :\nEn attente entité → En attente studio → Validée',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Text('Autorité Niveau 1 pour vos demandes :',
                      style: TextStyle(color: AppColors.secondary)),
                  Text('• ${info.l1Authority}',
                      style: const TextStyle(color: AppColors.secondary)),
                  const Text(
                      'Notifications de résultat : non désactivables.',
                      style: TextStyle(color: AppColors.secondary)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Rôles & permissions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RolesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Tableau de bord — Rôles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DashboardRolesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Aide & Contact'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('États & récupération (U1–U4)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Réinitialiser la démo'),
            subtitle: const Text('Restaure les données d’exemple.'),
            onTap: () async {
              final ok = await confirmDialog(context, 'Réinitialiser la démo ?',
                  'Toutes les modifications locales seront remplacées par les données d’exemple.');
              if (ok) {
                await appStore.resetDemo();
                if (context.mounted) {
                  showOk(context, 'Données d’exemple restaurées.');
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.err),
            title: const Text('Déconnexion',
                style: TextStyle(color: AppColors.err)),
            onTap: () {
              appStore.logout();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Brouillon local privé, sans partage avec l’équipe : la revue d’équipe (gate Issue #9) reste à lever avant toute diffusion.',
                style: TextStyle(
                    color: AppColors.secondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class RolesScreen extends StatelessWidget {
  const RolesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rôles & Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profil organisationnel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Étudiant · Professeur · Communication · Club · Externe (selon votre compte).',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          const Text('Rôles privilégiés',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Approbateur entité · Approbateur studio · Administrateur — périmètre limité, moindre privilège.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          const Text('Rôles contextuels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Représentant de club · Collaborateur de projet — accès explicite seulement.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          for (final e in kRoles.entries)
            if (e.key != AppRole.invite)
              Card(
                child: ListTile(
                  title: Text(e.value.label),
                  subtitle: Text(
                      'Niveau 1 : ${e.value.l1Authority}\n${e.value.note}'),
                  isThreeLine: true,
                ),
              ),
          const ConfirmNote(
              'Les permissions non définies par les specs restent « à décider » : l’app n’accorde aucun droit par implication.'),
        ],
      ),
    );
  }
}

class DashboardRolesScreen extends StatelessWidget {
  const DashboardRolesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l1 = appStore.pendingLevel1.length;
    final l2 = appStore.pendingLevel2.length;
    final occupied = appStore.occupancy
        .where((o) => appStore.displayedOccupancy(o) == OccupancyState.occupe)
        .length;
    final openIncidents = appStore.incidents
        .where((i) =>
            i.status == IncidentStatus.signale ||
            i.status == IncidentStatus.enExamen ||
            i.status == IncidentStatus.enCours)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord — Rôles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Pour les valideurs, techniciens et administrateurs.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Demandes à valider — Niveau 1'),
              subtitle: Text('$l1 demande(s) dans votre périmètre.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                goToTab(0);
                Navigator.pop(context);
                showOk(context,
                    'Ouvrez « Validations » depuis le menu ⋮ en haut à droite.');
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Validation technique — Niveau 2'),
              subtitle: Text('$l2 demande(s) prête(s) pour la validation finale.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showOk(context,
                    'Ouvrez « Validations » depuis le menu ⋮ en haut à droite.');
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Technicien / Régisseur'),
              subtitle: Text(
                  '$occupied studio(s) occupé(s), $openIncidents incident(s) en cours.'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Administrateur'),
              subtitle: const Text(
                  'Planning global, équipement, blocs et rapports.'),
            ),
          ),
          const ConfirmNote(
              'Le périmètre affiché ici est celui de la démonstration locale : en production, chaque valideur ne voit que son périmètre autorisé.'),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide & Contact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text('Comment réserver ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('1 · Choisissez un studio et un usage.\n'
              '2 · Choisissez un créneau futur.\n'
              '3 · Ajoutez le matériel, signez la charte.\n'
              '4 · Suivez En attente entité → En attente studio → Validée.'),
          SizedBox(height: 20),
          Text('Contacter les Studios',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
              'Coordonnées institutionnelles à compléter par l’équipe (non inventées ici). Signalez un incident depuis la session concernée ou depuis l’onglet Régie.'),
          SizedBox(height: 20),
          Text('Confidentialité',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
              'Notifications sans fichiers sensibles. Accès QR attribué à la réservation, non partageable. Les données de cette version de démonstration restent sur le téléphone.'),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres — Notifications')),
      body: ListView(
        children: [
          const ConfirmNote(
              'Les résultats de réservation restent obligatoires et ne peuvent pas être désactivés.'),
          SwitchListTile(
            title: const Text('Notifications de réservation'),
            subtitle: const Text('Obligatoires — non désactivables.'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            title: const Text('Notifications de projet'),
            subtitle: const Text(
                'Invitations, corrections, contrôle qualité, livraison.'),
            value: appStore.config.projectNotificationsEnabled,
            onChanged: (v) {
              appStore.setProjectNotifications(v);
              showOk(context,
                  v ? 'Notifications de projet activées.' : 'Notifications de projet désactivées.');
            },
          ),
          SwitchListTile(
            title: const Text('Notifications d’incident'),
            subtitle: const Text('Réservées aux techniciens et administrateurs.'),
            value: true,
            onChanged: null,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Aucune notification n’expose de fichier sensible ni de lien privé. Une notification renvoie toujours vers l’enregistrement concerné.',
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }
}

/// Écran des états globaux U1–U4 (spec : réconciliation après opération).
class StatesScreen extends StatefulWidget {
  const StatesScreen({super.key});
  @override
  State<StatesScreen> createState() => _StatesScreenState();
}

class _StatesScreenState extends State<StatesScreen> {
  String? _result;
  @override
  Widget build(BuildContext context) {
    final last = appStore.bookings.isEmpty ? null : appStore.bookings.first;
    return Scaffold(
      appBar: AppBar(title: const Text('États & récupération')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Vérification du résultat (U1)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Après chaque action (envoi, validation, refus, annulation), l’app relit l’état réel de la demande avant d’afficher un succès. En cas de doute, utilisez « Vérifier le résultat » ci-dessous : aucune action n’est rejouée à l’aveugle.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 12),
          if (last != null)
            Card(
              child: ListTile(
                title: Text('Dernière demande : ${last.id} — ${last.title}'),
                subtitle: Text('Statut actuel : ${last.status.label}'),
                trailing: FilledButton(
                  onPressed: () => setState(
                      () => _result = appStore.checkOutcome(last.id)),
                  child: const Text('Vérifier'),
                ),
              ),
            ),
          if (_result != null)
            ConfirmNote(_result!),
          if (appStore.lastOutcome != null)
            Card(
              child: ListTile(
                title: const Text('Dernier résultat enregistré (U3)'),
                subtitle: Text(appStore.lastOutcome!),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Résultat inconnu (U2)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Si une opération est interrompue (réseau, fermeture de l’app), l’état affiché serait « Résultat inconnu » jusqu’à vérification — jamais un succès inventé, jamais un échec présenté comme un créneau indisponible. En local, les opérations sont immédiates : cet état est présenté ici à titre de règle, pas comme un cas simulé.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          const Text('Action non enregistrée (U4)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text(
              'Si la vérification prouve que l’opération n’a pas été engagée, l’action peut être rejouée en toute sécurité. Un refus déjà engagé n’est jamais rejoué ni re-notifié.',
              style: TextStyle(color: AppColors.secondary)),
        ],
      ),
    );
  }
}
