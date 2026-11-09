// Test de fumée : vérifie que les règles métier de base tiennent
// (statuts, quotas, conflits) sans lancer l'interface, puis que la
// persistance SQLite (gratuite, locale) conserve réellement les données.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';
import 'package:uemf_studio_figma/data/sqlite_repository.dart';
import 'package:uemf_studio_figma/models.dart';
import 'package:uemf_studio_figma/store.dart';

void main() {
  // SQLite desktop pour flutter test ; l'app Android utilise sqflite.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  DateTime weekStartOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  test('SQLite : une réservation survit à un rechargement depuis la base',
      () async {
    final repo = SqliteAppRepository(path: inMemoryDatabasePath);
    final store = AppStore(repository: repo);
    await store.init();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final draft = Booking(
      id: 'T-SQL-1',
      spaceId: 'chroma',
      userName: 'Testeur',
      userRole: AppRole.etudiant,
      title: 'Test SQLite',
      purpose: 'Vérifier le round-trip.',
      date: tomorrow,
      startHour: 9,
      durationHours: 1,
      usage: UsageType.enregistrement,
      equipment: [],
      status: BookingStatus.attenteEntite,
      charterSigned: true,
      createdAt: now,
    );
    store.submitBooking(draft);
    await store.saveNow();
    final reloaded = AppStore(repository: repo);
    await reloaded.init();
    final found =
        reloaded.bookings.where((b) => b.id == 'T-SQL-1').toList();
    expect(found.length, 1);
    expect(found.first.title, 'Test SQLite');
    expect(found.first.status, BookingStatus.attenteEntite);
  });

  test('SQLite : une approbation Niveau 1 persiste après rechargement',
      () async {
    final repo = SqliteAppRepository(path: inMemoryDatabasePath);
    final store = AppStore(repository: repo);
    await store.init();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    store.submitBooking(Booking(
      id: 'T-SQL-2',
      spaceId: 'chroma',
      userName: 'Testeur',
      userRole: AppRole.etudiant,
      title: 'Test approbation',
      purpose: 'Vérifier la transition persistée.',
      date: tomorrow,
      startHour: 11,
      durationHours: 1,
      usage: UsageType.captation,
      equipment: [],
      status: BookingStatus.attenteEntite,
      charterSigned: true,
      createdAt: now,
    ));
    store.login('Responsable Vie Étudiante', AppRole.approbateurEntite);
    store.approveLevel1('T-SQL-2');
    await store.saveNow();
    final reloaded = AppStore(repository: repo);
    await reloaded.init();
    final found =
        reloaded.bookings.where((b) => b.id == 'T-SQL-2').toList();
    expect(found.length, 1);
    expect(found.first.status, BookingStatus.attenteStudio);
  });

  test('SQLite : le quota hebdomadaire est compté depuis la base',
      () async {
    final repo = SqliteAppRepository(path: inMemoryDatabasePath);
    final store = AppStore(repository: repo);
    await store.init();
    // Démo : B-1001 (Mouhssine, Validée, demain, 1 h) compte ; les
    // demandes Refusée / Annulée de Mouhssine ne comptent pas.
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final used = await repo.weeklyHoursUsedFromDb(
        'Mouhssine', AppRole.etudiant, weekStartOf(tomorrow));
    expect(used, 1);
    expect(store.weeklyHoursUsed('Mouhssine', AppRole.etudiant, tomorrow),
        used);
  });

  test('les statuts bloquants et terminaux sont cohérents', () {
    expect(BookingStatus.attenteEntite.isBlocking, isTrue);
    expect(BookingStatus.validee.isBlocking, isTrue);
    expect(BookingStatus.refusee.isBlocking, isFalse);
    expect(BookingStatus.terminee.countsTowardQuota, isTrue);
    expect(BookingStatus.annulee.countsTowardQuota, isFalse);
  });
  test('le catalogue Figma compte 6 espaces réservables + 2 supports', () {
    expect(kSpaces.where((s) => s.bookable).length, 6);
    expect(kSpaces.where((s) => !s.bookable).length, 2);
  });
  test('un créneau fin à 10h ne bloque pas un créneau début à 10h', () {
    final b = Booking(
      id: 'T-1', spaceId: 'podcast', userName: 'Test',
      userRole: AppRole.etudiant, title: 'T', purpose: 'T',
      date: DateTime(2027, 1, 5), startHour: 9, durationHours: 1,
      usage: UsageType.enregistrement, equipment: [],
      status: BookingStatus.validee, charterSigned: true,
      createdAt: DateTime(2027, 1, 1),
    );
    expect(b.overlaps(DateTime(2027, 1, 5), 10, 11), isFalse);
    expect(b.overlaps(DateTime(2027, 1, 5), 9, 10), isTrue);
  });
}
