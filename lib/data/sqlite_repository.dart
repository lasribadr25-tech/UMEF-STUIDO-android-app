// Implémentation SQLite (gratuite, locale, hors ligne) de AppRepository.
//
// Base : un seul fichier, créé par sqflite dans le dossier de documents de
// l'application (voir dbPath ci-dessous ; inspectable via adb / Device
// File Explorer d'Android Studio, chemin rappelé dans le README).
// Aucun compte, aucun serveur, aucun coût : les données restent sur le
// téléphone et ne sont PAS partagées entre téléphones.
//
// Schéma v1 (tables + index) : voir _createSchema.
//   meta, current_user, bookings, booking_equipment, projects,
//   project_invites, project_corrections, incidents, equipment,
//   maintenance_blocks, notifications, occupancy, audit, config.
// Clés étrangères activées (PRAGMA foreign_keys = ON) avec suppression
// en cascade pour les lignes enfants d'une réservation / d'un projet.
// Chaque save() réécrit le snapshot dans UNE transaction : en cas
// d'échec, la base reste dans son état précédent (pas d'écriture partielle).
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models.dart';
import 'repository.dart';

class SqliteAppRepository implements AppRepository {
  /// Chemin explicite (tests) ou null = fichier par défaut de l'app.
  /// La valeur spéciale ':memory:' de sqflite donne une base en mémoire.
  final String? _explicitPath;
  Database? _db;

  SqliteAppRepository({String? path}) : _explicitPath = path;

