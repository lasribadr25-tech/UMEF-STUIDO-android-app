// Modèles — Euromed Studios (Figma MPCFrOf9lWTGoVmska985o + specs GitHub Phase 1).
// Règles sources (docs/specs) :
// - Rôles et routage Niveau 1 : product-scope-roles.md.
// - Cycle de vie : En attente entité → En attente studio → Validée, puis
//   Refusée / Annulée / Expirée / Terminée (reservations.md).
// - Équipement (quantité, requis/optionnel), projets (4 types, pipeline 4
//   étapes), incidents (5 statuts, gravité), notifications, QR, occupation,
//   administration : equipment-projects-maintenance-notifications-qr.md.
// Les valeurs marquées « à confirmer par UEMF » dans Figma ne sont PAS des
// règles inventées : elles sont configurables (voir AppConfig) et signalées
// comme telles dans l'interface et le README.

enum AppRole {
  etudiant,
  professeur,
  communication,
  club,
  externe,
  technique,
  approbateurEntite,
  approbateurStudio,
  admin,
  invite,
}

class RoleInfo {
  final String label;
  final String org;
  final String l1Authority;
  final int? quotaHoursPerWeek; // null = illimité. Valeur d'exemple, configurable.
  final String note;
  const RoleInfo(this.label, this.org, this.l1Authority, this.quotaHoursPerWeek,
      this.note);
}

const Map<AppRole, RoleInfo> kRoles = {
  AppRole.etudiant: RoleInfo('Étudiant', 'EIDIA',
      'Responsable de la Vie Étudiante', 2,
      'Accès limité par défaut. Quota d’exemple : 2 h / semaine, à confirmer par UEMF.'),
  AppRole.professeur: RoleInfo('Professeur / Enseignant-Chercheur', 'UEMF',
      'Doyen / Directeur d’établissement', 6,
      'Priorité sur Studio Pédagogique et Speed MOOC (mécanisme à confirmer : ne contourne ni l’approbation ni une réservation valide).'),
  AppRole.communication: RoleInfo('Équipe Communication', 'Direction de la Communication',
      'Directeur de la Communication', 8, 'Projets institutionnels (Plateau TV, Studio Podcast).'),
  AppRole.club: RoleInfo('Club Étudiant', 'Club',
      'Direction des Affaires Estudiantines', 4,
      'Un club est un groupe, pas un compte partagé : un représentant identifié agit pour lui. Désignation du représentant à confirmer.'),
  AppRole.externe: RoleInfo('Client Externe', 'Externe',
      'Vice-Présidence Exécutive', 4,
      'Profil commercial : suivi de devis, sans facturation ni paiement en V1.'),
  AppRole.technique: RoleInfo('Équipe Technique / Régisseur', 'Studios',
      'Responsable des Studios', null, 'Maintenance, planning, occupation des studios.'),
  AppRole.approbateurEntite: RoleInfo('Approbateur d’Entité (Niveau 1)', 'Entité',
      '—', null, 'Valide uniquement les demandes de son périmètre. Un refus exige un motif.'),
  AppRole.approbateurStudio: RoleInfo('Responsable des Studios (Niveau 2)', 'Studios',
      '—', null, 'Validation technique finale. Auto-approbation interdite, y compris en cas de cumul de fonctions.'),
  AppRole.admin: RoleInfo('Administrateur', 'Studios',
      '—', null, 'Planning global, équipement, blocs, rapports et journal. Périmètre limité, moindre privilège.'),
  AppRole.invite: RoleInfo('Invité (sans compte)', '—',
      '—', null, 'Consultation seulement. La réservation exige un compte.'),
};

/// Comptes de démonstration (aucun mot de passe en démo locale ; l’authentification
/// réelle UEMF relève du backend, hors périmètre de cette version locale).
class DemoAccount {
  final String name;
  final AppRole role;
  const DemoAccount(this.name, this.role);
}

const List<DemoAccount> kDemoAccounts = [
  DemoAccount('Mouhssine', AppRole.etudiant),
  DemoAccount('Pr. El Amrani', AppRole.professeur),
  DemoAccount('Équipe Com UEMF', AppRole.communication),
  DemoAccount('Salma B. (Club Cinéma)', AppRole.club),
  DemoAccount('Client Démo', AppRole.externe),
  DemoAccount('Karim R.', AppRole.technique),
  DemoAccount('Responsable Vie Étudiante', AppRole.approbateurEntite),
  DemoAccount('Responsable des Studios', AppRole.approbateurStudio),
  DemoAccount('Administrateur Studios', AppRole.admin),
];

