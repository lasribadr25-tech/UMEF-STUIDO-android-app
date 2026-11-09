# Euromed Studios — Application Flutter (d'après Figma + specs GitHub)

Application Android (Flutter) de **réservation et de gestion des Euromed Studios**
de l'Université Euromed de Fès, réalisée d'après :

- le fichier Figma **MPCFrOf9lWTGoVmska985o** (pages 00 à 12 : carte produit,
  fondations & design system, accueil & coquille, studios & réservations,
  projets, équipement, notifications & QR, incidents & maintenance,
  approbations, opérations, administration, états globaux, flux prototype) ;
- les spécifications **Phase 1 du dépôt GitHub UEMF-Studio**
  (`docs/specs/product-scope-roles.md`, `docs/specs/reservations.md`,
  `docs/specs/equipment-projects-maintenance-notifications-qr.md`, Issue #9).

> ⚠️ **Statut : brouillon local privé.** Cette application est livrée pour
> relecture par badr uniquement. Elle ne prétend à **aucune approbation de
> l'équipe** : le README du dépôt d'équipe indique que la Phase 1 est terminée
> et que « Flutter implementation has not started », et la revue d'équipe
> (gate Issue #9 : revue Mouhssine + revue croisée Yassine, puis approbation
> humaine des trois) reste à lever avant tout partage, fusion ou PR.
> **Ne pas pousser ce code sur GitHub sans décision explicite de badr.**

> Toutes les données sont stockées **localement sur le téléphone**,
> dans une vraie base **SQLite** (`uemf_studio.db`, voir la section
> « Base de données » ci-dessous). Aucun serveur, aucun compte réel,
> aucune donnée ne quitte l'appareil. L'authentification UEMF réelle,
> le backend, la base de données partagée et les notifications push
> relèvent d'étapes ultérieures.

## Ouvrir le projet sur Windows (Android Studio)

1. Décompressez `uemf-studio-figma-app.zip` (ou copiez le dossier).
2. Dans Android Studio : **File → Open** → sélectionnez **la racine du
   projet** `uemf-studio-figma-app` — **pas** le sous-dossier `android/`
   (ouvrir `android/` seul casse la résolution Flutter, comme pour tout
   projet Flutter).
3. Vérifiez que vous voyez bien le **projet complet** : `pubspec.yaml`,
   `lib/`, `android/` et `test/` doivent apparaître à la racine. Si vous
   ne voyez que le contenu d'`android/` (ou si la vue semble vide),
   basculez le panneau de gauche de la vue **Android** vers la vue
   **Project** (menu déroulant en haut du panneau), ou utilisez
   **Ctrl+Shift+N** (recherche de fichier) et tapez `pubspec.yaml` pour
   confirmer que le fichier est bien là.
4. Dans un terminal (celui d'Android Studio) :
   ```bash
   flutter pub get
   ```
   Attendez le message **`Got dependencies!`** : c'est la confirmation
   que les dépendances sont installées. Si des messages signalent que des
   versions plus récentes existent, **ignorez-les** : ne lancez **pas**
   `flutter pub upgrade` sauf si une dépendance échoue réellement
   (une mise à jour peut casser la résolution).
5. Si la liste **Select Device** est grisée (aucun appareil) : créez un
   émulateur via **Tools → Device Manager → Create Device** (choisissez
   un téléphone récent, par exemple Pixel, avec une image système
   recommandée), lancez-le, puis vérifiez :
   ```bash
   flutter devices
   flutter run
   ```
   ⚠️ **Le premier lancement prend plusieurs minutes** : le premier
   `flutter run` (ou `flutter build apk --release`) télécharge et
   compile Gradle et les dépendances Android. C'est normal — laissez-le
   terminer sans l'interrompre.
   Pour produire l'APK installable :
   ```bash
   flutter build apk --release
   ```
   L'APK se trouve ensuite dans `build/app/outputs/flutter-apk/app-release.apk`.
6. Prérequis : Flutter 3.x et le SDK Android installés. Le projet déclare
   `sdk: '>=3.13.0 <4.0.0'` dans `pubspec.yaml` : il accepte donc Dart
   3.13.4 (aucune fonctionnalité n'exige une version plus récente, la
   contrainte est simplement alignée sur la machine de développement).
   Le fichier `android/gradle.properties` limite le daemon Gradle à
   `-Xmx4G` (valeur sûre sur une machine à 8 Go de RAM).
   L'APK livré avec ce dossier exige **Android 7.0 minimum (SDK 24)**.

## Tester le parcours complet (comptes de démonstration)

Sur l'écran de connexion, **aucun mot de passe n'est vérifié** (démo locale) :
choisissez un compte, puis « Entrer dans l'application ».

| Compte démo | Rôle | Pour tester |
|---|---|---|
| Mouhssine | Étudiant (EIDIA) | Réserver, quota, sessions, QR |
| Pr. El Amrani | Professeur | Priorité pédagogique, suivi projet MOOC |
| Équipe Com UEMF | Communication | Demande Plateau TV en attente entité |
| Salma B. (Club Cinéma) | Club | Réservation club (représentant identifié) |
| Client Démo | Client Externe | Demande avec mention devis (sans facturation) |
| Karim R. | Technique / Régisseur | Occupation, incidents |
| Responsable Vie Étudiante | Approbateur entité (Niveau 1) | File Niveau 1 |
| Responsable des Studios | Approbateur studio (Niveau 2) | Validation technique |
| Administrateur Studios | Administrateur | Planning, équipement, blocs, rapports, config |
| — | Invité (sans compte) | Consultation des studios seulement |

**Parcours de référence** (identique au flux prototype Figma) :

1. En **Étudiant** : Studios → Studio Podcast → « Réserver ce studio » →
   étape 1 activité (un seul usage : Enregistrement, Captation d'image,
   Montage ou Mixage audio) → étape 2 date + créneau (08h–18h, pause
   13h–14h) → étape 3 matériel (quantité, requis/optionnel) → étape 4
   charte (acceptation obligatoire, signature tactile optionnelle) →
   étape 5 récapitulatif → « Envoyer la demande ». La demande part en
   **En attente entité** et le créneau est **pré-verrouillé**.
2. Déconnectez-vous (Profil → Déconnexion), reconnectez-vous en
   **Responsable Vie Étudiante** → menu ⋮ → Validations → Niveau 1 →
   « Approuver » : la demande passe en **En attente studio**. Un refus
   exige un motif et notifie le demandeur.
3. Reconnectez-vous en **Responsable des Studios** → Validations →
   Niveau 2 → « Valider techniquement » (la validation re-vérifie le
   créneau, les blocs maintenance et les éléments requis) : la demande
   devient **Validée** et le QR devient actif **pendant le créneau
   seulement** (détail de la session → « Voir le QR d'accès » →
   « Simuler un scan »).
4. Onglet **Projets** : pipeline A→B→C→D, documents de pré-production,
   session Validée à lier pour passer en production, corrections,
   contrôle qualité → archivage et livraison.
5. Menu ⋮ → **Régie** (occupation Libre/Occupé/Inconnu) et **Incidents**
   (signalement, triage, gravité, blocage des ressources graves).
6. En **Administrateur** : menu ⋮ → Administration (planning global,
   équipement & blocs, rapports & journal, quotas et seuil de fraîcheur
   configurables).

**Règles métier implémentées** (specs, pas d'invention) :

- Cycle : En attente entité → En attente studio → Validée, puis Refusée /
  Annulée / Expirée / Terminée. Pas de passage direct entité → Validée.
- Conflit début inclus / fin exclue : une réservation finissant à 10h00 ne
  bloque pas un créneau débutant à 10h00.
- Annulation par le demandeur avant le début uniquement ; elle libère
  créneau et ressources. En attente non approuvée au début → Expirée ;
  Validée → Terminée à la fin du créneau (transitions automatiques à
  chaque ouverture de l'app).
- Quota hebdomadaire (semaine lundi–dimanche) : les statuts En attente
  entité, En attente studio, Validée et Terminée comptent ; Refusée,
  Annulée et Expirée ne comptent pas. **Valeurs configurables** (voir
  ci-dessous) — les valeurs par défaut sont des valeurs d'exemple.
- Auto-approbation interdite, y compris en cas de cumul de fonctions
  (note Figma page 00) : un valideur ne peut pas décider de sa propre
  demande.
- Équipement : un élément **requis** indisponible bloque la validation
  technique ; un optionnel indisponible est signalé, jamais retiré ou
  remplacé en silence. Substitution uniquement explicite et approuvée.
- QR : émis après validation Niveau 2, actif uniquement pendant
  `[début, fin)` heure du campus, sans période de grâce par défaut,
  plusieurs passages autorisés pour les participants autorisés.
- Notifications : les résultats de réservation sont obligatoires et non
  désactivables ; les notifications de projet sont configurables.
- Occupation : une information plus ancienne que le seuil configuré
  devient « Inconnu » (le seuil n'est pas figé à 15 minutes).
- Réconciliation U1–U4 : après chaque action, l'app relit l'état réel
  (Profil → « États & récupération ») ; un refus déjà engagé n'est jamais
  rejoué ni re-notifié.

## Carte Figma → écrans de l'app

| Page Figma | Écrans implémentés |
|---|---|
| 00 Product Map & Notes | Notes reprises dans ce README (points ouverts) ; auto-approbation interdite appliquée |
| 01 Foundations & Design System | `lib/theme.dart` : palette, statuts, espacements, rayons, composants (cartes, puces, boutons, champs, navigation) |
| 02 Home & App Shell | Bienvenue, Connexion, Accueil (4 actions rapides, prochaine session, projet), Profil, Rôles & Permissions, Tableau de bord — Rôles, Aide & Contact |
| 03 Studios & Reservations | Catalogue (recherche), fiche studio, réservation 5 étapes, récapitulatif, demande envoyée, Mes sessions, détail (modifier/annuler), quota, variantes Club / Externe (devis), studios invité, sessions Refusée / Annulée / Expirée / Terminée |
| 04 Projects | Mes projets, pipeline A–D, nouveau projet, détail, correction, livraison & CQ, collaborateurs (invitation accepter/refuser), projets archivés, suivi professeur (via projets) |
| 05 Equipment | Catalogue équipement, détail (règle requis/optionnel), équipement admin |
| 06 Notifications & QR | Notifications (lu/non lu, résultats obligatoires), paramètres, session + QR, résultat de scan simulé |
| 07 Incidents & Maintenance | Signaler un incident, triage, détail, bloc maintenance (admin) |
| 08 Approvals | File entité (Niveau 1), validation technique Disponible / Bloquée (Niveau 2), refus avec motif |
| 09 Studio Operations | Régie — occupation, mise à jour de l'occupation |
| 10 Administration | Planning global, équipement & blocs, rapports & journal, configuration (quotas, fraîcheur, utilisateurs démo) |
| 11 Global States | Chargement, vide, erreur (messages d'échec explicites), permission refusée, ressource indisponible, créneau pris, U1 vérification / U2 résultat inconnu / U3 action enregistrée / U4 action non enregistrée |
| 12 Prototype Flows | Flux cliquables Figma reproduits : Bienvenue → Connexion → Accueil → Studios → Réservation (5 étapes) → Sessions → QR ; Projets → Pipeline → Correction → Livraison ; Rôles → Approbations / Occupation / Incidents ; Admin → Planning / Équipement / Rapports |

## Structure du code (`lib/`)

| Fichier | Rôle |
|---|---|
| `main.dart` | Entrée + coquille : 4 onglets (Accueil, Studios, Projets, Sessions), menu ⋮ par rôle, FAB Réserver / Créer |
| `theme.dart` | Tokens Figma page 01 (couleurs, statuts, rayons, composants partagés) |
| `models.dart` | Rôles, studios (8 espaces), équipement, réservations (7 statuts), projets (4 types, pipeline 4 étapes), incidents, notifications, occupation, blocs, journal, configuration |
| `store.dart` | État global, règles métier, persistance locale, données de démonstration |
| `auth.dart` | Bienvenue, connexion démo, profil, rôles, tableau de bord rôles, aide, paramètres notifications, états U1–U4 |
| `home.dart` | Onglet Accueil |
| `studios.dart` | Catalogue, fiche studio, assistant de réservation 5 étapes, détail session, QR + scan simulé |
| `sessions.dart` | Mes sessions (filtres par statut), notifications, recherche globale |
| `projects.dart` | Projets : liste, création, détail/pipeline, corrections, collaborateurs, CQ/livraison |
| `approvals.dart` | Files d'approbation Niveau 1 et Niveau 2, refus avec motif |
| `ops.dart` | Régie/occupation, incidents, équipement (consultation) |
| `admin.dart` | Administration : planning, équipement & blocs, rapports & journal, configuration |
| `widgets.dart` | Composants partagés (cartes, puces de statut, états vide/erreur/permission, pilule session) |
| `signature_pad.dart` | Zone de signature tactile de la charte |

Dépendances : `shared_preferences` (persistance locale), `qr_flutter`
(QR d'accès), `cupertino_icons`. Aucune autre dépendance.

## Fonctionnalité → fichier qui l'implémente

| Exigence / fonctionnalité | Fichier(s) |
|---|---|
| Thème Figma page 01 (couleurs, statuts, rayons) | `lib/theme.dart` |
| Modèles : rôles, studios, réservations, projets, incidents, notifications, occupation, blocs, config | `lib/models.dart` |
| Règles métier : quotas, conflits, cycle de vie, validations L1/L2, refus avec motif, expiry/completion automatiques, occupation, journal | `lib/store.dart` |
| Coquille 4 onglets, menu ⋮ par rôle, FAB Réserver / Créer | `lib/main.dart` |
| Bienvenue, connexion démo, profil, quota, rôles, aide, paramètres notifications, états U1–U4 | `lib/auth.dart` |
| Accueil (hero, 4 actions rapides, prochaine session, projet) | `lib/home.dart` |
| Catalogue studios, fiche studio, réservation 5 étapes, détail session (modifier/annuler), QR + scan simulé, signature charte | `lib/studios.dart`, `lib/signature_pad.dart` |
| Mes sessions (filtres), notifications, recherche globale | `lib/sessions.dart` |
| Projets : création, pipeline A–D, documents, session Validée liée, corrections, collaborateurs, CQ/livraison, archivés | `lib/projects.dart` |
| Files d'approbation Niveau 1 et Niveau 2, refus avec motif | `lib/approvals.dart` |
| Régie/occupation, incidents (signalement, triage, détail), équipement (consultation) | `lib/ops.dart` |
| Administration : planning global, équipement & blocs, rapports & journal, configuration (quotas, fraîcheur) | `lib/admin.dart` |
| Composants partagés : cartes, puces de statut, états vide/erreur/permission, pilule session | `lib/widgets.dart` |
| Tests de fumée (statuts, catalogue, règle de conflit) | `test/smoke_test.dart` |
| Code natif Android (manifeste, Gradle, icône) — rien d'autre n'y vit | `android/` uniquement |

## Base de données

**Choix actuel (tests, gratuit, décidé le 04/11/2026) : SQLite, en local.**
Aucun compte, aucun serveur, aucun coût, fonctionnement hors ligne.

- **Implémentation** : `sqflite` (+ `path`, `path_provider`).
  Le métier ne parle jamais directement à SQLite : il passe par
  l'interface `AppRepository` (`lib/data/repository.dart`), implémentée
  par `SqliteAppRepository` (`lib/data/sqlite_repository.dart`).
- **Fichier** : `uemf_studio.db`, dans le dossier de documents de
  l'application. Sur un téléphone, il est inspectable via
  `adb` ou le Device File Explorer d'Android Studio (dossier de
  l'application, `app_flutter/uemf_studio.db`) ; il n'est pas copié
  dans le zip du projet.
- **Tables** : `meta`, `current_user`, `bookings`, `booking_equipment`,
  `projects`, `project_invites`, `project_corrections`, `incidents`,
  `equipment`, `maintenance_blocks`, `notifications`, `occupancy`,
  `audit`, `config`. Clés étrangères activées (suppression en cascade
  des lignes enfants). Index sur les réservations (date, studio,
  statut) et (utilisateur, rôle, date), sur les projets (étape,
  archivé), les notifications, les incidents et le journal.
- **Atomicité** : chaque sauvegarde réécrit l'état complet dans
  **une seule transaction SQLite** (tout ou rien). La création d'une
  réservation avec son contrôle de quota, et les transitions
  d'approbation L1/L2, ne peuvent donc pas laisser la base à moitié
  écrite. Les ID générés sont uniques même en cas de créations dans
  la même milliseconde (compteur monotone).
- **Migration depuis l'ancienne version** : à la première ouverture
  de cette version, si une ancienne sauvegarde SharedPreferences
  (`uemf_figma_state_v1`) existe et que la base SQLite est vide,
  elle est importée **une seule fois** dans SQLite, puis un drapeau
  (`uemf_figma_sp_migrated_v1`) empêche tout réimport ultérieur.
  L'ancienne clé est conservée intacte comme sauvegarde. S'il n'y a
  aucune ancienne donnée, les mêmes données de démo qu'avant sont
  créées directement en SQLite.
- **Réinitialiser la démo** : dans l'app, Profil → réinitialisation
  de la démo (ou effacer les données de l'application dans les
  paramètres Android, ce qui supprime aussi `uemf_studio.db`).
- **Limite à bien comprendre** : SQLite reste **locale à chaque
  téléphone**. Deux téléphones ne voient pas les mêmes données :
  une demande créée sur le téléphone A n'apparaît pas dans la file
  d'approbation du téléphone B. Pour un vrai usage multi-utilisateur,
  il faudra le backend partagé (voir ci-dessous).

## Plus tard : Firebase

**Firebase n'est PAS configuré dans cette version, par choix explicite
de badr (04/11/2026) : solution gratuite pour les tests d'abord,
Firebase à choisir plus tard.** Aucun projet Firebase, aucun compte,
aucune clé, aucun paquet `firebase_*` n'a été créé ou ajouté.

Quand badr choisira Firebase, le branchement se fera sans réécrire les
écrans ni les règles métier : il suffira d'écrire un
`FirebaseAppRepository` implémentant `AppRepository`
(`lib/data/repository.dart`) et de l'injecter dans `AppStore`.
Correspondance prévue (documentée aussi dans ce fichier) :

| Table SQLite | Collection Firestore prévue |
|---|---|
| `current_user` | `users/{userId}` (session, hors démo) |
| `bookings` | `bookings/{bookingId}` |
| `booking_equipment` | `bookings/{bookingId}.equipment` |
| `projects` | `projects/{projectId}` |
| `project_invites` | `projects/{projectId}.invites` |
| `project_corrections` | `projects/{projectId}.corrections` |
| `incidents` | `incidents/{incidentId}` |
| `equipment` | `equipment/{itemId}` |
| `maintenance_blocks` | `maintenance_blocks/{blockId}` |
| `notifications` | `notifications/{notificationId}` |
| `occupancy` | `occupancy/{spaceId}` |
| `audit` | `audit/{entryId}` |
| `config` | `config/app` (document unique) |

Les vérifications qui devront alors devenir des transactions Firestore
et des règles de sécurité (et non plus des contrôles locaux) sont :
création de réservation + quota + pré-verrouillage, transitions L1/L2
(état attendu vérifié à l'engagement, pas d'écrasement d'un état
terminal, une seule notification par refus), et comptage du quota
hebdomadaire.

## Points ouverts / écarts assumés (à confirmer par l'UEMF ou l'équipe)

1. **Inventaire définitif des espaces réservables** : Figma affiche 6 espaces
   réservables + 2 supports, chacun avec « Réservabilité à confirmer ». Les
   11 espaces de la première version (octobre 2026) — studio photo, régies
   détaillées, espace montage — ne figurent pas dans le nouveau fichier
   Figma et n'ont pas été repris, sauf Régie Plateau et Salon VIP en
   espaces support. La spec elle-même laisse l'inventaire ouvert (Issue #8).
2. **Quotas** : les valeurs par défaut (Étudiant 2 h, Professeur 6 h,
   Communication 8 h, Club 4 h, Externe 4 h, autres illimités) sont des
   **valeurs d'exemple configurables** (Administration → Configuration),
   pas des règles UEMF. La spec interdit de figer le « 2 h / semaine »
   du Cahier comme règle définitive.
3. **Routage Niveau 1 détaillé** : la correspondance par établissement
   (Vie Étudiante / Doyen / DirCom / Vice-Présidence) est appliquée par
   catégorie de demandeur, mais le routage fin par établissement et la
   désignation/révocation des représentants de club restent à confirmer.
4. **Devis externe** : la demande externe affiche le contexte commercial
   et le valideur Niveau 1 (Vice-Présidence Exécutive), mais le périmètre
   du devis, la tarification et la facturation sont hors V1 (aucune
   facturation ni paiement implémenté).
5. **Priorité professeurs** (Studio Pédagogique / Speed MOOC) : affichée
   comme règle, mais son mécanisme ne contourne ni l'approbation ni une
   réservation valide existante — la spec ne le définit pas davantage.
6. **Seuil de fraîcheur de l'occupation** : 30 minutes par défaut,
   configurable (15 / 30 / 60 / 120) ; il n'est pas figé à 15 minutes.
7. **Quantités d'équipement** (kit caméra 2, kit micro 3, kit lumière 2) :
   valeurs de démonstration modifiables par l'administrateur, « quantité
   à confirmer » selon Figma.
8. **Polices** : Figma utilise Plus Jakarta Sans (titres) et DM Sans
   (texte/contrôles). Leurs fichiers ne sont pas livrés avec le projet :
   l'app utilise la police système avec les mêmes graisses et tailles.
   Ajouter les fichiers `.ttf` sous `assets/fonts/` + déclaration dans
   `pubspec.yaml` pour une fidélité typographique exacte.
9. **Photographies** : les visuels sont les photos des studios déjà
   utilisées en octobre 2026 (dossier `assets/images/`), pas des captures
   Figma. Aucune URL temporaire Figma n'est utilisée dans le code.
10. **Comportements Figma-only** (écran fidèle, règle non définie par les
    specs) : l'écran « Devis envoyé » (confirmation externe), les écrans
    « Invité — … » par studio (déclinés en mode invité global), la
    « Recherche — Sans filtres » et les exemples datés de novembre 2026
    des maquettes (les données de démo de l'app utilisent des dates
    relatives — aujourd'hui/demain — pour rester testables).
11. **Hors périmètre V1 (specs)** : authentification réelle, backend /
    base partagée, notifications push, paiement/facturation, gestion
    complète de la maintenance (SLA, délais, réouverture d'incident),
    capteurs IoT d'occupation, analyses avancées et modifications en
    masse, handoff/retour physique du matériel (remise/retour différés).
12. **Réconciliation réseau** : en local, les opérations sont immédiates ;
    les états U2 (résultat inconnu) et U4 (action non enregistrée) sont
    documentés et vérifiables (écran États & récupération), mais aucun
    échec réseau réel n'est simulé.

## Vérifications effectuées

- `flutter analyze` : 0 erreur, 0 avertissement (6 remarques « info »
  sur l'API RadioListTile dépréciée de Flutter 3.47, fonctionnelle).
- `flutter test` : 6/6 passent — 3 tests de fumée (statuts, catalogue,
  règle de conflit début inclus / fin exclue) + 3 tests SQLite
  (round-trip d'une réservation, persistance d'une approbation Niveau 1,
  comptage du quota hebdomadaire lu depuis la base).
- Build APK : **réussi le 04/11/2026** sur la machine de construction
  (`flutter build apk --release`, `app-release.apk`, livré à côté
  du dossier sous le nom `uemf-studio-figma.apk` — taille exacte
  dans le rapport de livraison, l'ancien APK a été remplacé par le
  nouveau build SQLite). Sur Windows, il peut être reconstruit à
  l'identique via `flutter build apk --release`.
