# Preview mobile locale

## Démo multisport et Générateur conversationnel

Pour ouvrir la version actuelle de la démo sur le Mac, avec les données déjà
publiées et sans déclencher de collecte API-Hockey :

```sh
bash tool/run_demo_local.sh 8192 release
```

Ouvrir ensuite l'adresse affichée dans le navigateur habituel. Le lanceur sert
l'application sans ouvrir le profil Chrome temporaire de Flutter. La connexion
Lector doit être effectuée sur cette adresse locale ; elle est distincte de la
connexion sur Vercel. Le micro du Générateur nécessite un compte connecté.
L'adresse de retour doit également être autorisée dans Supabase → Authentication
→ URL Configuration → Redirect URLs. `http://localhost:8192/**` est enregistré.

Le lanceur active `LECTOR_GENERATOR_UI=true` et utilise
`lector-generator-workshop`. L'interface est locale, les requêtes du Générateur
utilisent le serveur démo : les changements des fonctions Supabase doivent être
déployés séparément. Un lancement local ne déploie pas ces fonctions.

Si le port est déjà occupé, le lanceur s'arrête avant de compiler et affiche
l'adresse à ouvrir pour consulter le serveur existant. Il ne ferme aucun
processus automatiquement.

`tool/run_multisport_local.sh` est le lanceur de collecte NHL locale. Il peut
consommer le quota fournisseur et ne sert pas à ouvrir simplement la démo.

## Preview depuis un téléphone

Ce workflow sert a tester rapidement l'application web locale depuis un
telephone, sans deployer.

## Commande

Depuis la racine du projet :

```sh
bash tool/mobile_preview.sh
```

Par defaut, le script compile l'application sur le port `8099` en mode
`release`, puis sert le dossier `build/web`.

Pour changer le port ou le mode :

```sh
bash tool/mobile_preview.sh 8099 release
bash tool/mobile_preview.sh 8100 debug
```

## Ce que fait le script

- detecte l'adresse IP locale du Mac ;
- construit une URL du type `http://192.168.x.x:8099/` ;
- compile le web avec cette URL comme `APP_PUBLIC_URL` ;
- desactive le service worker local pour eviter les caches blancs ;
- copie l'URL dans le presse-papiers ;
- genere `var/mobile-preview-qr.svg` quand `qrencode` ou `curl` est disponible ;
- ouvre le QR code a l'ecran seulement quand l'application est prete ;
- sert l'application avec `python3` sur `0.0.0.0` ;
- renvoie `index.html` pour les routes Flutter comme `/admin`.

Le telephone doit etre connecte au meme Wi-Fi que le Mac.

Si le port est deja occupe :

```sh
lsof -nP -iTCP:8099 -sTCP:LISTEN
kill $(lsof -tiTCP:8099 -sTCP:LISTEN)
```

## Auth Google

Pour tester Google sur mobile avec une URL locale, l'URL LAN affichee par le
script doit etre autorisee dans la configuration Supabase Auth / OAuth.
Sinon, le mode invite reste utilisable pour verifier les donnees et l'interface.