enum UsageType { enregistrement, captation, montage, mixage }

extension UsageLabel on UsageType {
  String get label => switch (this) {
        UsageType.enregistrement => 'Enregistrement',
        UsageType.captation => 'Captation d’image',
        UsageType.montage => 'Montage',
        UsageType.mixage => 'Mixage audio',
      };
}

enum BookingStatus {
  attenteEntite,
  attenteStudio,
  validee,
  refusee,
  annulee,
  expiree,
  terminee,
}

extension BookingStatusLabel on BookingStatus {
  String get label => switch (this) {
        BookingStatus.attenteEntite => 'En attente entité',
        BookingStatus.attenteStudio => 'En attente studio',
        BookingStatus.validee => 'Validée',
        BookingStatus.refusee => 'Refusée',
        BookingStatus.annulee => 'Annulée',
        BookingStatus.expiree => 'Expirée',
        BookingStatus.terminee => 'Terminée',
      };
  bool get isBlocking => this == BookingStatus.attenteEntite ||
      this == BookingStatus.attenteStudio ||
      this == BookingStatus.validee;
  bool get countsTowardQuota =>
      isBlocking || this == BookingStatus.terminee;
  bool get isTerminal =>
      this == BookingStatus.refusee ||
      this == BookingStatus.annulee ||
      this == BookingStatus.expiree ||
      this == BookingStatus.terminee;
}

class StudioSpace {
  final String id;
  final String name;
  final String zone;
  final String tagline;
  final String description;
  final String? image;
  final int isolation; // étoiles 0-5
  final List<String> features;
  final bool bookable;
  const StudioSpace({
    required this.id,
    required this.name,
    required this.zone,
    required this.tagline,
    required this.description,
    this.image,
    required this.isolation,
    required this.features,
    required this.bookable,
  });
}

// Inventaire affiché par Figma (page 03) : 6 espaces + 2 espaces support.
// Figma précise pour chaque espace « Réservabilité à confirmer » : le badge
// est affiché dans l'app et l'inventaire définitif reste une question ouverte.
const List<StudioSpace> kSpaces = [
  StudioSpace(
    id: 'podcast',
    name: 'Studio Podcast',
    zone: 'Production',
    tagline: 'Captation audio · Isolation ★★★★★',
    description:
        'Captation audio, interviews et émissions. Le plus isolé du pôle : micros broadcast, régie dédiée, streaming.',
    image: 'assets/images/studio_podcast.jpg',
    isolation: 5,
    features: ['Audio Pro', 'Streaming', 'Régie dédiée'],
    bookable: true,
  ),
  StudioSpace(
    id: 'plateau_tv',
    name: 'Plateau TV / Web TV',
    zone: 'Production',
    tagline: 'Multicam · Téléprompteur',
    description:
        'Plateau télévision multi-caméras avec décor UEMF, régie dédiée et streaming live. Émissions et captations institutionnelles.',
    image: 'assets/images/plateau_tv.jpg',
    isolation: 4,
    features: ['Multicam', 'Téléprompteur', 'Streaming', 'Audio Pro'],
    bookable: true,
  ),
  StudioSpace(
    id: 'radio',
    name: 'Euromed Radio',
    zone: 'Production',
    tagline: 'Diffusion · Régie technique',
    description:
        'Studio radio : console de mixage, micros broadcast et diffusion en streaming. Isolation acoustique maximale.',
    image: 'assets/images/euromed_radio.jpg',
    isolation: 5,
    features: ['Audio Pro', 'Streaming', 'Diffusion'],
    bookable: true,
  ),
  StudioSpace(
    id: 'chroma',
    name: 'Chroma Key Studio',
    zone: 'Production',
    tagline: 'Fond vert · Post-production',
    description:
        'Studio fond vert avec éclairage complet : incrustations, présentations virtuelles et captations multicam.',
    image: 'assets/images/studio_photo.jpg',
    isolation: 4,
    features: ['Fond vert', 'Multicam', 'Post-production'],
    bookable: true,
  ),
  StudioSpace(
    id: 'pedagogique',
    name: 'Studio Pédagogique',
    zone: 'Pédagogie numérique',
    tagline: 'Cours · MOOC · Téléprompteur',
    description:
        'Studio e-learning avec tableau lumineux (lightboard) et téléprompteur : l’enseignant écrit face caméra.',
    image: 'assets/images/studio_pedagogique.jpg',
    isolation: 4,
    features: ['Téléprompteur', 'Streaming', 'Cours / MOOC'],
    bookable: true,
  ),
  StudioSpace(
    id: 'speedmooc',
    name: 'Speed MOOC',
    zone: 'Pédagogie numérique',
    tagline: 'Cours rapides · Vidéo',
    description:
        'Cellule de production MOOC rapide : poste de réalisation tout-en-un pour enregistrer un cours complet en une session.',
    image: 'assets/images/speedmooc.jpg',
    isolation: 3,
    features: ['Cours rapides', 'Vidéo', 'Téléprompteur'],
    bookable: true,
  ),
  StudioSpace(
    id: 'regie_plateau',
    name: 'Régie Plateau',
    zone: 'Post-production',
    tagline: 'Espace support · hors réservation directe',
    description:
        'Régie centralisée du plateau : retour vidéo multi-caméras, console audio et contrôle du streaming live.',
    image: 'assets/images/regie_tv.jpg',
    isolation: 4,
    features: ['Régie technique', 'Multicam', 'Streaming'],
    bookable: false,
  ),
  StudioSpace(
    id: 'salon_vip',
    name: 'Salon VIP / Réception',
    zone: 'Accueil',
    tagline: 'Espace support · hors réservation directe',
    description:
        'Espace d’accueil des invités et de préparation avant l’entrée en studio.',
    image: 'assets/images/salon_vip.jpg',
    isolation: 1,
    features: ['Accueil', 'Préparation'],
    bookable: false,
  ),
];

