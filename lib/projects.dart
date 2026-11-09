// Projets — écrans Figma page 04.
// Pipeline (spec Issue #7) : A Pré-production (brief + au moins un document
// script / conducteur / storyboard) → B Production (liée à une session
// Validée uniquement) → C Post-production (statut de montage, corrections)
// → D Validation & Archivage (contrôle qualité, livraison, archivage).
// Un seul type principal par projet. Collaborations par invitation identifiée
// (accepter / refuser, révocation par le propriétaire).
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';
import 'studios.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});
  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  bool _archivedOnly = false;
  @override
  Widget build(BuildContext context) {
    final user = appStore.user;
    var list = appStore.projects
        .where((p) => p.archived == _archivedOnly)
        .toList();
    final next = appStore.nextSession;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('Mes projets',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              FilterChip(
                  label: const Text('Archivés'),
                  selected: _archivedOnly,
                  onSelected: (v) => setState(() => _archivedOnly = v)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                'Types (un seul par projet) : Enseignement / MOOC · Recherche · Culture · Communication institutionnelle.',
                style: TextStyle(color: AppColors.secondary, fontSize: 13)),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyState(
                  title: _archivedOnly
                      ? 'Aucun projet archivé'
                      : 'Aucun projet',
                  subtitle: _archivedOnly
                      ? 'Un projet archivé apparaît ici après un contrôle qualité réussi.'
                      : 'Créez un projet avec le bouton + pour suivre son pipeline.')
              : ListView(
                  children: [
                    for (final p in list)
                      ProjectCard(p, onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProjectDetailScreen(project: p)));
                      }),
                  ],
                ),
        ),
        if (user != null && !user.isGuest)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NewProjectScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau projet'),
              ),
            ),
          )
        else if (next != null)
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

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});
  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _title = TextEditingController();
  ProjectType _type = ProjectType.culture;
  final _doc = TextEditingController();
  final List<String> _docs = [];
  final _collab = TextEditingController();
  final List<String> _invites = [];

  @override
  Widget build(BuildContext context) {
    final user = appStore.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau projet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Nouveau\nprojet',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const Text('Un seul type principal par projet.',
              style: TextStyle(color: AppColors.secondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
                labelText: 'Nom du projet *',
                hintText: 'Ex. : Voix du campus'),
          ),
          const SizedBox(height: 16),
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final t in ProjectType.values)
            RadioListTile<ProjectType>(
              value: t,
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v!),
              title: Text(t.label),
            ),
          const SizedBox(height: 8),
          const Text('Script / conducteur / storyboard',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const Text(
              'Au moins un fichier, avant la production. Le brief se dépose ensuite dans Documents de pré-production.',
              style: TextStyle(color: AppColors.secondary)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _doc,
                  decoration: const InputDecoration(
                      hintText: 'Ex. : Script_ep01.pdf'),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_doc.text.trim().isNotEmpty) {
                    setState(() {
                      _docs.add(_doc.text.trim());
                      _doc.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          for (final d in _docs) Chip(label: Text(d)),
          const SizedBox(height: 12),
          const Text('Collaborateurs',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('Inviter par identité · accepter / refuser.',
              style: TextStyle(color: AppColors.secondary)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collab,
                  decoration: const InputDecoration(
                      hintText: 'Nom de la personne à inviter'),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_collab.text.trim().isNotEmpty) {
                    setState(() {
                      _invites.add(_collab.text.trim());
                      _collab.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          for (final i in _invites) Chip(label: Text(i)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _title.text.trim().isEmpty
                ? null
                : () {
                    try {
                      appStore.addProject(Project(
                        id: appStore.newId('P'),
                        title: _title.text.trim(),
                        type: _type,
                        stage: ProjectStage.preproduction,
                        ownerName: user.name,
                        ownerRole: user.role,
                        collaborators: [],
                        invites: _invites
                            .map((n) => Invite(name: n))
                            .toList(),
                        documents: _docs,
                        corrections: [],
                      ));
                      Navigator.pop(context);
                      showOk(context, 'Projet créé (Pré-production).');
                    } on BookingException catch (e) {
                      showError(context, e.message);
                    }
                  },
            child: const Text('Créer le projet'),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});
  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Project get p => appStore.projects.firstWhere((x) => x.id == widget.project.id,
      orElse: () => widget.project);
  final _doc = TextEditingController();
  final _correction = TextEditingController();
  final _invite = TextEditingController();
  final _delivery = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final linked = p.linkedBookingId == null
        ? null
        : appStore.bookings
            .where((b) => b.id == p.linkedBookingId)
            .toList();
    final linkedBooking = linked == null || linked.isEmpty ? null : linked.first;
    final validated = appStore.myValidatedBookings;
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.type.label,
                    style: const TextStyle(color: AppColors.secondary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.studioBg,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(p.stepLabel,
                    style: const TextStyle(
                        color: AppColors.studioFg,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (p.archived)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Archivé — livraison disponible ci-dessous.',
                  style: TextStyle(
                      color: AppColors.ok, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 16),
          const Text('Pipeline de production',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final stage in ProjectStage.values)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.stage.index >= stage.index
                      ? AppColors.primary
                      : AppColors.neutralBg,
                  child: Text(stage.letter,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                title: Text(stage.label),
                subtitle: Text(_stageHint(stage, linkedBooking)),
                trailing: p.stage == stage
                    ? const Icon(Icons.play_arrow, color: AppColors.primary)
                    : p.stage.index > stage.index
                        ? const Icon(Icons.check, color: AppColors.ok)
                        : null,
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: p.archived
                ? null
                : () {
                    try {
                      appStore.advanceProject(p.id);
                      if (mounted) {
                        showOk(context,
                            'Projet avancé → ${p.stage.label}.');
                        setState(() {});
                      }
                    } on BookingException catch (e) {
                      showError(context, e.message);
                    }
                  },
            child: Text(p.stage == ProjectStage.validation
                ? 'Projet en validation'
                : 'Avancer à l’étape suivante'),
          ),
          const SizedBox(height: 16),
          const Text('Documents de pré-production',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final d in p.documents)
            Card(child: ListTile(title: Text(d), leading: const Icon(Icons.description_outlined))),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _doc,
                  decoration: const InputDecoration(
                      hintText: 'Nom du document à déposer'),
                ),
              ),
              IconButton(
                onPressed: () {
                  appStore.addDocument(p.id, _doc.text);
                  _doc.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Session liée (production)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (linkedBooking != null)
            BookingCard(linkedBooking, onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          BookingDetailScreen(booking: linkedBooking)));
            })
          else
            const Text(
                'Aucune session liée. La production exige une session Validée.',
                style: TextStyle(color: AppColors.secondary)),
          DropdownButton<String?>(
            value: p.linkedBookingId,
            isExpanded: true,
            hint: const Text('Lier une session Validée…'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Aucune')),
              for (final b in validated)
                DropdownMenuItem(
                    value: b.id,
                    child: Text(
                        '${b.title} · ${fmtDay(b.date)} · ${b.slotLabel}')),
            ],
            onChanged: (v) {
              appStore.linkBooking(p.id, v);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          const Text('Post-production & corrections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Row(
            children: [
              const Text('Montage : '),
              DropdownButton<String>(
                value: p.editingStatus,
                items: const [
                  DropdownMenuItem(
                      value: 'Non commencé', child: Text('Non commencé')),
                  DropdownMenuItem(
                      value: 'En cours', child: Text('En cours')),
                  DropdownMenuItem(
                      value: 'Correction demandée',
                      child: Text('Correction demandée')),
                  DropdownMenuItem(
                      value: 'Prêt pour CQ', child: Text('Prêt pour CQ')),
                ],
                onChanged: (v) {
                  appStore.setEditingStatus(p.id, v!);
                  setState(() {});
                },
              ),
            ],
          ),
          for (var i = 0; i < p.corrections.length; i++)
            Card(
              child: ListTile(
                title: Text(p.corrections[i].text),
                trailing: p.corrections[i].resolved
                    ? const Icon(Icons.check, color: AppColors.ok)
                    : TextButton(
                        onPressed: () {
                          appStore.resolveCorrection(p.id, i);
                          setState(() {});
                        },
                        child: const Text('Résoudre'),
                      ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _correction,
                  decoration: const InputDecoration(
                      hintText: 'Demander une correction…'),
                ),
              ),
              IconButton(
                onPressed: () {
                  try {
                    appStore.requestCorrection(p.id, _correction.text);
                    _correction.clear();
                    setState(() {});
                  } on BookingException catch (e) {
                    showError(context, e.message);
                  }
                },
                icon: const Icon(Icons.send, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Collaborateurs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final c in p.collaborators)
            Card(
              child: ListTile(
                title: Text(c),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () {
                    appStore.removeCollaborator(p.id, c);
                    setState(() {});
                  },
                ),
              ),
            ),
          for (var i = 0; i < p.invites.length; i++)
            Card(
              child: ListTile(
                title: Text(p.invites[i].name),
                subtitle: Text('Invitation : ${p.invites[i].status}'),
                trailing: p.invites[i].status == 'en attente'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.check,
                                  color: AppColors.ok),
                              onPressed: () {
                                appStore.respondInvite(p.id, i, true);
                                setState(() {});
                              }),
                          IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.err),
                              onPressed: () {
                                appStore.respondInvite(p.id, i, false);
                                setState(() {});
                              }),
                        ],
                      )
                    : null,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invite,
                  decoration: const InputDecoration(
                      hintText: 'Inviter une personne (identité)…'),
                ),
              ),
              IconButton(
                onPressed: () {
                  appStore.inviteCollaborator(p.id, _invite.text);
                  _invite.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.person_add, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Contrôle qualité & livraison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          TextField(
            controller: _delivery,
            decoration: const InputDecoration(
                labelText: 'Lien de livraison finale (optionnel)',
                hintText: 'Lien sécurisé fourni par l’équipe technique'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    appStore.qcPass(p.id, _delivery.text);
                    setState(() {});
                    showOk(context,
                        'Contrôle qualité réussi : projet archivé.');
                  },
                  child: const Text('CQ réussi → Archiver'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final reason = await reasonDialog(
                        context, 'Contrôle qualité — retour en correction');
                    if (reason != null) {
                      try {
                        appStore.qcFail(p.id, reason);
                        setState(() {});
                      } on BookingException catch (e) {
                        if (context.mounted) showError(context, e.message);
                      }
                    }
                  },
                  child: const Text('CQ : correction'),
                ),
              ),
            ],
          ),
          if (p.deliveryLink != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Livraison : ${p.deliveryLink}',
                  style: const TextStyle(color: AppColors.ok)),
            ),
          const ConfirmNote(
              'La livraison finale n’est considérée comme disponible qu’après un contrôle qualité enregistré. L’archivage ne supprime rien avant la politique de conservation de l’UEMF.'),
        ],
      ),
    );
  }

  String _stageHint(ProjectStage stage, Booking? linked) {
    switch (stage) {
      case ProjectStage.preproduction:
        return p.documents.isEmpty
            ? 'Script déposé ? Non — déposez au moins un document.'
            : 'Script déposé ✓ (${p.documents.length} document(s))';
      case ProjectStage.production:
        return linked == null
            ? 'Session validée requise.'
            : 'Session validée le ${fmtDay(linked.date)}.';
      case ProjectStage.postproduction:
        return 'Montage : ${p.editingStatus}${p.corrections.any((c) => !c.resolved) ? ' — correction demandée' : ''}';
      case ProjectStage.validation:
        return 'Contrôle qualité, puis livraison et archivage.';
    }
  }
}
