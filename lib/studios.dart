// Studios & réservations — écrans Figma page 03.
// Parcours de réservation en 5 étapes (Figma) :
// 1 Activité (un seul usage par demande) · 2 Date & créneaux ·
// 3 Matériel (quantité, requis/optionnel) · 4 Charte (obligatoire) ·
// 5 Récapitulatif → Demande envoyée (En attente entité, créneau pré-verrouillé).
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'signature_pad.dart';
import 'ops.dart';

class StudiosTab extends StatefulWidget {
  const StudiosTab({super.key});
  @override
  State<StudiosTab> createState() => _StudiosTabState();
}

class _StudiosTabState extends State<StudiosTab> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final spaces = kSpaces.where((s) {
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.zone.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    final next = appStore.nextSession;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Les studios',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const Text('Espaces réels · réservabilité à confirmer.',
                  style: TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher un studio…'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final s in spaces)
                StudioCard(s, onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StudioDetailScreen(space: s)));
                }),
              if (spaces.isEmpty)
                const EmptyState(
                    title: 'Aucun studio trouvé',
                    subtitle: 'Essayez un autre mot-clé.'),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (next != null)
          SafeArea(
            top: false,
            child: NextSessionPill(next, onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookingDetailScreen(booking: next)));
            }),
          ),
      ],
    );
  }
}