StudioSpace spaceById(String id) => kSpaces.firstWhere((s) => s.id == id);

// ---------- Équipement ----------

enum EquipmentStatus { disponible, bloque }

extension EquipmentStatusLabel on EquipmentStatus {
  String get label =>
      this == EquipmentStatus.disponible ? 'Disponible' : 'Bloqué — maintenance';
}

class EquipmentItem {
  String id;
  String name;
  String category;
  int totalQty; // quantité à confirmer par UEMF (modifiable par l'admin)
  EquipmentStatus status;
  String description;
  EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.totalQty,
    required this.status,
    required this.description,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category, 'totalQty': totalQty,
        'status': status.index, 'description': description,
      };
  factory EquipmentItem.fromJson(Map<String, dynamic> j) => EquipmentItem(
        id: j['id'], name: j['name'], category: j['category'],
        totalQty: j['totalQty'], status: EquipmentStatus.values[j['status']],
        description: j['description'],
      );
}

class EquipmentRequest {
  String itemId;
  int qty;
  bool required; // requis (bloquant en validation technique) vs optionnel
  EquipmentRequest({required this.itemId, required this.qty, required this.required});
  Map<String, dynamic> toJson() =>
      {'itemId': itemId, 'qty': qty, 'required': required};
  factory EquipmentRequest.fromJson(Map<String, dynamic> j) =>
      EquipmentRequest(
          itemId: j['itemId'], qty: j['qty'], required: j['required']);
}

// ---------- Réservation ----------

class Booking {
  String id;
  String spaceId;
  String userName;
  AppRole userRole;
  String title; // nom du projet / de la session
  String purpose; // objet obligatoire (Figma : récapitulatif + demande)
  DateTime date;
  int startHour; // 8..17 (créneaux horaires, pause 13h–14h)
  int durationHours; // 1..4
  UsageType usage;
  List<EquipmentRequest> equipment;
  BookingStatus status;
  String? refusalReason;
  bool charterSigned;
  DateTime createdAt;

  Booking({
    required this.id,
    required this.spaceId,
    required this.userName,
    required this.userRole,
    required this.title,
    required this.purpose,
    required this.date,
    required this.startHour,
    required this.durationHours,
    required this.usage,
    required this.equipment,
    required this.status,
    this.refusalReason,
    required this.charterSigned,
    required this.createdAt,
  });

