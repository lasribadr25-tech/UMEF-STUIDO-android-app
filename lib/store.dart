// État global + règles métier — Euromed Studios (Figma + specs GitHub Phase 1).
// Persistance locale via SQLite (lib/data/sqlite_repository.dart), gratuite
// et hors ligne : aucun serveur n'est requis pour tester, aucune donnée ne
// quitte le téléphone. Le store ne connaît que l'interface AppRepository
// (lib/data/repository.dart) : le futur passage à Firebase se fera en
// branchant une autre implémentation de cette interface, sans toucher aux
// écrans ni aux règles ci-dessous. Les opérations qui changent un statut
// sont sérialisées dans ce store local (une seule écriture à la fois,
// vérification de l'état au moment de l'engagement) et chaque sauvegarde
// est une seule transaction SQLite (tout ou rien) — l'équivalent local des
// invariants atomiques exigés par les specs pour un futur backend (pas de
// double validation, pas de refus qui écrase un état terminal, une seule
// notification par refus engagé).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/repository.dart';
import 'data/sqlite_repository.dart';
import 'models.dart';

class BookingException implements Exception {
  final String message;
  BookingException(this.message);
  @override
  String toString() => message;
}

/// Créneaux horaires proposés (Figma, pages Réserver) : 08h–18h, pause 13h–14h.
const List<int> kSlotHours = [8, 9, 10, 11, 12, 14, 15, 16, 17];

class AppStore extends ChangeNotifier {
  /// Ancienne clé SharedPreferences, lue UNE seule fois pour la migration.
  static const _legacyKey = 'uemf_figma_state_v1';
  static const _migratedKey = 'uemf_figma_sp_migrated_v1';

  /// Compteur monotone : SQLite impose l'unicité des ID, contrairement
  /// à l'ancien JSON. Deux notifications créées dans la même milliseconde
  /// (ex. deux expirations dans refreshStatuses) ne doivent jamais
  /// partager un ID, sinon la transaction échoue.
  static int _idSeq = 0;
  static String _uniqueId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${_idSeq++}';

  /// Dépôt injecté (tests) ou SQLite par défaut (application).
  final AppRepository _repository;
  AppStore({AppRepository? repository})
      : _repository = repository ?? SqliteAppRepository();

  AppRepository get repository => _repository;

  CurrentUser? user;
  List<Booking> bookings = [];
  List<Project> projects = [];
  List<Incident> incidents = [];
  List<EquipmentItem> equipment = [];
  List<MaintenanceBlock> blocks = [];
  List<AppNotification> notifications = [];
  List<Occupancy> occupancy = [];
  List<AuditEntry> audit = [];
  AppConfig config = AppConfig.defaults();
  bool loaded = false;
  String? lastOutcome; // U1–U4 : résultat de la dernière opération vérifiable

  void _applySnapshot(AppSnapshot s) {
    user = s.user;
    bookings = s.bookings;
    projects = s.projects;
    incidents = s.incidents;
    equipment = s.equipment;
    blocks = s.blocks;
    notifications = s.notifications;
    occupancy = s.occupancy;
    audit = s.audit;
    config = s.config;
    if (equipment.isEmpty) equipment = _defaultEquipment();
    if (occupancy.isEmpty) occupancy = _defaultOccupancy();
  }

  AppSnapshot _snapshot() => AppSnapshot(
        user: user,
        bookings: bookings,
        projects: projects,
        incidents: incidents,
        equipment: equipment,
        blocks: blocks,
        notifications: notifications,
        occupancy: occupancy,
        audit: audit,
        config: config,
      );

