# ElioTV (multiplateforme)

Lecteur IPTV gratuit : codes Xtream, lien ou fichier M3U. Un seul code Flutter pour
**Android, Android TV / Fire TV, Windows, iPhone/iPad et Mac**, avec le moteur vidéo
libmpv (media_kit) : MPEG-TS, HLS, MKV, HEVC, AC3, DTS, sous-titres…

ElioTV est un lecteur : il ne fournit aucune chaîne.

## Fonctions
- Connexion Xtream / lien M3U / fichier M3U ; plusieurs fournisseurs enregistrés.
- TV, films, séries ; catégories, recherche sans accents, favoris (appui long), récents.
- Filtres pays (langue), genre, année ; tri par année, ajout, note, nom.
- Guide TV (programme en cours et suivant).
- Lecteur : pistes audio, sous-titres, plein écran ; bascule automatique .ts ↔ .m3u8.
- Plein écran au clavier ou à la télécommande : ↑ ↓ zapper, ← → ±10 s, OK pause, Retour.
- Android TV : apparaît sur l'écran d'accueil TV, navigation complète à la télécommande.

## Compiler
Prérequis : Flutter (`brew install --cask flutter`).

| Plateforme | Commande | Résultat |
|---|---|---|
| Android / TV | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Mac | `flutter build macos --release` | `build/macos/Build/Products/Release/ElioTV.app` |
| Windows | sur un PC Windows : `flutter build windows --release`, ou automatiquement sur GitHub (voir ci-dessous) | `build/windows/x64/runner/Release/` |
| iPhone / iPad | `flutter build ios` (composant iOS de Xcode requis ; installation sur appareil = compte Apple) | |

## GitHub (gratuit)
`.github/workflows/build.yml` compile Windows et Android à chaque envoi sur la branche `main` ;
les fichiers sont téléchargeables dans l'onglet **Actions** du dépôt.

## Tests
- `flutter test` : logique (pays, genres, M3U, adresses de flux).
- `flutter test integration_test/playback_test.dart -d macos` : lecture réelle
  (lancer d’abord le faux serveur de test : `python3 tool/mock_xtream.py`).
