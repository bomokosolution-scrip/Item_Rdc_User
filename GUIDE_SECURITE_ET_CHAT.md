# Sécurité administrateur + Chat de groupe — mise en place (100 % gratuit)

## A. Créer le compte administrateur (Firebase)
1. Firebase Console > **Authentication** > **Users** > **Add user** : e-mail + mot de passe FORT. 
2. Copiez l'**UID** affiché dans la liste.
3. **Firestore Database** > **Données** > **Démarrer une collection** : ID de collection `admins`.
   ID du document = l'UID copié. Ajoutez un champ quelconque (ex. `role` = `admin`). Enregistrez.

## B. Installer la nouvelle app admin AVANT de changer les règles
1. Remplacez `lib/` du dépôt admin (zip `item_rdc_admin.zip`), puis **Build APK** et installez.
2. À l'ouverture : écran de connexion. Entrez l'e-mail / mot de passe du compte créé en A.
   - Si « Accès refusé » : l'UID n'est pas dans `admins` (revoyez A.3).
3. Vérifiez que le panneau s'affiche et que vous pouvez lire/modifier du contenu.

## C. Publier les règles sécurisées (seulement après B)
1. **COPIEZ d'abord vos règles actuelles** dans un fichier (pour pouvoir revenir en arrière).
2. Firestore > **Règles** > remplacez TOUT par `FIRESTORE_RULES_COMPLETE.rules` > **Publier**.
3. Ce que cela change : seuls les administrateurs peuvent écrire dans le contenu ; un utilisateur ne peut plus
   modifier son Premium ; les contenus Premium ne sont lisibles que par les comptes Premium ; les chats/publications
   sont protégés.
4. Test rapide : l'app utilisateur doit toujours afficher Documents / Vidéos / Bibliothèque ; l'admin doit toujours
   pouvoir ajouter/modifier.

## D. Ouvrir le chat
1. App admin > **Chat** > interrupteur **General chat open** (crée `settings/chat`).
2. App utilisateur (version 1.0.9) > onglet **Discussion** : choix du pseudo + règles, puis messages.
3. Modération (app admin > Chat) : **Messages** (supprimer / suspendre / réinitialiser un pseudo),
   **Reports** (messages signalés), **Suspended** (lever une suspension).

## E. Gratuité : points d'attention
- Firestore gratuit (Spark) : ~50 000 lectures et 20 000 écritures par jour. Le chat ne charge que 40 messages,
  puis les précédents à la demande. Chaque message envoyé est lu une fois par utilisateur connecté à l'écran Discussion.
  Surveillez Firebase > Firestore > Utilisation.
- Aucune notification push pour le chat (elles passent déjà par votre relais Cloudflare gratuit pour les annonces admin).
- Le pseudo est définitif ; l'admin peut le réinitialiser.

---

## F. Mise à jour : messages privés, « Contacter l'auteur », entraide (version 1.0.10)

1. **Republier les règles** : Firebase > Firestore > Règles > remplacer TOUT par le nouveau
   `FIRESTORE_RULES_COMPLETE.rules` > Publier. (Il ajoute `chat_dms`, `help_posts` et les signalements par type.)
2. **Admin** (nouvelle version) > **Chat** : trois interrupteurs indépendants
   - *General group* (groupe général),
   - *Help space (images)* (entraide),
   - *Private messages* (messages privés).
   Activez ceux que vous voulez. Onglets : Messages · Help · Reports · Suspended.
3. **App utilisateur** > Discussion : trois volets **Groupe · Entraide · Privé** (point rouge sur « Privé » = nouveau message).
4. **Contacter l'auteur** : bouton visible sur un document en affichage **Détails** ou **Grand**, seulement pour les
   documents publiés par un utilisateur APRÈS cette mise à jour (le compte de l'auteur est enregistré à l'acceptation).
   Les anciens documents et ceux ajoutés par l'admin n'ont pas ce bouton.
5. **Mes publications** : toucher une publication propose « Ouvrir le fichier » et, une fois validée, « Voir dans
   l'université / le dossier ».
6. **Images et fichiers du chat** : images -> bucket `media` (2 Mo max, réduites à 1024 px) ; fichiers (PDF, Word, Excel,
   PowerPoint, 10 Mo max) -> bucket `publications`. Stockage gratuit Supabase : 1 Go au total : surveillez Storage.
7. **Confidentialité** : les messages privés ne sont lisibles que par les deux participants (même pas par l'admin).
   L'admin ne voit que le contenu d'un message **signalé** par un participant, et peut suspendre l'auteur.