  /// Nom du fichier sur l'appareil (rappelé dans le README).
  static const String dbFileName = 'uemf_studio.db';

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final String path;
    if (_explicitPath != null) {
      path = _explicitPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, dbFileName);
    }
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    return _db!;
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute(
        'CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE current_user(id INTEGER PRIMARY KEY CHECK (id = 1), name TEXT NOT NULL, role INTEGER NOT NULL)');
    await db.execute('''
      CREATE TABLE bookings(
        id TEXT PRIMARY KEY, space_id TEXT NOT NULL, user_name TEXT NOT NULL,
        user_role INTEGER NOT NULL, title TEXT NOT NULL, purpose TEXT NOT NULL,
        date TEXT NOT NULL, start_hour INTEGER NOT NULL,
        duration_hours INTEGER NOT NULL, usage INTEGER NOT NULL,
        status INTEGER NOT NULL, refusal_reason TEXT,
        charter_signed INTEGER NOT NULL, created_at TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE booking_equipment(
        booking_id TEXT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
        item_id TEXT NOT NULL, qty INTEGER NOT NULL, required INTEGER NOT NULL,
        PRIMARY KEY (booking_id, item_id))''');
    await db.execute('''
      CREATE TABLE projects(
        id TEXT PRIMARY KEY, title TEXT NOT NULL, type INTEGER NOT NULL,
        stage INTEGER NOT NULL, editing_status TEXT NOT NULL,
        owner_name TEXT NOT NULL, owner_role INTEGER NOT NULL,
        collaborators TEXT NOT NULL, documents TEXT NOT NULL,
        linked_booking_id TEXT, archived INTEGER NOT NULL,
        delivery_link TEXT)''');
    await db.execute('''
      CREATE TABLE project_invites(
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name TEXT NOT NULL, status TEXT NOT NULL,
        PRIMARY KEY (project_id, name))''');
    await db.execute('''
      CREATE TABLE project_corrections(
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        row_id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL, resolved INTEGER NOT NULL)''');
    await db.execute('''
      CREATE TABLE incidents(
        id TEXT PRIMARY KEY, space_id TEXT NOT NULL, equipment_id TEXT,
        title TEXT NOT NULL, description TEXT NOT NULL,
        reporter_name TEXT NOT NULL, booking_id TEXT, severity INTEGER NOT NULL,
        status INTEGER NOT NULL, block_id TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE equipment(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
        total_qty INTEGER NOT NULL, status INTEGER NOT NULL,
        description TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE maintenance_blocks(
        id TEXT PRIMARY KEY, space_id TEXT NOT NULL, date TEXT NOT NULL,
        start_hour INTEGER NOT NULL, duration_hours INTEGER NOT NULL,
        reason TEXT NOT NULL, created_by TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE notifications(
        id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL,
        kind TEXT NOT NULL, booking_id TEXT, project_id TEXT,
        read INTEGER NOT NULL, mandatory INTEGER NOT NULL,
        created_at TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE occupancy(
        space_id TEXT PRIMARY KEY, state INTEGER NOT NULL,
        updated_at TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE audit(
        id TEXT PRIMARY KEY, action TEXT NOT NULL, detail TEXT NOT NULL,
        actor TEXT NOT NULL, created_at TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE config(
        id INTEGER PRIMARY KEY CHECK (id = 1), quotas TEXT NOT NULL,
        freshness_minutes INTEGER NOT NULL,
        project_notifications INTEGER NOT NULL)''');
    // Index demandés par le cahier des charges de la migration.
    await db.execute(
        'CREATE INDEX idx_bookings_date_space_status ON bookings(date, space_id, status)');
    await db.execute(
        'CREATE INDEX idx_bookings_user_week ON bookings(user_name, user_role, date)');
    await db.execute(
        'CREATE INDEX idx_projects_stage ON projects(stage, archived)');
    await db.execute(
        'CREATE INDEX idx_notifications_created ON notifications(created_at)');
    await db.execute(
        'CREATE INDEX idx_incidents_space ON incidents(space_id, status)');
    await db.execute('CREATE INDEX idx_audit_created ON audit(created_at)');
  }

  @override
  Future<AppSnapshot?> load() async {
    final db = await _open();
    final meta = await db.query('meta',
        where: 'key = ?', whereArgs: ['initialized']);
    if (meta.isEmpty || meta.first['value'] != '1') return null;

    final userRows = await db.query('current_user');
    final bookingRows = await db.query('bookings');
    final equipmentReqRows = await db.query('booking_equipment');
    final reqByBooking = <String, List<EquipmentRequest>>{};
    for (final r in equipmentReqRows) {
      reqByBooking.putIfAbsent(r['booking_id'] as String, () => []).add(
          EquipmentRequest(
              itemId: r['item_id'] as String,
              qty: r['qty'] as int,
              required: (r['required'] as int) == 1));
    }
    final bookings = bookingRows
        .map((r) => Booking(
              id: r['id'] as String,
              spaceId: r['space_id'] as String,
              userName: r['user_name'] as String,
              userRole: AppRole.values[r['user_role'] as int],
              title: r['title'] as String,
              purpose: r['purpose'] as String,
              date: DateTime.parse(r['date'] as String),
              startHour: r['start_hour'] as int,
              durationHours: r['duration_hours'] as int,
              usage: UsageType.values[r['usage'] as int],
              equipment: reqByBooking[r['id'] as String] ?? [],
              status: BookingStatus.values[r['status'] as int],
              refusalReason: r['refusal_reason'] as String?,
              charterSigned: (r['charter_signed'] as int) == 1,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();

    final projectRows = await db.query('projects');
    final inviteRows = await db.query('project_invites');
    final correctionRows =
        await db.query('project_corrections', orderBy: 'row_id ASC');
    final projects = projectRows.map((r) {
      final id = r['id'] as String;
      return Project(
        id: id,
        title: r['title'] as String,
        type: ProjectType.values[r['type'] as int],
        stage: ProjectStage.values[r['stage'] as int],
        editingStatus: r['editing_status'] as String,
        ownerName: r['owner_name'] as String,
        ownerRole: AppRole.values[r['owner_role'] as int],
        collaborators:
            List<String>.from(jsonDecode(r['collaborators'] as String) as List),
        invites: inviteRows
            .where((i) => i['project_id'] == id)
            .map((i) => Invite(
                name: i['name'] as String, status: i['status'] as String))
            .toList(),
        documents:
            List<String>.from(jsonDecode(r['documents'] as String) as List),
        corrections: correctionRows
            .where((c) => c['project_id'] == id)
            .map((c) => Correction(
                text: c['text'] as String,
                resolved: (c['resolved'] as int) == 1))
            .toList(),
        linkedBookingId: r['linked_booking_id'] as String?,
        archived: (r['archived'] as int) == 1,
        deliveryLink: r['delivery_link'] as String?,
      );
    }).toList();

    AppConfig config = AppConfig.defaults();
    final configRows = await db.query('config');
    if (configRows.isNotEmpty) {
      config = AppConfig.fromJson({
        'quotas': jsonDecode(configRows.first['quotas'] as String),
        'freshnessMinutes': configRows.first['freshness_minutes'],
        'projectNotificationsEnabled':
            (configRows.first['project_notifications'] as int) == 1,
      });
    }

    return AppSnapshot(
      user: userRows.isEmpty
          ? null
          : CurrentUser(userRows.first['name'] as String,
              AppRole.values[userRows.first['role'] as int]),
      bookings: bookings,
      projects: projects,
      incidents: (await db.query('incidents'))
          .map((r) => Incident(
                id: r['id'] as String,
                spaceId: r['space_id'] as String,
                equipmentId: r['equipment_id'] as String?,
                title: r['title'] as String,
                description: r['description'] as String,
                reporterName: r['reporter_name'] as String,
                bookingId: r['booking_id'] as String?,
                severity: Severity.values[r['severity'] as int],
                status: IncidentStatus.values[r['status'] as int],
                blockId: r['block_id'] as String?,
                createdAt: DateTime.parse(r['created_at'] as String),
              ))
          .toList(),
      equipment: (await db.query('equipment'))
          .map((r) => EquipmentItem(
                id: r['id'] as String,
                name: r['name'] as String,
                category: r['category'] as String,
                totalQty: r['total_qty'] as int,
                status: EquipmentStatus.values[r['status'] as int],
                description: r['description'] as String,
              ))
          .toList(),
      blocks: (await db.query('maintenance_blocks'))
          .map((r) => MaintenanceBlock(
                id: r['id'] as String,
                spaceId: r['space_id'] as String,
                date: DateTime.parse(r['date'] as String),
                startHour: r['start_hour'] as int,
                durationHours: r['duration_hours'] as int,
                reason: r['reason'] as String,
                createdBy: r['created_by'] as String,
              ))
          .toList(),
      notifications: (await db.query('notifications'))
          .map((r) => AppNotification(
                id: r['id'] as String,
                title: r['title'] as String,
                body: r['body'] as String,
                kind: r['kind'] as String,
                bookingId: r['booking_id'] as String?,
                projectId: r['project_id'] as String?,
                read: (r['read'] as int) == 1,
                mandatory: (r['mandatory'] as int) == 1,
                createdAt: DateTime.parse(r['created_at'] as String),
              ))
          .toList(),
      occupancy: (await db.query('occupancy'))
          .map((r) => Occupancy(
                spaceId: r['space_id'] as String,
                state: OccupancyState.values[r['state'] as int],
                updatedAt: DateTime.parse(r['updated_at'] as String),
              ))
          .toList(),
      audit: (await db.query('audit'))
          .map((r) => AuditEntry(
                id: r['id'] as String,
                action: r['action'] as String,
                detail: r['detail'] as String,
                actor: r['actor'] as String,
                createdAt: DateTime.parse(r['created_at'] as String),
              ))
          .toList(),
      config: config,
    );
  }

  @override
  Future<void> save(AppSnapshot s) async {
    final db = await _open();
    // UNE transaction : création, quota, approbation ou toute autre action
    // qui appelle save() n'est jamais écrite à moitié.
    await db.transaction((txn) async {
      for (final table in [
        'booking_equipment',
        'project_invites',
        'project_corrections',
        'bookings',
        'projects',
        'incidents',
        'equipment',
        'maintenance_blocks',
        'notifications',
        'occupancy',
        'audit',
        'current_user',
        'config',
        'meta',
      ]) {
        await txn.delete(table);
      }
      if (s.user != null) {
        await txn.insert('current_user',
            {'id': 1, 'name': s.user!.name, 'role': s.user!.role.index});
      }
      for (final b in s.bookings) {
        await txn.insert('bookings', {
          'id': b.id,
          'space_id': b.spaceId,
          'user_name': b.userName,
          'user_role': b.userRole.index,
          'title': b.title,
          'purpose': b.purpose,
          'date': b.date.toIso8601String(),
          'start_hour': b.startHour,
          'duration_hours': b.durationHours,
          'usage': b.usage.index,
          'status': b.status.index,
          'refusal_reason': b.refusalReason,
          'charter_signed': b.charterSigned ? 1 : 0,
          'created_at': b.createdAt.toIso8601String(),
        });
        for (final e in b.equipment) {
          await txn.insert('booking_equipment', {
            'booking_id': b.id,
            'item_id': e.itemId,
            'qty': e.qty,
            'required': e.required ? 1 : 0,
          });
        }
      }
      for (final pr in s.projects) {
        await txn.insert('projects', {
          'id': pr.id,
          'title': pr.title,
          'type': pr.type.index,
          'stage': pr.stage.index,
          'editing_status': pr.editingStatus,
          'owner_name': pr.ownerName,
          'owner_role': pr.ownerRole.index,
          'collaborators': jsonEncode(pr.collaborators),
          'documents': jsonEncode(pr.documents),
          'linked_booking_id': pr.linkedBookingId,
          'archived': pr.archived ? 1 : 0,
          'delivery_link': pr.deliveryLink,
        });
        for (final inv in pr.invites) {
          await txn.insert('project_invites', {
            'project_id': pr.id,
            'name': inv.name,
            'status': inv.status,
          });
        }
        for (final c in pr.corrections) {
          await txn.insert('project_corrections', {
            'project_id': pr.id,
            'text': c.text,
            'resolved': c.resolved ? 1 : 0,
          });
        }
      }
      for (final i in s.incidents) {
        await txn.insert('incidents', {
          'id': i.id,
          'space_id': i.spaceId,
          'equipment_id': i.equipmentId,
          'title': i.title,
          'description': i.description,
          'reporter_name': i.reporterName,
          'booking_id': i.bookingId,
          'severity': i.severity.index,
          'status': i.status.index,
          'block_id': i.blockId,
          'created_at': i.createdAt.toIso8601String(),
        });
      }
      for (final e in s.equipment) {
        await txn.insert('equipment', {
          'id': e.id,
          'name': e.name,
          'category': e.category,
          'total_qty': e.totalQty,
          'status': e.status.index,
          'description': e.description,
        });
      }
      for (final bl in s.blocks) {
        await txn.insert('maintenance_blocks', {
          'id': bl.id,
          'space_id': bl.spaceId,
          'date': bl.date.toIso8601String(),
          'start_hour': bl.startHour,
          'duration_hours': bl.durationHours,
          'reason': bl.reason,
          'created_by': bl.createdBy,
        });
      }
      for (final n in s.notifications) {
        await txn.insert('notifications', {
          'id': n.id,
          'title': n.title,
          'body': n.body,
          'kind': n.kind,
          'booking_id': n.bookingId,
          'project_id': n.projectId,
          'read': n.read ? 1 : 0,
          'mandatory': n.mandatory ? 1 : 0,
          'created_at': n.createdAt.toIso8601String(),
        });
      }
      for (final o in s.occupancy) {
        await txn.insert('occupancy', {
          'space_id': o.spaceId,
          'state': o.state.index,
          'updated_at': o.updatedAt.toIso8601String(),
        });
      }
      for (final a in s.audit) {
        await txn.insert('audit', {
          'id': a.id,
          'action': a.action,
          'detail': a.detail,
          'actor': a.actor,
          'created_at': a.createdAt.toIso8601String(),
        });
      }
      final quotasJson = s.config.toJson()['quotas'] as Map;
      await txn.insert('config', {
        'id': 1,
        'quotas': jsonEncode(
            quotasJson.map((k, v) => MapEntry(k.toString(), v))),
        'freshness_minutes': s.config.freshnessMinutes,
        'project_notifications':
            s.config.projectNotificationsEnabled ? 1 : 0,
      });
      await txn.insert('meta', {'key': 'initialized', 'value': '1'});
    });
  }

  @override
  Future<int> weeklyHoursUsedFromDb(
      String userName, AppRole role, DateTime weekStart) async {
    final db = await _open();
    // Statuts comptant pour le quota : En attente entité (0), En attente
    // studio (1), Validée (2), Terminée (6). Refusée / Annulée / Expirée : 0.
    final weekEnd = weekStart.add(const Duration(days: 7));
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(duration_hours), 0) AS total FROM bookings '
      'WHERE user_name = ? AND user_role = ? AND date >= ? AND date < ? '
      'AND status IN (0, 1, 2, 6)',
      [
        userName,
        role.index,
        weekStart.toIso8601String(),
        weekEnd.toIso8601String(),
      ],
    );
    return (rows.first['total'] as num).toInt();
  }
}
