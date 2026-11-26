# Modifications apportées (Item RDC + Item RDC Admin)

## 1. Sous-dossiers : icône (URL ou icône par défaut) — comme les dossiers
Admin (Documents + Vidéos) :
- « Sub-folder » : la feuille de création propose maintenant l'URL d'icône OU une icône prédéfinie.
- Nouveau bouton « Icon » sur chaque sous-dossier pour changer / retirer l'icône.
- Stockage : champs `icon` et `iconUrl` dans l'élément du sous-dossier (même format que les dossiers).
  Les anciens sous-dossiers sans icône restent valides (icône par défaut).
App utilisateur : les sous-dossiers affichent leur icône (documents et vidéos).
Aperçus admin (pages/user) : sous-dossiers et icônes désormais affichés (avant, un sous-dossier pouvait faire planter l'ouverture d'un PDF).

## 2. Affichage instantané
- La session et le catalogue démarrent dès l'ouverture, PENDANT le drapeau Lottie (`lazy:false` + `CatalogStore`).
  L'écran Lottie attend (3,2 s max) que profil + documents + vidéos + icônes soient prêts.
- Icônes : images décodées gardées en mémoire et peintes de façon synchrone (`RawImage`) → plus de clignotement.
- Les onglets reçoivent immédiatement la dernière version connue (`initialData`).
- Animations d'apparition raccourcies et limitées aux premiers éléments.

## 3. Tri / filtrage (barre « Trier »)
Plus récents · Plus anciens · A→Z · Z→A · Plus de contenu.
Appliqué à : dossiers (Documents, Vidéos), vidéos hors dossier, catégories, universités, documents d'université
(en plus du filtre TFC/Mémoire/Internship existant) — côté app ET côté admin (y compris aperçus).
Les nouveaux éléments reçoivent un `createdAt` ; les anciens sans date sont traités comme les plus anciens.

## 4. Erreurs corrigées
- `orderBy('createdAt')` masquait tout élément sans `createdAt` (vidéos, documents d'université) → tri côté appareil.
- `doc['items']` / `doc['title']` / `doc['url']` plantaient si le champ manquait → lecture sécurisée.
- Ajout de PDF : des entrées vides (titre ou URL vide) pouvaient être enregistrées → filtrées.
- Aperçu admin vidéos : un sous-dossier était traité comme une vidéo.
- Logos d'universités : icône « école » qui changeait après chargement → placeholder neutre + préchargement.

## 5. YouTube « Error Code: 150 »
Le lecteur intégré YouTube refuse certaines vidéos (150/101/152/153). Dans les deux apps, la vidéo bascule
automatiquement sur la page de lecture YouTube affichée DANS l'application (aucun téléchargement).
Fichiers : lib/pages/video_player_page.dart (app et admin).

## 6. Mise à jour : un lien par version d'Android
Pastebin : `apk_url` (défaut), `apk_url_android7` (Android 7.1 et moins), `apk_url_android8plus` (Android 8+).
Voir PASTEBIN_EXEMPLE.json. L'app détecte Android (MainActivity.kt -> sdkInt) et pré-sélectionne le bon lien ;
si les deux liens sont fournis, l'utilisateur peut changer via deux puces. Anciens Pastebin (apk_url seul) inchangés.

## 7. Images Supabase, couvertures, modes d'affichage, « Stage »
ADMIN
- Nouveau `lib/util/supabase_storage.dart` (à configurer : URL + clé anon) et `SUPABASE_SETUP.sql`.
- Bouton « Import … from gallery » dans : icône des dossiers / sous-dossiers / dossiers vidéo, logo d'université.
  L'image est réduite (icônes 192 px, couvertures 512 px) puis envoyée ; l'URL se remplit toute seule.
- Ajout de fichiers (PDF, vidéos, documents d'université) : couverture (URL ou import), nom du propriétaire, détails.
- `pubspec.yaml` : ajout de `image_picker` -> faire `flutter pub get`.
APP UTILISATEUR
- Modes d'affichage Liste / Détails / Grand (bouton à droite de « Trier », choix mémorisé) pour Documents, Vidéos
  et documents d'université. Couverture, propriétaire, date et détails affichés ; les vidéos YouTube prennent
  automatiquement leur miniature.
- « Internship » renommé « Stage » (admin + app). Les anciens documents « Internship » restent visibles sous « Stage ».

## 8. Modifier la couverture d'un fichier existant (admin)
Bouton « image » à côté de la corbeille sur chaque fichier (PDF, vidéos, sous-dossiers, vidéos hors dossier,
documents d'université) : couverture (URL ou import), propriétaire (saisi) et détails. Champ vidé = champ retiré.
La clé Supabase « publishable » (sb_publishable_…) est aussi acceptée.