  int get endHour => startHour + durationHours;
  String get slotLabel =>
      '${startHour.toString().padLeft(2, '0')}:00 – ${endHour.toString().padLeft(2, '0')}:00';
  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day, startHour);
  DateTime get endDateTime =>
      DateTime(date.year, date.month, date.day, endHour);

  bool overlaps(DateTime d, int start, int end) =>
      date.year == d.year &&
      date.month == d.month &&
      date.day == d.day &&
      startHour < end &&
      start < endHour;

  String get qrPayload =>
      'EUROMED-STUDIOS|$id|$spaceId|${date.toIso8601String().substring(0, 10)}|$startHour-$endHour|$userName';

  Map<String, dynamic> toJson() => {
        'id': id, 'spaceId': spaceId, 'userName': userName,
        'userRole': userRole.index, 'title': title, 'purpose': purpose,
        'date': date.toIso8601String(), 'startHour': startHour,
        'durationHours': durationHours, 'usage': usage.index,
        'equipment': equipment.map((e) => e.toJson()).toList(),
        'status': status.index, 'refusalReason': refusalReason,
        'charterSigned': charterSigned, 'createdAt': createdAt.toIso8601String(),
      };
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'], spaceId: j['spaceId'], userName: j['userName'],
        userRole: AppRole.values[j['userRole']], title: j['title'],
        purpose: j['purpose'] ?? j['title'], date: DateTime.parse(j['date']),
        startHour: j['startHour'], durationHours: j['durationHours'],
        usage: UsageType.values[j['usage']],
        equipment: (j['equipment'] as List)
            .map((e) => EquipmentRequest.fromJson(e))
            .toList(),
        status: BookingStatus.values[j['status']],
        refusalReason: j['refusalReason'], charterSigned: j['charterSigned'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

// ---------- Projets ----------

enum ProjectType { enseignement, recherche, culture, communication }

extension ProjectTypeLabel on ProjectType {
  String get label => switch (this) {
        ProjectType.enseignement => 'Enseignement / MOOC',
        ProjectType.recherche => 'Recherche',
        ProjectType.culture => 'Culture',
        ProjectType.communication => 'Communication institutionnelle',
      };
}

enum ProjectStage { preproduction, production, postproduction, validation }

extension ProjectStageLabel on ProjectStage {
  String get label => switch (this) {
        ProjectStage.preproduction => 'Pré-production',
        ProjectStage.production => 'Production',
        ProjectStage.postproduction => 'Post-production',
        ProjectStage.validation => 'Validation & Archivage',
      };
  String get letter => switch (this) {
        ProjectStage.preproduction => 'A',
        ProjectStage.production => 'B',
        ProjectStage.postproduction => 'C',
        ProjectStage.validation => 'D',
      };
}

class Correction {
  String text;
  bool resolved;
  Correction({required this.text, this.resolved = false});
  Map<String, dynamic> toJson() => {'text': text, 'resolved': resolved};
  factory Correction.fromJson(Map<String, dynamic> j) =>
      Correction(text: j['text'], resolved: j['resolved'] ?? false);
}

class Invite {
  String name;
  String status; // en attente / acceptée / refusée
  Invite({required this.name, this.status = 'en attente'});
  Map<String, dynamic> toJson() => {'name': name, 'status': status};
  factory Invite.fromJson(Map<String, dynamic> j) =>
      Invite(name: j['name'], status: j['status']);
}

class Project {
  String id;
  String title;
  ProjectType type; // un seul type principal par projet (Figma + spec)
  ProjectStage stage;
  String editingStatus; // Non commencé / En cours / Correction demandée / Prêt pour CQ
  String ownerName;
  AppRole ownerRole;
  List<String> collaborators;
  List<Invite> invites;
  List<String> documents; // script, conducteur, storyboard…
  List<Correction> corrections;
  String? linkedBookingId; // production liée à une session Validée uniquement
  bool archived;
  String? deliveryLink;
  Project({
    required this.id,
    required this.title,
    required this.type,
    required this.stage,
    this.editingStatus = 'Non commencé',
    required this.ownerName,
    required this.ownerRole,
    required this.collaborators,
    required this.invites,
    required this.documents,
    required this.corrections,
    this.linkedBookingId,
    this.archived = false,
    this.deliveryLink,
  });
  String get stepLabel => '${stage.index + 1} / 4 étapes';
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'type': type.index, 'stage': stage.index,
        'editingStatus': editingStatus, 'ownerName': ownerName,
        'ownerRole': ownerRole.index, 'collaborators': collaborators,
        'invites': invites.map((e) => e.toJson()).toList(),
        'documents': documents,
        'corrections': corrections.map((e) => e.toJson()).toList(),
        'linkedBookingId': linkedBookingId, 'archived': archived,
        'deliveryLink': deliveryLink,
      };
  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'], title: j['title'], type: ProjectType.values[j['type']],
        stage: ProjectStage.values[j['stage']],
        editingStatus: j['editingStatus'] ?? 'Non commencé',
        ownerName: j['ownerName'], ownerRole: AppRole.values[j['ownerRole']],
        collaborators: List<String>.from(j['collaborators']),
        invites: (j['invites'] as List? ?? [])
            .map((e) => Invite.fromJson(e))
            .toList(),
        documents: List<String>.from(j['documents']),
        corrections: (j['corrections'] as List? ?? [])
            .map((e) => Correction.fromJson(e))
            .toList(),
        linkedBookingId: j['linkedBookingId'], archived: j['archived'] ?? false,
        deliveryLink: j['deliveryLink'],
      );
}

