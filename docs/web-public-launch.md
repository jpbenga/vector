# Lector : domaine personnalisé et responsive

## Décision recommandée

L’application est déjà en ligne sur Vercel. Le travail demandé consiste à lui
rattacher un nom de domaine de marque et à harmoniser le responsive. Conserver
Flutter pour l’application, Vercel pour les fichiers web et Supabase pour les
comptes et les données. Chrome et Safari sont pris
en charge sur mobile comme sur ordinateur par Flutter.
[Navigateurs pris en charge](https://docs.flutter.dev/platform-integration/web/faq).

Le domaine personnalisé donne une adresse de marque. Il n’est pas nécessaire
pour partager l’application : l’adresse Vercel existante suffit déjà.
Un domaine ne rend pas automatiquement l’interface responsive.

**Choix confirmé : `lector-sports.com`.** La réservation n’est pas effectuée.
Adresse principale proposée : `https://lector-sports.com/`, avec
`https://www.lector-sports.com/` redirigée vers l’adresse principale.

L’utilisateur a confirmé un hébergement Vercel. Le dépôt contient `vercel.json`
et `tool/build_web_staging.sh`, mais aucune configuration Firebase Hosting.
La configuration réelle du compte Vercel et la connexion sur le site public
n’ont pas été inspectées dans cette intervention.

## Noms envisagés

Vérification du 3 octobre 2026 ; aucun achat ni réservation effectués :

| Nom | Constat |
| --- | --- |
| `lector.com` | Déjà enregistré dans le registre officiel .com |
| `lector.ai` | Déjà utilisé par lector.ai GmbH pour son propre service |
| `lector-sport.com` | Le registre .com renvoie 404 : aucun domaine enregistré trouvé lors de la vérification |
| `lector-sports.com` | Même constat |

Un résultat 404 du registre n’est ni une réservation ni un prix garanti. La
disponibilité finale, le prix et le renouvellement sont à confirmer auprès du
fournisseur au moment de la commande. Racheter `lector.com` serait une démarche
auprès de son propriétaire, différente d’une inscription au tarif courant.

Sources : [registre officiel lector.com](https://rdap.verisign.com/com/v1/domain/lector.com),
[registre officiel lector-sport.com](https://rdap.verisign.com/com/v1/domain/lector-sport.com),
[registre officiel lector-sports.com](https://rdap.verisign.com/com/v1/domain/lector-sports.com),
[service utilisant lector.ai](https://legal.app.lector.ai/html/lector.ai_agbs.html).

## Ce qui expliquait l’incohérence des captures

L’accueil possédait une largeur maximale ; les pages Mon espace, compétitions,
scénarios et stratégies utilisaient des listes à la largeur totale de la fenêtre.
Flutter permet le responsive, mais le choix des contraintes et des dispositions
doit être effectué dans les composants.
[Approche Flutter](https://docs.flutter.dev/ui/adaptive-responsive/general).

## Corrections locales

`lib/core/widgets/lector_responsive_layout.dart` centralise les contraintes :

| Usage | Comportement |
| --- | --- |
| Téléphone | Largeur disponible ; défilement vertical ; options empilées |
| Pages de préférences et explications | Colonne centrée, au maximum 760 pixels logiques |
| Mon espace | Au maximum 1120 pixels ; deux colonnes de cartes dès 820 pixels disponibles à l’intérieur du contenu |
| Texte agrandi | Retour à une colonne pour les options de Mon espace |
| Détail de rencontre | Au maximum 1120 pixels ; les composants conservent leurs adaptations internes |
| Apparence | Aperçu et catalogue côte à côte lorsque la place le permet, sinon empilés |
| Accueil, Tous et Bilan | Conservent leurs dispositions ; largeur de 1120 centralisée |
| Configuration initiale | Formulaire et récapitulatif centrés, largeur de 760 |

Les marges internes sont comprises dans le cadre : les contrôles ne touchent
pas les bords. Les arrière-plans gardent la largeur de la fenêtre. Les composants
gardent leurs tailles de texte et leur fonctionnement ; la page n’est pas une
image mobile agrandie. Le manifeste autorise aussi l’orientation paysage.

Cette étape harmonise les pages publiques concernées. Elle ne constitue pas
une refonte de chaque tableau, fenêtre secondaire ou panneau d’administration.
Les pages Apparence et les guides possédaient déjà des adaptations internes.

## Étapes pour le domaine

1. Réserver **`lector-sports.com`** dans votre compte, par exemple depuis la
   gestion des domaines Vercel afin de conserver une gestion simple.
   Vérifier son prix de renouvellement,
   pas seulement le prix de la première année. Le coût dépend du domaine et du
   fournisseur ; aucun achat n’a été effectué.
2. Dans le projet Vercel existant : **Settings → Domains → Add Domain**.
   Ajouter **`lector-sports.com`** puis **`www.lector-sports.com`**.
   Rediriger `www` vers `lector-sports.com`.
3. Chez le fournisseur du domaine, recopier exactement les enregistrements DNS
   indiqués par Vercel. Ne pas reprendre une adresse IP provenant d’un tutoriel.
   Attendre que Vercel confirme le domaine et son certificat HTTPS.
   [Configuration du domaine](https://vercel.com/docs/domains/working-with-domains/add-a-domain).
4. Dans Vercel, renseigner les variables du build **Production** :

   | Variable | Valeur |
   | --- | --- |
   | `APP_PUBLIC_URL` | `https://lector-sports.com/` |
   | `APP_ENV` | `production` |
   | `SUPABASE_URL` | L’origine du projet Supabase actuel |
   | `SUPABASE_ANON_KEY` | La clé publique actuelle |
   | `MATCH_FEED_SOURCE` | `auto` |

   Le script prend désormais en compte `APP_ENV`. Sans cette variable, les
   previews conservent `staging`. Ces valeurs sont compilées dans l’application :
   changer une variable Vercel nécessite un nouveau build/déploiement.
   Les clés privées du backend ne doivent pas être fournies au build du front.

5. Dans Supabase : **Authentication → URL Configuration**. Mettre le domaine
   **`https://lector-sports.com/`** en **Site URL** et ajouter les URL de retour exactes utilisées par
   l’application dans **Redirect URLs**. Le code conserve le chemin courant au
   retour OAuth : `/` pour l’entrée normale, ainsi que les autres chemins utilisés
   pour se connecter s’il y en a. Garder les URL de développement et de preview
   nécessaires séparément. Cela évite une connexion qui revient vers localhost
   ou une autre adresse.
   [URL de retour Supabase](https://supabase.com/docs/guides/auth/redirect-urls).
6. Vérifier le parcours Google. Avec Supabase comme intermédiaire, l’URL callback
   du fournisseur est celle de Supabase, pas nécessairement le domaine Lector.
   Vérifier aussi si le consentement Google reste limité aux comptes de test.
7. Après validation locale, publier la version via le projet Vercel existant.
   Le dépôt configure déjà la distribution de `build/web` et la réécriture des
   chemins vers `index.html`. Valider aussi la branche de production réellement
   configurée dans Vercel ; ne pas en déduire l’état à partir du seul dépôt.
8. Sur le domaine final, vérifier : entrée invitée, connexion et reconnexion,
   chargement des données, changement de date, lien direct et actualisation,
   préférences, mobile portrait/paysage et clavier lors d’une recherche.

Effectuer les étapes de configuration de l’authentification après la réservation
et l’activation HTTPS du domaine. Ne pas compiler cette adresse dans la version
publique tant que le domaine n’est pas sous votre contrôle : la connexion doit
continuer à revenir sur l’adresse existante pendant la préparation.

## Coût et infrastructure

Le passage à un domaine ne requiert pas une nouvelle base de données ou une
nouvelle infrastructure. Les fichiers Flutter sont servis par Vercel ; les
appels aux données et l’authentification restent sur Supabase. La croissance
du trafic peut augmenter la bande passante et les lectures, mais le responsive
ne lance aucun batch supplémentaire et ne change pas la collecte.

Prévoir le renouvellement annuel du domaine et vérifier le plan Vercel : **Hobby
est réservé à un usage personnel non commercial**. Pour une activité commerciale,
prévoir un plan compatible ; consulter le prix actuel avant de souscrire.
[Conditions du plan Hobby](https://vercel.com/docs/plans/hobby).

## Ensuite, sans retarder l’accès par navigateur

- Une petite page de présentation en HTML peut faciliter la découverte par les
  moteurs de recherche ; l’application Flutter reste dédiée à l’usage interactif.
- Nom, icône, description, aide, contact et informations de confidentialité doivent
  être finalisés pour présenter le service aux visiteurs.
- Le manifeste existant prépare l’ajout à l’écran d’accueil. Cela ne prouve pas
  un fonctionnement hors connexion : ne pas annoncer les données hors ligne sans
  un travail et une validation spécifiques.
- Vérifier le cache des fichiers d’entrée lors des publications. Un navigateur
  peut conserver une ancienne version selon les en-têtes du serveur et les
  éventuels service workers. Le domaine ne corrige pas ce comportement.
  [Cache des versions Flutter web](https://docs.flutter.dev/platform-integration/web/faq).
- Mesurer démarrage, poids du build et erreurs sur quelques navigateurs réels
  avant une ouverture large. Aucun SDK de suivi n’a été ajouté ici.

## Vérifier sans téléphone ni simulateur

Depuis le dépôt :

```bash
cd "/Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration"
bash tool/run_web_with_env.sh 8099 release
```

Dans Chrome, ouvrir les outils de développement puis activer la barre d’appareils
avec **Cmd + Shift + M** sur Mac. Utiliser **Responsive** et modifier la largeur :
320, 390, 768, 1280 et 1920. Revenir en vue normale pour contrôler le bureau.
Les dimensions concernent la fenêtre de l’application, pas toute la capture.

Les tests Flutter contrôlent ces cinq largeurs sur les pages réelles, le passage
une/deux colonnes, la navigation, les préférences et le texte agrandi. Ils peuvent
être exécutés sans téléphone ni émulateur :

```bash
flutter test test/features/matches/presentation/lector_responsive_pages_test.dart
```

L’émulation Chrome permet de contrôler la disposition. Elle ne reproduit pas
complètement Safari iOS, le clavier et les performances d’un téléphone réel.
Une courte validation par des testeurs sur leurs téléphones restera utile.
