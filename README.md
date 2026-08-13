# Neurostatus

Application Android de suivi d'humeur au quotidien.

Une notification quotidienne invite à noter :
- un état général sur une échelle de 1 à 5,
- les émotions principales du jour (liste prédéfinie ou personnalisée),
- un évènement majeur (optionnel).

Tout est conservé localement (SQLite) pour un suivi sur plusieurs années,
avec un écran d'historique, un graphique d'évolution, un journal de crises,
un export CSV/JSON pour les sauvegardes, et un import des exports Daylio.

## Développement

Projet Flutter classique.

```
flutter pub get
flutter run
```

## Build APK

```
flutter build apk --release
```

L'APK généré se trouve dans `build/app/outputs/flutter-apk/app-release.apk`
et peut être installé directement sur un téléphone Android (sideload).