// ---------- Incidents / maintenance ----------

enum IncidentStatus { signale, enExamen, enCours, resolu, ferme }

extension IncidentStatusLabel on IncidentStatus {
  String get label => switch (this) {
        IncidentStatus.signale => 'Signalé',
        IncidentStatus.enExamen => 'En examen',
        IncidentStatus.enCours => 'En cours',
        IncidentStatus.resolu => 'Résolu',
        IncidentStatus.ferme => 'Fermé',
      };
}

enum Severity { basse, moyenne, haute }

extension SeverityLabel on Severity {
  String get label => switch (this) {
        Severity.basse => 'Basse',
        Severity.moyenne => 'Moyenne',
        Severity.haute => 'Haute',
      };
}

class Incident {
  String id;
  String spaceId;
  String? equipmentId;
  String title;
  String description;
  String reporterName;
  String? bookingId;
  Severity severity;
  IncidentStatus status;
  String? blockId; // bloc maintenance créé si gravité haute
  DateTime createdAt;
  Incident({
    required this.id, required this.spaceId, this.equipmentId,
    required this.title, required this.description, required this.reporterName,
    this.bookingId, required this.severity, required this.status,
    this.blockId, required this.createdAt,
  });
  bool get blocksResource =>
      severity == Severity.haute &&
      (status == IncidentStatus.signale ||
          status == IncidentStatus.enExamen ||
          status == IncidentStatus.enCours);
  Map<String, dynamic> toJson() => {
        'id': id, 'spaceId': spaceId, 'equipmentId': equipmentId,
        'title': title, 'description': description, 'reporterName': reporterName,
        'bookingId': bookingId, 'severity': severity.index,
        'status': status.index, 'blockId': blockId,
        'createdAt': createdAt.toIso8601String(),
      };
  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'], spaceId: j['spaceId'], equipmentId: j['equipmentId'],
        title: j['title'], description: j['description'],
        reporterName: j['reporterName'], bookingId: j['bookingId'],
        severity: Severity.values[j['severity']],
        status: IncidentStatus.values[j['status']], blockId: j['blockId'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class MaintenanceBlock {
  String id;
  String spaceId;
  DateTime date;
  int startHour;
  int durationHours;
  String reason;
  String createdBy;
  MaintenanceBlock({
    required this.id, required this.spaceId, required this.date,
    required this.startHour, required this.durationHours, required this.reason,
    required this.createdBy,
  });
  int get endHour => startHour + durationHours;
  bool overlaps(DateTime d, int start, int end) =>
      date.year == d.year && date.month == d.month && date.day == d.day &&
      startHour < end && start < endHour;
  Map<String, dynamic> toJson() => {
        'id': id, 'spaceId': spaceId, 'date': date.toIso8601String(),
        'startHour': startHour, 'durationHours': durationHours,
        'reason': reason, 'createdBy': createdBy,
      };
  factory MaintenanceBlock.fromJson(Map<String, dynamic> j) =>
      MaintenanceBlock(
        id: j['id'], spaceId: j['spaceId'], date: DateTime.parse(j['date']),
        startHour: j['startHour'], durationHours: j['durationHours'],
        reason: j['reason'], createdBy: j['createdBy'],
      );
}

// ---------- Notifications / occupation / journal / config ----------

class AppNotification {
  String id;
  String title;
  String body;
  String kind; // réservation / projet / incident / système
  String? bookingId;
  String? projectId;
  bool read;
  bool mandatory; // les résultats de réservation ne peuvent pas être désactivés
  DateTime createdAt;
  AppNotification({
    required this.id, required this.title, required this.body,
    required this.kind, this.bookingId, this.projectId, this.read = false,
    this.mandatory = false, required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'body': body, 'kind': kind,
        'bookingId': bookingId, 'projectId': projectId, 'read': read,
        'mandatory': mandatory, 'createdAt': createdAt.toIso8601String(),
      };
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'], title: j['title'], body: j['body'], kind: j['kind'],
        bookingId: j['bookingId'], projectId: j['projectId'],
        read: j['read'] ?? false, mandatory: j['mandatory'] ?? false,
        createdAt: DateTime.parse(j['createdAt']),
      );
}

enum OccupancyState { libre, occupe, inconnu }

extension OccupancyLabel on OccupancyState {
  String get label => switch (this) {
        OccupancyState.libre => 'Libre',
        OccupancyState.occupe => 'Occupé',
        OccupancyState.inconnu => 'Inconnu',
      };
}

class Occupancy {
  String spaceId;
  OccupancyState state;
  DateTime updatedAt;
  Occupancy(
      {required this.spaceId, required this.state, required this.updatedAt});
  Map<String, dynamic> toJson() => {
        'spaceId': spaceId, 'state': state.index,
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory Occupancy.fromJson(Map<String, dynamic> j) => Occupancy(
        spaceId: j['spaceId'], state: OccupancyState.values[j['state']],
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}

class AuditEntry {
  String id;
  String action;
  String detail;
  String actor;
  DateTime createdAt;
  AuditEntry({
    required this.id, required this.action, required this.detail,
    required this.actor, required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id, 'action': action, 'detail': detail, 'actor': actor,
        'createdAt': createdAt.toIso8601String(),
      };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'], action: j['action'], detail: j['detail'],
        actor: j['actor'], createdAt: DateTime.parse(j['createdAt']),
      );
}

/// Configuration institutionnelle — modifiable par l'administrateur.
/// Aucune de ces valeurs n'est présentée comme une règle UEMF définitive :
/// chaque écran concerné rappelle « à confirmer par UEMF ».
class AppConfig {
  Map<AppRole, int?> quotas; // null = illimité
  int freshnessMinutes; // seuil de fraîcheur de l'occupation (configurable)
  bool projectNotificationsEnabled; // les résultats de réservation restent obligatoires
  AppConfig({
    required this.quotas,
    required this.freshnessMinutes,
    required this.projectNotificationsEnabled,
  });
  factory AppConfig.defaults() => AppConfig(
        quotas: {for (final e in kRoles.entries) e.key: e.value.quotaHoursPerWeek},
        freshnessMinutes: 30,
        projectNotificationsEnabled: true,
      );
  Map<String, dynamic> toJson() => {
        'quotas': quotas.map((k, v) => MapEntry(k.index.toString(), v)),
        'freshnessMinutes': freshnessMinutes,
        'projectNotificationsEnabled': projectNotificationsEnabled,
      };
  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final quotas = <AppRole, int?>{};
    final raw = (j['quotas'] as Map<String, dynamic>? ?? {});
    for (final r in AppRole.values) {
      quotas[r] = raw.containsKey(r.index.toString())
          ? raw[r.index.toString()] as int?
          : kRoles[r]!.quotaHoursPerWeek;
    }
    return AppConfig(
      quotas: quotas,
      freshnessMinutes: j['freshnessMinutes'] ?? 30,
      projectNotificationsEnabled: j['projectNotificationsEnabled'] ?? true,
    );
  }
}

class CurrentUser {
  final String name;
  final AppRole role;
  const CurrentUser(this.name, this.role);
  bool get isGuest => role == AppRole.invite;
  bool get canBook =>
      role != AppRole.invite &&
      role != AppRole.approbateurEntite &&
      role != AppRole.approbateurStudio &&
      role != AppRole.admin;
  bool get canApproveL1 =>
      role == AppRole.approbateurEntite || role == AppRole.admin;
  bool get canApproveL2 =>
      role == AppRole.approbateurStudio || role == AppRole.admin;
  bool get canRegie => role == AppRole.technique || role == AppRole.admin;
  bool get isAdmin => role == AppRole.admin;
}