class StudioDetailScreen extends StatelessWidget {
  final StudioSpace space;
  const StudioDetailScreen({super.key, required this.space});
  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return Scaffold(
      appBar: AppBar(title: Text(space.name)),
      body: ListView(
        children: [
          if (space.image != null)
            Image.asset(space.image!,
                height: 220, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 220, color: AppColors.studioBg,
                    child: const Icon(Icons.videocam, size: 56))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(space.tagline,
                    style: const TextStyle(
                        color: AppColors.secondary, fontSize: 14)),
                const SizedBox(height: 8),
                Text(space.description, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Isolation ',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    starsRow(space.isolation),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Matériel principal',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in space.features)
                      Chip(label: Text(f), avatar: const Icon(Icons.check, size: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Créneaux du jour (exemple)',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in [9, 10, 11])
                      Chip(
                        label: Text(
                            '${h.toString().padLeft(2, '0')}:00 — ${appStore.slotState(space.id, day, h)}'),
                        backgroundColor:
                            appStore.slotState(space.id, day, h) == 'Libre'
                                ? AppColors.validatedBg
                                : AppColors.entityBg,
                      ),
                  ],
                ),
                const ConfirmNote(
                    'Réservabilité, inventaire et conditions à confirmer par UEMF. Parcours de réservation illustratif.'),
                const SizedBox(height: 8),
                if (space.bookable)
                  FilledButton(
                    onPressed: () {
                      if (user == null || user.isGuest) {
                        showOk(context,
                            'La réservation exige un compte : connectez-vous depuis votre profil.');
                        return;
                      }
                      if (!user.canBook) {
                        showError(context,
                            'Ce profil ne soumet pas de réservation (valideur / administrateur).');
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  BookingWizardScreen(space: space)));
                    },
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Réserver ce studio'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18)
                        ]),
                  )
                else
                  const Text(
                      'Espace support : il n’est pas réservable directement. Il est mobilisé via la validation technique d’une production.',
                      style: TextStyle(color: AppColors.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Assistant de réservation (5 étapes) ----------

class BookingWizardScreen extends StatefulWidget {
  final StudioSpace space;
  final Booking? existing; // non utilisé pour l'instant (modification via détail)
  const BookingWizardScreen({super.key, required this.space, this.existing});
  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  int _step = 0;
  UsageType _usage = UsageType.enregistrement;
  final _title = TextEditingController();
  final _purpose = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _startHour = 10;
  int _duration = 1;
  final Map<String, int> _qty = {};
  final Map<String, bool> _required = {};
  bool _charterAccepted = false;
  bool _signed = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime(_date.year, _date.month, _date.day);
    for (final e in appStore.equipment) {
      _qty[e.id] = 0;
      _required[e.id] = false;
    }
    // Valeurs par défaut de Figma (écran Matériel) : caméra ×1 requis,
    // microphone ×1 optionnel, lumière ×2 optionnel.
    if (_qty.containsKey('kit_camera')) {
      _qty['kit_camera'] = 1;
      _required['kit_camera'] = true;
    }
    if (_qty.containsKey('kit_micro')) _qty['kit_micro'] = 1;
    if (_qty.containsKey('kit_lumiere')) _qty['kit_lumiere'] = 2;
  }

  List<EquipmentRequest> get _requests => [
        for (final e in appStore.equipment)
          if ((_qty[e.id] ?? 0) > 0)
            EquipmentRequest(
                itemId: e.id,
                qty: _qty[e.id]!,
                required: _required[e.id] ?? false),
      ];

  bool get _intervalOk {
    if (_startHour < 13 && _startHour + _duration > 13) return false;
    if (_startHour + _duration > 18) return false;
    return true;
  }

  void _submit() {
    final user = appStore.user!;
    try {
      final draft = Booking(
        id: appStore.newId('B'),
        spaceId: widget.space.id,
        userName: user.name,
        userRole: user.role,
        title: _title.text.trim(),
        purpose: _purpose.text.trim(),
        date: _date,
        startHour: _startHour,
        durationHours: _duration,
        usage: _usage,
        equipment: _requests,
        status: BookingStatus.attenteEntite,
        charterSigned: _charterAccepted,
        createdAt: DateTime.now(),
      );
      final created = appStore.submitBooking(draft);
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => BookingSentScreen(booking: created)));
    } on BookingException catch (e) {
      showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = appStore.user!;
    return Scaffold(
      appBar: AppBar(
          title: Text('Réserver — ${widget.space.name}'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_step > 0) {
                  setState(() => _step--);
                } else {
                  Navigator.pop(context);
                }
              })),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text('RÉSERVATION · ÉTAPE ${_step + 1} / 5',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 12,
                        letterSpacing: 1)),
                const Spacer(),
                Text('${widget.space.name}',
                    style: const TextStyle(color: AppColors.secondary)),
              ],
            ),
          ),
          LinearProgressIndicator(value: (_step + 1) / 5),
          Expanded(child: _buildStep(user)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Retour')),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canContinue() ? () {
                        if (_step < 4) {
                          setState(() => _step++);
                        } else {
                          _submit();
                        }
                      } : null,
                      child: Text(_step == 4 ? 'Envoyer la demande' : 'Continuer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canContinue() {
    switch (_step) {
      case 0:
        return _title.text.trim().isNotEmpty &&
            _purpose.text.trim().isNotEmpty;
      case 1:
        return _intervalOk;
      case 2:
        return true;
      case 3:
        return _charterAccepted;
      default:
        return true;
    }
  }

  Widget _buildStep(CurrentUser user) {
    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Que voulez-vous\nfaire ?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                '${widget.space.name} · Un seul usage par demande\nContexte : ${user.name} · ${kRoles[user.role]!.label}',
                style: const TextStyle(color: AppColors.secondary)),
            if (user.role == AppRole.club)
              const ConfirmNote(
                  'Réserver pour un club : un club est un groupe, pas un compte partagé. Un représentant identifié agit pour lui. Le routage et la désignation du représentant restent à confirmer par UEMF.'),
            if (user.role == AppRole.externe)
              const ConfirmNote(
                  'Demande de devis — Externe : profil commercial. Tarification, périmètre du devis et facturation : à confirmer par UEMF. Facturation / paiement : hors V1. Validation Niveau 1 : Vice-Présidence Exécutive.'),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Nom de la session / du projet *',
                  hintText: 'Ex. : Voix du campus'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purpose,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Objet de la demande *',
                  hintText: 'Décrivez brièvement l’activité prévue…'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            for (final u in UsageType.values)
              Card(
                child: RadioListTile<UsageType>(
                  value: u,
                  groupValue: _usage,
                  onChanged: (v) => setState(() => _usage = v!),
                  title: Text(u.label),
                ),
              ),
          ],
        );
      case 1:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Choisissez une date\net un créneau',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(fmtDay(_date)),
              subtitle: const Text('Touchez pour changer de date'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() => _date =
                      DateTime(picked.year, picked.month, picked.day));
                }
              },
            ),
            const Text('Heure de début',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in kSlotHours)
                  ChoiceChip(
                    label: Text(
                        '${h.toString().padLeft(2, '0')}:00 — ${appStore.slotState(widget.space.id, _date, h)}'),
                    selected: _startHour == h,
                    onSelected: (_) => setState(() => _startHour = h),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Durée (heures)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Row(
              children: [
                IconButton(
                    onPressed: _duration > 1
                        ? () => setState(() => _duration--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('$_duration h',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(
                    onPressed: _duration < 4
                        ? () => setState(() => _duration++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline)),
                const SizedBox(width: 8),
                Text('Fin : ${(_startHour + _duration).toString().padLeft(2, '0')}:00'),
              ],
            ),
            if (!_intervalOk)
              const ConfirmNote(
                  'Créneau invalide : la pause de 13:00 à 14:00 ne peut pas être traversée et la fin doit rester avant 18:00.'),
            const ConfirmNote(
                'Disponibilité vérifiée pour la date et l’intervalle sélectionnés. Un créneau « Pré-verrouillé » est déjà pris par une demande en cours.'),
            const Text('Horaires illustratifs · à confirmer par UEMF.',
                style: TextStyle(color: AppColors.secondary)),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Matériel\nsupplémentaire',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('Optionnel. Quantité et caractère requis.',
                style: TextStyle(color: AppColors.secondary)),
            const SizedBox(height: 12),
            for (final e in appStore.equipment)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          Text(e.status.label,
                              style: TextStyle(
                                  color: e.status == EquipmentStatus.disponible
                                      ? AppColors.ok
                                      : AppColors.err,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Text('${e.category} · ${e.totalQty} au total',
                          style: const TextStyle(
                              color: AppColors.secondary, fontSize: 13)),
                      Row(
                        children: [
                          IconButton(
                              onPressed: (_qty[e.id] ?? 0) > 0
                                  ? () => setState(() => _qty[e.id] =
                                      (_qty[e.id] ?? 0) - 1)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline)),
                          Text('× ${_qty[e.id] ?? 0}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          IconButton(
                              onPressed: () => setState(() => _qty[e.id] =
                                  (_qty[e.id] ?? 0) + 1),
                              icon: const Icon(Icons.add_circle_outline)),
                          const Spacer(),
                          FilterChip(
                            label: Text((_required[e.id] ?? false)
                                ? 'Requis'
                                : 'Optionnel'),
                            selected: _required[e.id] ?? false,
                            onSelected: (v) =>
                                setState(() => _required[e.id] = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const ConfirmNote(
                'Un élément requis indisponible bloque la validation technique. Un optionnel indisponible doit être signalé, jamais retiré ou remplacé en silence.'),
          ],
        );
      case 3:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Charte de\nresponsabilité',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('RÉSERVATION · ÉTAPE 4 / 5 · OBLIGATOIRE',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'En acceptant, je m’engage à respecter le règlement des studios, à restituer le matériel en bon état, à signaler tout incident en fin de session et à n’utiliser le créneau que pour l’activité déclarée. Le QR d’accès est personnel et non partageable.'),
              ),
            ),
            CheckboxListTile(
              value: _charterAccepted,
              onChanged: (v) => setState(() => _charterAccepted = v ?? false),
              title: const Text(
                  'J’accepte la charte de responsabilité (obligatoire)'),
            ),
            const Text('Signature (optionnelle — l’acceptation suffit) :'),
            const SizedBox(height: 8),
            SignaturePad(onChanged: (v) => setState(() => _signed = v)),
            if (_signed)
              const Text('Signature enregistrée pour cette demande.',
                  style: TextStyle(color: AppColors.ok)),
          ],
        );
      default:
        final quota = appStore.quotaFor(user.role);
        final used =
            appStore.weeklyHoursUsed(user.name, user.role, _date);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Vérifiez votre demande',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _RecapRow('Studio', widget.space.name),
            _RecapRow('Usage', _usage.label),
            _RecapRow('Créneau',
                '${fmtDay(_date)} · ${_startHour.toString().padLeft(2, '0')}:00 – ${(_startHour + _duration).toString().padLeft(2, '0')}:00'),
            _RecapRow('Projet', _title.text),
            _RecapRow('Objet', _purpose.text),
            _RecapRow(
                'Matériel',
                _requests.isEmpty
                    ? 'Aucun matériel supplémentaire'
                    : _requests
                        .map((r) {
                          final item = appStore.equipment.firstWhere(
                              (e) => e.id == r.itemId);
                          return '${item.name} × ${r.qty} · ${r.required ? 'requis' : 'facultatif'}';
                        })
                        .join('\n')),
            _RecapRow('Charte', _charterAccepted ? 'Acceptée ✓' : 'Non acceptée'),
            _RecapRow('Quota semaine',
                quota == null
                    ? 'Illimité'
                    : '$used h utilisées / $quota h — cette demande : $_duration h'),
            const SizedBox(height: 12),
            const Text(
                'En attente entité → En attente studio → Validée',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Text(
                'Une fois envoyée, votre demande pré-verrouille le créneau : il ne peut pas être réservé deux fois.',
                style: TextStyle(color: AppColors.secondary)),
            Text('Pour : ${user.name} · ${kRoles[user.role]!.label}',
                style: const TextStyle(color: AppColors.secondary)),
          ],
        );
    }
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  const _RecapRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: AppColors.secondary))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class BookingSentScreen extends StatelessWidget {
  final Booking booking;
  const BookingSentScreen({super.key, required this.booking});
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
              const Icon(Icons.check_circle,
                  color: AppColors.ok, size: 56),
              const SizedBox(height: 16),
              const Text('Demande envoyée',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const StatusChip(BookingStatus.attenteEntite),
              const SizedBox(height: 12),
              const Text(
                  'Votre créneau est pré-verrouillé. Vous serez notifié à chaque changement de statut.',
                  style: TextStyle(color: AppColors.secondary)),
              const SizedBox(height: 16),
              BookingCard(booking),
              const Text(
                  'En cas de refus, le motif sera affiché et notifié.',
                  style: TextStyle(color: AppColors.secondary)),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.popUntil(context, (r) => r.isFirst);
                  goToTab(3);
                },
                child: const Text('Voir mes sessions'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Détail d'une session / réservation ----------

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  const BookingDetailScreen({super.key, required this.booking});
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking get b => appStore.bookings.firstWhere((x) => x.id == widget.booking.id,
      orElse: () => widget.booking);

  @override
  Widget build(BuildContext context) {
    final space = spaceById(b.spaceId);
    final user = appStore.user;
    final isOwner = user != null && user.name == b.userName;
    final canCancel = isOwner &&
        (b.status == BookingStatus.attenteEntite ||
            b.status == BookingStatus.attenteStudio ||
            b.status == BookingStatus.validee) &&
        b.startDateTime.isAfter(DateTime.now());
    final blockers =
        b.status == BookingStatus.attenteStudio ? appStore.level2Blockers(b) : const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(b.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(space.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              StatusChip(b.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('${fmtDay(b.date)} · ${b.slotLabel}',
              style: const TextStyle(fontSize: 16)),
          Text('${b.usage.label} · ${b.userName} (${kRoles[b.userRole]!.label})',
              style: const TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 12),
          _RecapRow('Objet', b.purpose),
          _RecapRow(
              'Matériel',
              b.equipment.isEmpty
                  ? 'Aucun'
                  : b.equipment
                      .map((r) {
                        final item = appStore.equipment.firstWhere(
                            (e) => e.id == r.itemId,
                            orElse: () => EquipmentItem(
                                id: r.itemId, name: r.itemId, category: '',
                                totalQty: 0,
                                status: EquipmentStatus.disponible,
                                description: ''));
                        return '${item.name} × ${r.qty} · ${r.required ? 'requis' : 'optionnel'}';
                      })
                      .join('\n')),
          _RecapRow('Charte', b.charterSigned ? 'Acceptée ✓' : 'Non acceptée'),
          _RecapRow('Autorité Niveau 1',
              kRoles[b.userRole]!.l1Authority),
          if (b.refusalReason != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.rejectedBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Motif du refus : ${b.refusalReason}',
                  style: const TextStyle(color: AppColors.rejectedFg)),
            ),
          const SizedBox(height: 16),
          const Text('Parcours de validation',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _StepRow('En attente entité',
              b.status.index >= BookingStatus.attenteStudio.index ||
                  b.status == BookingStatus.validee ||
                  b.status == BookingStatus.terminee),
          _StepRow('En attente studio',
              b.status == BookingStatus.validee ||
                  b.status == BookingStatus.terminee),
          _StepRow('Validée',
              b.status == BookingStatus.validee ||
                  b.status == BookingStatus.terminee),
          if (blockers.isNotEmpty)
            ConfirmNote(
                'Validation technique bloquée :\n• ${blockers.join('\n• ')}'),
          const SizedBox(height: 16),
          if (b.status == BookingStatus.validee)
            FilledButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => QrScreen(booking: b))),
              icon: const Icon(Icons.qr_code),
              label: const Text('Voir le QR d’accès'),
            ),
          if (canCancel) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final ok = await confirmDialog(
                    context, 'Modifier la session ?',
                    'Choisissez une nouvelle date et un nouvel horaire.');
                if (ok && context.mounted) {
                  _showModifyDialog(context);
                }
              },
              child: const Text('Modifier la session'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.err,
                  side: const BorderSide(color: AppColors.err)),
              onPressed: () async {
                final ok = await confirmDialog(context, 'Annuler la session ?',
                    'L’annulation libère le créneau et les ressources. Cette action est définitive.');
                if (ok) {
                  try {
                    appStore.cancelBooking(b.id);
                    if (context.mounted) {
                      showOk(context, 'Session annulée.');
                      setState(() {});
                    }
                  } on BookingException catch (e) {
                    if (context.mounted) showError(context, e.message);
                  }
                }
              },
              child: const Text('Annuler la session'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportIncidentScreen(booking: b))),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Signaler un incident'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final result = appStore.checkOutcome(b.id);
              showOk(context, result);
              setState(() {});
            },
            child: const Text('Vérifier le résultat (U1)'),
          ),
        ],
      ),
    );
  }

  void _showModifyDialog(BuildContext context) async {
    var date = b.date;
    var start = b.startHour;
    var duration = b.durationHours;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Modifier la session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(fmtDay(date)),
                leading: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setD(() => date =
                        DateTime(picked.year, picked.month, picked.day));
                  }
                },
              ),
              DropdownButton<int>(
                value: start,
                isExpanded: true,
                items: [
                  for (final h in kSlotHours)
                    DropdownMenuItem(
                        value: h,
                        child: Text('${h.toString().padLeft(2, '0')}:00'))
                ],
                onChanged: (v) => setD(() => start = v!),
              ),
              Row(
                children: [
                  const Text('Durée : '),
                  DropdownButton<int>(
                    value: duration,
                    items: [
                      for (var d = 1; d <= 4; d++)
                        DropdownMenuItem(value: d, child: Text('$d h'))
                    ],
                    onChanged: (v) => setD(() => duration = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        appStore.modifyBooking(b.id, date, start, duration);
        if (context.mounted) {
          showOk(context, 'Session modifiée.');
          setState(() {});
        }
      } on BookingException catch (e) {
        if (context.mounted) showError(context, e.message);
      }
    }
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  const _StepRow(this.label, this.done);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.ok : AppColors.secondary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
}

// ---------- QR d'accès ----------

class QrScreen extends StatefulWidget {
  final Booking booking;
  const QrScreen({super.key, required this.booking});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  String? _scanResult;
  @override
  Widget build(BuildContext context) {
    final b = appStore.bookings.firstWhere((x) => x.id == widget.booking.id,
        orElse: () => widget.booking);
    final now = DateTime.now();
    final active = b.status == BookingStatus.validee &&
        !now.isBefore(b.startDateTime) &&
        now.isBefore(b.endDateTime);
    final space = spaceById(b.spaceId);
    return Scaffold(
      appBar: AppBar(title: const Text('Session + QR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(b.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Row(
            children: [
              const StatusChip(BookingStatus.validee),
              const SizedBox(width: 8),
              Text('${space.name} · ${fmtDay(b.date)} · ${b.slotLabel}',
                  style: const TextStyle(color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Accès : pendant le créneau seulement',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  QrImageView(
                    data: b.qrPayload,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                  const SizedBox(height: 12),
                  Text(
                      active
                          ? 'QR actif — accès autorisé pendant ce créneau.'
                          : 'QR inactif hors créneau : avant le début ou après la fin, l’accès est refusé.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: active ? AppColors.ok : AppColors.err,
                          fontWeight: FontWeight.w700)),
                  const Text(
                      'Actif uniquement pendant [début, fin), heure du campus. Aucune période de grâce par défaut (à confirmer par UEMF). Plusieurs passages autorisés pendant le créneau, pour les participants autorisés uniquement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.secondary, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final user = appStore.user;
              if (user == null || user.name != b.userName) {
                setState(() => _scanResult =
                    'Accès refusé — vous n’êtes pas un participant autorisé de cette réservation.');
              } else if (active) {
                setState(() => _scanResult =
                    'Accès accordé — bienvenue en studio (${space.name}). Passage enregistré (réservation, résultat, heure).');
              } else if (b.status != BookingStatus.validee) {
                setState(() => _scanResult =
                    'Accès refusé — réservation non validée (statut : ${b.status.label}).');
              } else if (now.isBefore(b.startDateTime)) {
                setState(() => _scanResult =
                    'Accès refusé — créneau pas encore commencé.');
              } else {
                setState(() => _scanResult =
                    'Accès refusé — créneau terminé.');
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Simuler un scan'),
          ),
          if (_scanResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_scanResult!,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _scanResult!.startsWith('Accès accordé')
                            ? AppColors.ok
                            : AppColors.err)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportIncidentScreen(booking: b))),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Signaler un incident'),
          ),
        ],
      ),
    );
  }
}