  /// Lecture de l'ancien format SharedPreferences (JSON unique), utilisée
  /// uniquement par la migration. Retourne null si le format est illisible.
  AppSnapshot? _legacySnapshot(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return AppSnapshot(
        user: j['user'] == null
            ? null
            : CurrentUser(
                j['user']['name'], AppRole.values[j['user']['role']]),
        bookings: (j['bookings'] as List)
            .map((e) => Booking.fromJson(e))
            .toList(),
        projects: (j['projects'] as List)
            .map((e) => Project.fromJson(e))
            .toList(),
        incidents: (j['incidents'] as List)
            .map((e) => Incident.fromJson(e))
            .toList(),
        equipment: (j['equipment'] as List)
            .map((e) => EquipmentItem.fromJson(e))
            .toList(),
        blocks: (j['blocks'] as List)
            .map((e) => MaintenanceBlock.fromJson(e))
            .toList(),
        notifications: (j['notifications'] as List)
            .map((e) => AppNotification.fromJson(e))
            .toList(),
        occupancy: (j['occupancy'] as List)
            .map((e) => Occupancy.fromJson(e))
            .toList(),
        audit: (j['audit'] as List)
            .map((e) => AuditEntry.fromJson(e))
            .toList(),
        config: j['config'] != null
            ? AppConfig.fromJson(j['config'])
            : AppConfig.defaults(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    final existing = await _repository.load();
    if (existing != null) {
      _applySnapshot(existing);
    } else {
      // Première ouverture avec SQLite : migration unique depuis
      // SharedPreferences si des données anciennes existent, sinon démo.
      var migrated = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final already = prefs.getBool(_migratedKey) ?? false;
        final raw = already ? null : prefs.getString(_legacyKey);
        if (raw != null) {
          final legacy = _legacySnapshot(raw);
          if (legacy != null) {
            _applySnapshot(legacy);
            migrated = true;
          }
        }
        if (migrated) {
          // Drapeau de migration : l'import ne sera jamais rejoué, même
          // si l'utilisateur réinitialise ensuite la démo dans SQLite.
          // L'ancienne clé est conservée intacte comme sauvegarde.
          await prefs.setBool(_migratedKey, true);
        }
      } catch (_) {
        // Aucune donnée ancienne lisible : on retombe sur la démo.
      }
      if (!migrated) _seed();
      await _save();
    }
    refreshStatuses(notify: false);
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() => _repository.save(_snapshot());

  /// Version attendable de _save(), pour les tests et la réinitialisation.
  Future<void> saveNow() => _save();

  Future<void> resetDemo() async {
    _seed();
    refreshStatuses(notify: false);
    await _save();
    notifyListeners();
  }

  List<EquipmentItem> _defaultEquipment() => [
        EquipmentItem(
            id: 'kit_camera',
            name: 'Kit caméra mobile',
            category: 'Vidéo',
            totalQty: 2,
            status: EquipmentStatus.disponible,
            description:
                'Caméra mobile avec trépied et accessoires. Quantité à confirmer par UEMF.'),
        EquipmentItem(
            id: 'kit_micro',
            name: 'Kit microphone mobile',
            category: 'Audio',
            totalQty: 3,
            status: EquipmentStatus.disponible,
            description:
                'Microphones HF mobiles. Quantité à confirmer par UEMF.'),
        EquipmentItem(
            id: 'kit_lumiere',
            name: 'Kit lumière mobile',
            category: 'Éclairage',
            totalQty: 2,
            status: EquipmentStatus.bloque,
            description:
                'Panneaux LED mobiles. Un kit est actuellement bloqué pour maintenance (voir Incidents).'),
      ];

  List<Occupancy> _defaultOccupancy() {
    final now = DateTime.now();
    return [
      for (final s in kSpaces)
        Occupancy(
            spaceId: s.id,
            state: s.id == 'podcast'
                ? OccupancyState.occupe
                : s.id == 'plateau_tv'
                    ? OccupancyState.occupe
                    : OccupancyState.libre,
            updatedAt: now.subtract(const Duration(minutes: 5))),
    ];
  }

  void _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    equipment = _defaultEquipment();
    occupancy = _defaultOccupancy();
    blocks = [];
    bookings = [
      Booking(
        id: 'B-1001', spaceId: 'podcast', userName: 'Mouhssine',
        userRole: AppRole.etudiant, title: 'Voix du campus',
        purpose: 'Enregistrement de l’épisode 01 du podcast étudiant.',
        date: tomorrow, startHour: 10, durationHours: 1,
        usage: UsageType.enregistrement,
        equipment: [EquipmentRequest(itemId: 'kit_camera', qty: 1, required: true)],
        status: BookingStatus.validee, charterSigned: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Booking(
        id: 'B-1002', spaceId: 'pedagogique', userName: 'Pr. El Amrani',
        userRole: AppRole.professeur, title: 'MOOC — Introduction à l’IA',
        purpose: 'Enregistrement du module 1 du MOOC.',
        date: today, startHour: 14, durationHours: 2,
        usage: UsageType.enregistrement, equipment: [],
        status: BookingStatus.attenteStudio, charterSigned: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Booking(
        id: 'B-1003', spaceId: 'plateau_tv', userName: 'Équipe Com UEMF',
        userRole: AppRole.communication, title: 'Rencontres Euromed',
        purpose: 'Captation de la cérémonie Rencontres Euromed.',
        date: tomorrow, startHour: 9, durationHours: 2,
        usage: UsageType.captation,
        equipment: [EquipmentRequest(itemId: 'kit_lumiere', qty: 2, required: false)],
        status: BookingStatus.attenteEntite, charterSigned: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Booking(
        id: 'B-1004', spaceId: 'chroma', userName: 'Salma B. (Club Cinéma)',
        userRole: AppRole.club, title: 'Court-métrage — fond vert',
        purpose: 'Captation fond vert pour le court-métrage du club.',
        date: tomorrow, startHour: 15, durationHours: 2,
        usage: UsageType.captation,
        equipment: [EquipmentRequest(itemId: 'kit_camera', qty: 1, required: true)],
        status: BookingStatus.attenteEntite, charterSigned: true,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Booking(
        id: 'B-1005', spaceId: 'podcast', userName: 'Mouhssine',
        userRole: AppRole.etudiant, title: 'Voix du campus — refusée',
        purpose: 'Demande refusée : motif visible dans la demande.',
        date: yesterday, startHour: 14, durationHours: 1,
        usage: UsageType.enregistrement, equipment: [],
        status: BookingStatus.refusee, refusalReason: 'Créneau déjà attribué à une production institutionnelle.',
        charterSigned: true, createdAt: now.subtract(const Duration(days: 3)),
      ),
      Booking(
        id: 'B-1006', spaceId: 'radio', userName: 'Mouhssine',
        userRole: AppRole.etudiant, title: 'Voix du campus — annulée',
        purpose: 'Demande annulée par le demandeur avant le début.',
        date: tomorrow, startHour: 16, durationHours: 1,
        usage: UsageType.mixage, equipment: [],
        status: BookingStatus.annulee, charterSigned: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      // En attente depuis hier : refreshStatuses() la fera passer à Expirée.
      Booking(
        id: 'B-1007', spaceId: 'speedmooc', userName: 'Pr. El Amrani',
        userRole: AppRole.professeur, title: 'MOOC — capsule expirée',
        purpose: 'Demande restée en attente après le début du créneau.',
        date: yesterday, startHour: 10, durationHours: 1,
        usage: UsageType.enregistrement, equipment: [],
        status: BookingStatus.attenteEntite, charterSigned: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    projects = [
      Project(
        id: 'P-01', title: 'Voix du campus', type: ProjectType.culture,
        stage: ProjectStage.production, editingStatus: 'En cours',
        ownerName: 'Mouhssine', ownerRole: AppRole.etudiant,
        collaborators: ['Omar F.'], invites: [],
        documents: ['Conducteur_ep01.pdf'], corrections: [],
        linkedBookingId: 'B-1001',
      ),
      Project(
        id: 'P-02', title: 'MOOC — Introduction à l’IA',
        type: ProjectType.enseignement, stage: ProjectStage.postproduction,
        editingStatus: 'Correction demandée',
        ownerName: 'Pr. El Amrani', ownerRole: AppRole.professeur,
        collaborators: ['Yasmine T. (monitrice)', 'Karim R. (technicien)'],
        invites: [], documents: ['Script_MOOC_IA.pdf', 'Conducteur_seance1.docx'],
        corrections: [Correction(text: 'Raccourcir l’introduction (00:00–00:45).')],
        linkedBookingId: 'B-1002',
      ),
      Project(
        id: 'P-03', title: 'Rencontres Euromed',
        type: ProjectType.communication, stage: ProjectStage.preproduction,
        ownerName: 'Équipe Com UEMF', ownerRole: AppRole.communication,
        collaborators: [], invites: [],
        documents: ['Storyboard_rentree.pdf'], corrections: [],
      ),
    ];
    incidents = [
      Incident(
        id: 'I-01', spaceId: 'chroma', equipmentId: 'kit_lumiere',
        title: 'Lumière HS — Chroma',
        description: 'Un panneau LED du kit lumière ne s’allume plus.',
        reporterName: 'Karim R.', severity: Severity.haute,
        status: IncidentStatus.enCours, createdAt: now.subtract(const Duration(days: 1)),
      ),
      Incident(
        id: 'I-02', spaceId: 'podcast', title: 'Micro grésille — Podcast',
        description: 'Le micro grésille dès le début de la session.',
        reporterName: 'Mouhssine', severity: Severity.moyenne,
        status: IncidentStatus.signale, bookingId: 'B-1001',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ];
    notifications = [
      AppNotification(
        id: 'N-01', title: 'Réservation validée', kind: 'réservation',
        body: 'Studio Podcast · ${fmtDay(tomorrow)} · 10:00–11:00 — Voix du campus.',
        bookingId: 'B-1001', mandatory: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'N-02', title: 'Demande reçue', kind: 'réservation',
        body: 'Plateau TV · Rencontres Euromed — En attente entité.',
        bookingId: 'B-1003', mandatory: true, read: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: 'N-03', title: 'Réservation refusée', kind: 'réservation',
        body: 'Motif enregistré disponible dans la demande (B-1005).',
        bookingId: 'B-1005', mandatory: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: 'N-04', title: 'Correction demandée', kind: 'projet',
        body: 'Projet MOOC — Introduction à l’IA : raccourcir l’introduction.',
        projectId: 'P-02',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ];
    audit = [
      AuditEntry(
          id: 'A-01', action: 'Validation Niveau 2',
          detail: 'B-1001 validée (Studio Podcast).',
          actor: 'Responsable des Studios',
          createdAt: now.subtract(const Duration(hours: 3))),
    ];
    config = AppConfig.defaults();
    lastOutcome = null;
  }

  // ---------- Session ----------
  void login(String name, AppRole role) {
    user = CurrentUser(name, role);
    _save();
    notifyListeners();
  }

  void loginGuest() {
    user = const CurrentUser('Invité', AppRole.invite);
    _save();
    notifyListeners();
  }

  void logout() {
    user = null;
    _save();
    notifyListeners();
  }

  // ---------- Règles : dates, quotas, conflits ----------
  DateTime _weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int weeklyHoursUsed(String userName, AppRole role, DateTime anyDayInWeek) {
    final start = _weekStart(anyDayInWeek);
    final end = start.add(const Duration(days: 7));
    var total = 0;
    for (final b in bookings) {
      if (b.userName == userName &&
          b.userRole == role &&
          b.status.countsTowardQuota &&
          !b.date.isBefore(start) &&
          b.date.isBefore(end)) {
        total += b.durationHours;
      }
    }
    return total;
  }

  int? quotaFor(AppRole role) => config.quotas[role];

  int? remainingQuota(String userName, AppRole role, DateTime date, int hours,
      {String? excludeBookingId}) {
    final quota = quotaFor(role);
    if (quota == null) return null;
    var used = weeklyHoursUsed(userName, role, date);
    if (excludeBookingId != null) {
      final old = bookings.where((b) => b.id == excludeBookingId).toList();
      if (old.isNotEmpty && old.first.status.countsTowardQuota) {
        used -= old.first.durationHours;
      }
    }
    return quota - used;
  }

  bool isBlockedByMaintenance(
      String spaceId, DateTime date, int start, int end) {
    return blocks.any((b) => b.spaceId == spaceId && b.overlaps(date, start, end));
  }

  bool hasConflict(String spaceId, DateTime date, int start, int end,
      {String? excludeBookingId}) {
    // Règle début inclus / fin exclue : fin à 10h00 ne bloque pas 10h00.
    return bookings.any((b) =>
        b.id != excludeBookingId &&
        b.spaceId == spaceId &&
        b.status.isBlocking &&
        b.overlaps(date, start, end));
  }

  /// État d'un créneau horaire pour l'écran de réservation (Figma).
  String slotState(String spaceId, DateTime date, int hour) {
    if (hour == 13) return 'Indisponible';
    if (isBlockedByMaintenance(spaceId, date, hour, hour + 1)) {
      return 'Indisponible';
    }
    if (hasConflict(spaceId, date, hour, hour + 1)) return 'Pré-verrouillé';
    return 'Libre';
  }

  void _checkInterval(DateTime date, int start, int duration) {
    final now = DateTime.now();
    final startDt = DateTime(date.year, date.month, date.day, start);
    if (!startDt.isAfter(now)) {
      throw BookingException(
          'Le créneau doit être dans le futur (heure du campus).');
    }
    if (start < 8 || start + duration > 18) {
      throw BookingException('Les créneaux vont de 08:00 à 18:00.');
    }
    if (start < 13 && start + duration > 13) {
      throw BookingException(
          'La pause de 13:00 à 14:00 ne peut pas être traversée par une réservation.');
    }
  }

  void _checkQuotaAndConflict(Booking draft, {String? excludeBookingId}) {
    final remaining = remainingQuota(draft.userName, draft.userRole, draft.date,
        draft.durationHours,
        excludeBookingId: excludeBookingId);
    final quota = quotaFor(draft.userRole);
    if (remaining != null && draft.durationHours > remaining) {
      throw BookingException(
          'Quota hebdomadaire dépassé : il reste $remaining h cette semaine (quota configuré : $quota h — valeur à confirmer par UEMF).');
    }
    if (isBlockedByMaintenance(draft.spaceId, draft.date, draft.startHour,
        draft.endHour)) {
      throw BookingException(
          'Studio bloqué pour maintenance ou raison administrative sur ce créneau.');
    }
    if (hasConflict(draft.spaceId, draft.date, draft.startHour, draft.endHour,
        excludeBookingId: excludeBookingId)) {
      throw BookingException(
          'Créneau déjà pré-verrouillé pour ${spaceById(draft.spaceId).name}. Choisissez un autre horaire.');
    }
  }

  Booking submitBooking(Booking draft) {
    if (draft.title.trim().isEmpty) {
      throw BookingException('Le nom de la session / du projet est obligatoire.');
    }
    if (draft.purpose.trim().isEmpty) {
      throw BookingException('L’objet de la demande est obligatoire.');
    }
    if (!draft.charterSigned) {
      throw BookingException(
          'La charte de responsabilité doit être acceptée et signée avant l’envoi.');
    }
    if (!spaceById(draft.spaceId).bookable) {
      throw BookingException(
          'Cet espace est un espace support, hors réservation directe.');
    }
    _checkInterval(draft.date, draft.startHour, draft.durationHours);
    _checkQuotaAndConflict(draft);
    draft.status = BookingStatus.attenteEntite;
    bookings = [draft, ...bookings];
    _notify(
        title: 'Demande reçue',
        body:
            '${spaceById(draft.spaceId).name} · ${fmtDay(draft.date)} · ${draft.slotLabel} — En attente entité.',
        kind: 'réservation', bookingId: draft.id, mandatory: true);
    lastOutcome =
        'Action enregistrée : demande ${draft.id} créée — En attente entité. Créneau pré-verrouillé.';
    _save();
    notifyListeners();
    return draft;
  }

  void modifyBooking(String id, DateTime date, int start, int duration) {
    final b = bookings.firstWhere((x) => x.id == id);
    if (user == null || b.userName != user!.name) {
      throw BookingException('Seul le demandeur peut modifier sa demande.');
    }
    if (b.status != BookingStatus.attenteEntite &&
        b.status != BookingStatus.attenteStudio &&
        b.status != BookingStatus.validee) {
      throw BookingException('Cette demande ne peut plus être modifiée (statut : ${b.status.label}).');
    }
    if (!b.startDateTime.isAfter(DateTime.now())) {
      throw BookingException('La demande ne peut plus être modifiée après son début.');
    }
    final draft = Booking(
      id: b.id, spaceId: b.spaceId, userName: b.userName, userRole: b.userRole,
      title: b.title, purpose: b.purpose, date: date, startHour: start,
      durationHours: duration, usage: b.usage, equipment: b.equipment,
      status: b.status, charterSigned: b.charterSigned, createdAt: b.createdAt,
    );
    _checkInterval(date, start, duration);
    _checkQuotaAndConflict(draft, excludeBookingId: id);
    b.date = date;
    b.startHour = start;
    b.durationHours = duration;
    lastOutcome = 'Action enregistrée : demande $id modifiée.';
    _save();
    notifyListeners();
  }

  void cancelBooking(String id) {
    final b = bookings.firstWhere((x) => x.id == id);
    if (user == null || b.userName != user!.name) {
      throw BookingException('Seul le demandeur peut annuler sa demande.');
    }
    if (b.status != BookingStatus.attenteEntite &&
        b.status != BookingStatus.attenteStudio &&
        b.status != BookingStatus.validee) {
      throw BookingException('Cette demande ne peut plus être annulée (statut : ${b.status.label}).');
    }
    if (!b.startDateTime.isAfter(DateTime.now())) {
      throw BookingException('Une demande ne peut pas être annulée après son début.');
    }
    b.status = BookingStatus.annulee; // libère créneau + ressources (spec)
    _notify(
        title: 'Réservation annulée',
        body: '${b.title} · ${fmtDay(b.date)} · ${b.slotLabel}.',
        kind: 'réservation', bookingId: b.id, mandatory: true);
    lastOutcome = 'Action enregistrée : demande $id annulée. Le créneau est libéré.';
    _save();
    notifyListeners();
  }

  // ---------- Approbations ----------
  void _checkNotSelf(Booking b) {
    if (user != null && user!.name == b.userName) {
      throw BookingException(
          'Auto-approbation interdite, y compris en cas de cumul de fonctions : un autre valideur doit décider.');
    }
  }

  void approveLevel1(String id) {
    final b = bookings.firstWhere((x) => x.id == id);
    _checkNotSelf(b);
    if (b.status != BookingStatus.attenteEntite) {
      throw BookingException(
          'Décision impossible : la demande n’est plus En attente entité (statut actuel : ${b.status.label}).');
    }
    if (!b.startDateTime.isAfter(DateTime.now())) {
      b.status = BookingStatus.expiree;
      _save();
      notifyListeners();
      throw BookingException('La demande a expiré (début du créneau atteint).');
    }
    b.status = BookingStatus.attenteStudio;
    _audit('Validation Niveau 1', '$id approuvée (→ En attente studio).');
    _notify(
        title: 'Demande transmise au studio',
        body: '${b.title} · ${fmtDay(b.date)} · ${b.slotLabel} — En attente studio.',
        kind: 'réservation', bookingId: b.id, mandatory: true);
    lastOutcome = 'Action enregistrée : $id → En attente studio.';
    _save();
    notifyListeners();
  }

  void refuse(String id, String reason, {required int level}) {
    final b = bookings.firstWhere((x) => x.id == id);
    if (reason.trim().isEmpty) {
      throw BookingException('Un refus exige un motif (obligatoire).');
    }
    _checkNotSelf(b);
    final expected = level == 1
        ? BookingStatus.attenteEntite
        : BookingStatus.attenteStudio;
    if (b.status != expected) {
      // Un état terminal ou une décision concurrente a déjà gagné : on ne
      // l'écrase pas et on n'envoie pas de seconde notification (spec).
      throw BookingException(
          'Décision impossible : la demande n’est plus dans l’état attendu (statut actuel : ${b.status.label}). Aucune notification n’a été envoyée.');
    }
    b.status = BookingStatus.refusee;
    b.refusalReason = reason.trim();
    _audit('Refus Niveau $level', '$id refusée — motif : ${b.refusalReason}.');
    _notify(
        title: 'Réservation refusée',
        body: '${b.title} · Motif : ${b.refusalReason}',
        kind: 'réservation', bookingId: b.id, mandatory: true);
    lastOutcome = 'Action enregistrée : $id refusée. Le demandeur est notifié.';
    _save();
    notifyListeners();
  }

  /// Vérifications techniques du Niveau 2 (spec Issue #5 + #7).
  /// Retourne la liste des blocages ; vide = validation possible.
  List<String> level2Blockers(Booking b) {
    final blockers = <String>[];
    if (!b.startDateTime.isAfter(DateTime.now())) {
      blockers.add('Le créneau a déjà commencé.');
    }
    if (isBlockedByMaintenance(b.spaceId, b.date, b.startHour, b.endHour)) {
      blockers.add('Bloc maintenance / administratif sur ce créneau.');
    }
    final others = bookings.where((o) =>
        o.id != b.id &&
        o.spaceId == b.spaceId &&
        o.status.isBlocking &&
        o.overlaps(b.date, b.startHour, b.endHour));
    if (others.isNotEmpty) {
      blockers.add('Conflit avec une autre réservation bloquante.');
    }
    for (final req in b.equipment) {
      final item = equipment.firstWhere((e) => e.id == req.itemId,
          orElse: () => EquipmentItem(
              id: req.itemId, name: req.itemId, category: '',
              totalQty: 0, status: EquipmentStatus.bloque, description: ''));
      if (item.status == EquipmentStatus.bloque) {
        if (req.required) {
          blockers.add('Élément requis indisponible : ${item.name} (maintenance).');
        }
      } else {
        var claimed = 0;
        for (final o in bookings) {
          if (o.id != b.id &&
              o.status == BookingStatus.validee &&
              o.overlaps(b.date, b.startHour, b.endHour)) {
            for (final r in o.equipment) {
              if (r.itemId == req.itemId) claimed += r.qty;
            }
          }
        }
        if (claimed + req.qty > item.totalQty) {
          if (req.required) {
            blockers.add(
                'Élément requis indisponible en quantité suffisante : ${item.name} (${item.totalQty} au total, $claimed déjà attribué(s)).');
          }
        }
      }
    }
    return blockers;
  }

  void approveLevel2(String id) {
    final b = bookings.firstWhere((x) => x.id == id);
    _checkNotSelf(b);
    if (b.status != BookingStatus.attenteStudio) {
      throw BookingException(
          'Décision impossible : la demande n’est plus En attente studio (statut actuel : ${b.status.label}).');
    }
    final blockers = level2Blockers(b);
    if (blockers.isNotEmpty) {
      throw BookingException(
          'Validation technique bloquée :\n• ${blockers.join('\n• ')}\nUtilisez « Refuser avec motif » pour notifier le demandeur.');
    }
    b.status = BookingStatus.validee;
    _audit('Validation Niveau 2', '$id validée techniquement (→ Validée, QR actif pendant le créneau).');
    _notify(
        title: 'Réservation validée',
        body: '${b.title} · ${fmtDay(b.date)} · ${b.slotLabel} — QR actif pendant le créneau.',
        kind: 'réservation', bookingId: b.id, mandatory: true);
    lastOutcome = 'Action enregistrée : $id → Validée. QR actif pendant le créneau.';
    _save();
    notifyListeners();
  }

  /// Transitions automatiques (spec) : en attente → Expirée au début,
  /// Validée → Terminée à la fin. Appelée à chaque ouverture et après action.
  void refreshStatuses({bool notify = true}) {
    final now = DateTime.now();
    var changed = false;
    for (final b in bookings) {
      if ((b.status == BookingStatus.attenteEntite ||
              b.status == BookingStatus.attenteStudio) &&
          !b.startDateTime.isAfter(now)) {
        b.status = BookingStatus.expiree;
        changed = true;
        _notify(
            title: 'Demande expirée',
            body: '${b.title} · ${fmtDay(b.date)} — approbation non terminée avant le début.',
            kind: 'réservation', bookingId: b.id, mandatory: true);
      } else if (b.status == BookingStatus.validee &&
          !b.endDateTime.isAfter(now)) {
        b.status = BookingStatus.terminee;
        changed = true;
      }
    }
    if (changed) _save();
    if (notify) notifyListeners();
  }

  // ---------- Projets ----------
  void addProject(Project p) {
    if (p.title.trim().isEmpty) {
      throw BookingException('Le nom du projet est obligatoire.');
    }
    projects = [p, ...projects];
    _save();
    notifyListeners();
  }

  void advanceProject(String id) {
    final p = projects.firstWhere((x) => x.id == id);
    if (p.archived) {
      throw BookingException('Ce projet est archivé.');
    }
    if (p.stage == ProjectStage.preproduction) {
      if (p.documents.isEmpty) {
        throw BookingException(
            'Pré-production incomplète : déposez au moins un document (script, conducteur ou storyboard) avant la production.');
      }
      if (p.linkedBookingId == null) {
        throw BookingException(
            'Liez d’abord une session Validée : la production ne peut pas démarrer sans créneau validé.');
      }
      final linked = bookings.where((b) => b.id == p.linkedBookingId).toList();
      if (linked.isEmpty || linked.first.status != BookingStatus.validee) {
        throw BookingException(
            'La session liée n’est pas Validée. La production est liée uniquement aux sessions Validées.');
      }
      p.stage = ProjectStage.production;
    } else if (p.stage == ProjectStage.production) {
      p.stage = ProjectStage.postproduction;
      p.editingStatus = 'En cours';
    } else if (p.stage == ProjectStage.postproduction) {
      if (p.corrections.any((c) => !c.resolved)) {
        throw BookingException(
            'Des corrections sont encore ouvertes. Résolvez-les avant le contrôle qualité.');
      }
      p.stage = ProjectStage.validation;
    }
    _save();
    notifyListeners();
  }

  void setEditingStatus(String id, String status) {
    final p = projects.firstWhere((x) => x.id == id);
    p.editingStatus = status;
    _save();
    notifyListeners();
  }

  void addDocument(String id, String name) {
    final p = projects.firstWhere((x) => x.id == id);
    if (name.trim().isEmpty) return;
    p.documents = [...p.documents, name.trim()];
    _save();
    notifyListeners();
  }

  void linkBooking(String projectId, String? bookingId) {
    final p = projects.firstWhere((x) => x.id == projectId);
    p.linkedBookingId = bookingId;
    _save();
    notifyListeners();
  }

  void requestCorrection(String projectId, String text) {
    final p = projects.firstWhere((x) => x.id == projectId);
    if (text.trim().isEmpty) {
      throw BookingException('Décrivez la correction demandée.');
    }
    p.corrections = [...p.corrections, Correction(text: text.trim())];
    p.editingStatus = 'Correction demandée';
    _notify(
        title: 'Correction demandée',
        body: 'Projet ${p.title} : $text',
        kind: 'projet', projectId: p.id);
    _save();
    notifyListeners();
  }

  void resolveCorrection(String projectId, int index) {
    final p = projects.firstWhere((x) => x.id == projectId);
    p.corrections[index].resolved = true;
    if (p.corrections.every((c) => c.resolved)) {
      p.editingStatus = 'Prêt pour CQ';
    }
    _save();
    notifyListeners();
  }

  void inviteCollaborator(String projectId, String name) {
    final p = projects.firstWhere((x) => x.id == projectId);
    if (name.trim().isEmpty) return;
    p.invites = [...p.invites, Invite(name: name.trim())];
    _notify(
        title: 'Invitation à un projet',
        body: '$name invité(e) sur « ${p.title} » — en attente de réponse.',
        kind: 'projet', projectId: p.id);
    _save();
    notifyListeners();
  }

  void respondInvite(String projectId, int index, bool accept) {
    final p = projects.firstWhere((x) => x.id == projectId);
    p.invites[index].status = accept ? 'acceptée' : 'refusée';
    if (accept && !p.collaborators.contains(p.invites[index].name)) {
      p.collaborators = [...p.collaborators, p.invites[index].name];
    }
    _save();
    notifyListeners();
  }

  void removeCollaborator(String projectId, String name) {
    final p = projects.firstWhere((x) => x.id == projectId);
    p.collaborators = p.collaborators.where((c) => c != name).toList();
    _save();
    notifyListeners();
  }

  void qcPass(String projectId, String deliveryLink) {
    final p = projects.firstWhere((x) => x.id == projectId);
    p.stage = ProjectStage.validation;
    p.archived = true;
    p.deliveryLink = deliveryLink.trim().isEmpty ? null : deliveryLink.trim();
    p.editingStatus = 'Prêt pour CQ';
    _notify(
        title: 'Livraison disponible',
        body: 'Projet ${p.title} : contrôle qualité réussi, projet archivé.',
        kind: 'projet', projectId: p.id);
    _save();
    notifyListeners();
  }

  void qcFail(String projectId, String reason) {
    final p = projects.firstWhere((x) => x.id == projectId);
    if (reason.trim().isEmpty) {
      throw BookingException('Le motif du refus qualité est obligatoire.');
    }
    p.stage = ProjectStage.postproduction;
    p.corrections = [...p.corrections, Correction(text: 'CQ : $reason')];
    p.editingStatus = 'Correction demandée';
    _notify(
        title: 'Contrôle qualité : correction requise',
        body: 'Projet ${p.title} : $reason',
        kind: 'projet', projectId: p.id);
    _save();
    notifyListeners();
  }

  // ---------- Incidents / maintenance / occupation ----------
  void addIncident(Incident incident) {
    if (incident.description.trim().isEmpty) {
      throw BookingException('Décrivez le problème constaté.');
    }
    incidents = [incident, ...incidents];
    _applyIncidentBlocking(incident);
    _notify(
        title: 'Incident signalé',
        body: '${incident.title} — ${incident.severity.label}.',
        kind: 'incident');
    _save();
    notifyListeners();
  }

  void _applyIncidentBlocking(Incident incident) {
    if (incident.severity != Severity.haute) return;
    if (incident.equipmentId != null) {
      final item = equipment.where((e) => e.id == incident.equipmentId).toList();
      if (item.isNotEmpty) item.first.status = EquipmentStatus.bloque;
    } else {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final block = MaintenanceBlock(
        id: _uniqueId('BL'),
        spaceId: incident.spaceId, date: day, startHour: 8, durationHours: 10,
        reason: 'Incident grave : ${incident.title}', createdBy: incident.reporterName,
      );
      blocks = [...blocks, block];
      incident.blockId = block.id;
    }
  }

  void setIncidentStatus(String id, IncidentStatus status) {
    final inc = incidents.firstWhere((x) => x.id == id);
    inc.status = status;
    if (status == IncidentStatus.resolu || status == IncidentStatus.ferme) {
      if (inc.blockId != null) {
        blocks = blocks.where((b) => b.id != inc.blockId).toList();
        inc.blockId = null;
      }
      if (inc.equipmentId != null &&
          !incidents.any((o) =>
              o.id != id &&
              o.equipmentId == inc.equipmentId &&
              o.blocksResource)) {
        final item = equipment.where((e) => e.id == inc.equipmentId).toList();
        if (item.isNotEmpty) item.first.status = EquipmentStatus.disponible;
      }
    }
    _save();
    notifyListeners();
  }

  void setIncidentSeverity(String id, Severity severity) {
    final inc = incidents.firstWhere((x) => x.id == id);
    final wasBlocking = inc.blocksResource;
    inc.severity = severity;
    if (!wasBlocking && inc.blocksResource) _applyIncidentBlocking(inc);
    _save();
    notifyListeners();
  }

  void setOccupancy(String spaceId, OccupancyState state) {
    final occ = occupancy.where((o) => o.spaceId == spaceId).toList();
    if (occ.isEmpty) {
      occupancy = [
        ...occupancy,
        Occupancy(spaceId: spaceId, state: state, updatedAt: DateTime.now())
      ];
    } else {
      occ.first.state = state;
      occ.first.updatedAt = DateTime.now();
    }
    _save();
    notifyListeners();
  }

  OccupancyState displayedOccupancy(Occupancy occ) {
    // Une information trop ancienne devient Inconnu (seuil configurable).
    if (DateTime.now().difference(occ.updatedAt).inMinutes >
        config.freshnessMinutes) {
      return OccupancyState.inconnu;
    }
    return occ.state;
  }

  // ---------- Administration ----------
  void setEquipmentStatus(String id, EquipmentStatus status) {
    final item = equipment.firstWhere((x) => x.id == id);
    item.status = status;
    _audit('Équipement', '${item.name} → ${status.label}.');
    _save();
    notifyListeners();
  }

  void setEquipmentQty(String id, int qty) {
    final item = equipment.firstWhere((x) => x.id == id);
    item.totalQty = qty;
    _audit('Équipement', '${item.name} : quantité totale = $qty.');
    _save();
    notifyListeners();
  }

  void addBlock(MaintenanceBlock block) {
    blocks = [...blocks, block];
    _audit('Bloc maintenance',
        '${spaceById(block.spaceId).name} · ${fmtDay(block.date)} ${block.startHour}h–${block.endHour}h : ${block.reason}');
    _save();
    notifyListeners();
  }

  void removeBlock(String id) {
    blocks = blocks.where((b) => b.id != id).toList();
    _save();
    notifyListeners();
  }

  void setQuota(AppRole role, int? hours) {
    config.quotas[role] = hours;
    _audit('Configuration',
        'Quota ${kRoles[role]!.label} = ${hours == null ? 'illimité' : '$hours h / semaine'}.');
    _save();
    notifyListeners();
  }

  void setFreshness(int minutes) {
    config.freshnessMinutes = minutes;
    _audit('Configuration', 'Seuil de fraîcheur occupation = $minutes min.');
    _save();
    notifyListeners();
  }

  void setProjectNotifications(bool enabled) {
    config.projectNotificationsEnabled = enabled;
    _save();
    notifyListeners();
  }

  // ---------- Notifications / journal ----------
  void _notify({
    required String title,
    required String body,
    required String kind,
    String? bookingId,
    String? projectId,
    bool mandatory = false,
  }) {
    if (kind == 'projet' && !config.projectNotificationsEnabled && !mandatory) {
      return;
    }
    notifications = [
      AppNotification(
        id: _uniqueId('N'),
        title: title, body: body, kind: kind, bookingId: bookingId,
        projectId: projectId, mandatory: mandatory, createdAt: DateTime.now(),
      ),
      ...notifications,
    ];
  }

  void _audit(String action, String detail) {
    audit = [
      AuditEntry(
        id: _uniqueId('A'),
        action: action, detail: detail,
        actor: user?.name ?? '—', createdAt: DateTime.now(),
      ),
      ...audit,
    ];
  }

  void markNotificationRead(String id) {
    final n = notifications.where((x) => x.id == id).toList();
    if (n.isNotEmpty) {
      n.first.read = true;
      _save();
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    _save();
    notifyListeners();
  }

  /// U1 : revérifier le résultat réel d'une opération (réconciliation).
  String checkOutcome(String bookingId) {
    final found = bookings.where((b) => b.id == bookingId).toList();
    if (found.isEmpty) return 'Demande introuvable.';
    final b = found.first;
    lastOutcome =
        'Résultat vérifié : ${b.id} — ${b.status.label} (${fmtDay(b.date)} · ${b.slotLabel}).';
    notifyListeners();
    return lastOutcome!;
  }

  // ---------- Vues dérivées ----------
  List<Booking> get myBookings => user == null
      ? []
      : bookings
          .where((b) => b.userName == user!.name && b.userRole == user!.role)
          .toList();

  List<Booking> get pendingLevel1 => bookings
      .where((b) => b.status == BookingStatus.attenteEntite)
      .toList();

  List<Booking> get pendingLevel2 => bookings
      .where((b) => b.status == BookingStatus.attenteStudio)
      .toList();

  List<Booking> bookingsOn(DateTime day) => bookings
      .where((b) =>
          b.status.isBlocking &&
          b.date.year == day.year &&
          b.date.month == day.month &&
          b.date.day == day.day)
      .toList()
    ..sort((a, b) => a.startHour.compareTo(b.startHour));

  Booking? get nextSession {
    final now = DateTime.now();
    final mine = myBookings
        .where((b) => b.status.isBlocking && b.startDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    if (mine.isNotEmpty) return mine.first;
    final any = bookings
        .where((b) => b.status == BookingStatus.validee && b.startDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return any.isEmpty ? null : any.first;
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  List<Booking> get myValidatedBookings => myBookings
      .where((b) => b.status == BookingStatus.validee)
      .toList();

  String newId(String prefix) => _uniqueId(prefix);
}

final AppStore appStore = AppStore();

const List<String> kMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];

String fmtDay(DateTime d) => '${d.day} ${kMonths[d.month - 1]} ${d.year}';
String fmtDayShort(DateTime d) => '${d.day} ${kMonths[d.month - 1]}';
