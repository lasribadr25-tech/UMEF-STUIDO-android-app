// Couche de persistance — Euromed Studios.
//
// Le métier (lib/store.dart, AppStore) ne parle JAMAIS directement à SQLite,
// à SharedPreferences ou à un futur backend : il ne connaît que cette
// interface et le snapshot ci-dessous. C'est ce qui rend le futur passage à
// Firebase possible sans réécrire les écrans ni les règles métier.
//
// Implémentation actuelle (gratuite, locale, hors ligne) :
//   lib/data/sqlite_repository.dart  (SqliteAppRepository, sqflite)
//
// Implémentation future (NON configurée — choix ultérieur de badr) :
//   un FirebaseAppRepository implémentant la même interface, branché ici
//   par injection dans AppStore(repository: ...). Voir la section
//   « Plus tard : Firebase » du README pour la correspondance
//   tables SQLite → collections Firestore :
//     current_user      → users/{userId} (doc de session, hors démo)
//     bookings          → bookings/{bookingId}
//     booking_equipment → bookings/{bookingId}.equipment (sous-collection)
//     projects          → projects/{projectId}
//     project_invites   → projects/{projectId}.invites
//     project_corrections → projects/{projectId}.corrections
//     incidents         → incidents/{incidentId}
//     equipment         → equipment/{itemId}
//     maintenance_blocks→ maintenance_blocks/{blockId}
//     notifications     → notifications/{notificationId}
//     occupancy         → occupancy/{spaceId}
//     audit             → audit/{entryId}
//     config            → config/app (document unique)
//   Les règles qui doivent alors devenir des transactions Firestore /
//   des règles de sécurité (et non plus des vérifications locales) sont :
//   création d'une réservation + contrôle quota + pré-verrouillage,
//   transitions d'approbation L1/L2 (état attendu vérifié au moment de
//   l'engagement, pas d'écrasement d'un état terminal, une seule
//   notification par refus engagé), et le comptage quota hebdomadaire.
//   Tant que cette implémentation n'existe pas, AUCUNE donnée ne quitte
//   le téléphone et rien n'est partagé entre téléphones.
import '../models.dart';

/// État complet de l'application, tel que persisté d'un coup.
/// Un snapshot est toujours écrit en une seule transaction SQLite
/// (voir SqliteAppRepository.save) : jamais d'écriture partielle.
class AppSnapshot {
  CurrentUser? user;
  List<Booking> bookings;
  List<Project> projects;
  List<Incident> incidents;
  List<EquipmentItem> equipment;
  List<MaintenanceBlock> blocks;
  List<AppNotification> notifications;
  List<Occupancy> occupancy;
  List<AuditEntry> audit;
  AppConfig config;

  AppSnapshot({
    required this.user,
    required this.bookings,
    required this.projects,
    required this.incidents,
    required this.equipment,
    required this.blocks,
    required this.notifications,
    required this.occupancy,
    required this.audit,
    required this.config,
  });
}

/// Contrat de persistance. Toute implémentation doit garantir :
/// - load() == null si aucune donnée n'a jamais été sauvegardée ;
/// - save() atomique (tout ou rien) ;
/// - weeklyHoursUsedFromDb() calculé depuis la source persistée, pas
///   depuis la mémoire, pour que le quota survive à un redémarrage.
abstract class AppRepository {
  Future<AppSnapshot?> load();
  Future<void> save(AppSnapshot snapshot);
  Future<int> weeklyHoursUsedFromDb(
      String userName, AppRole role, DateTime weekStart);
}
