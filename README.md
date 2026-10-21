# Жүгүм кайда? (aydoochu_app)

Кардар ↔ айдоочу тиркемеси (Flutter). Кардар заказын картадан көрөт:
кайсы машина, гос номер, түсү, айдоочу жана азыр кайда келе жатканы.

## Иштетүү
```
cd aydoochu_app
flutter create . --org kg.gruz --project-name aydoochu_app   # android/ios папкаларын түзөт (lib/ жана pubspec.yaml өзгөрбөйт)
flutter pub get
flutter run
```

## Иконка
`assets/icon/` ичинде даяр. Android/iOS папкалары түзүлгөндөн кийин бир жолу:
```
dart run flutter_launcher_icons
```
Тиркеменин аты телефондо "Жүгүм кайда?" болушу үчүн `android/app/src/main/AndroidManifest.xml` ичиндеги `android:label` маанисин өзгөртүңүз.
Android'де релиз үчүн `android/app/src/main/AndroidManifest.xml` ичине
`<uses-permission android:name="android.permission.INTERNET"/>` кошуңуз.

## Азыркы абал (демо)
- Карта: OpenStreetMap (flutter_map), ачкыч талап кылынбайт.
- Айдоочу "Жолго чыктым" басканда машина маршрут боюнча симуляция менен жылат.
- Кардар бөлүмүндө ошол эле позиция жандуу көрүнөт.

## Кийинки кадамдар (чыныгы колдонуу үчүн)
1. Сервер: Firebase (Auth + Firestore) — заказдар жана `drivers/{id}/location`.
2. Айдоочунун чыныгы GPS: `geolocator` пакети, фондо ар 5 сек сайын Firestore'го жазуу.
3. `TrackingService` ичиндеги симуляцияны Firestore snapshot угуучусуна алмаштыруу.
4. Кирүү (телефон номери менен), заказ түзүү (сатуучу панели), push-билдирүүлөр.

## Код түзүлүшү
```
lib/
  main.dart                  кирүү чекити
  core/                      models, theme, tracking_service (маалымат жана логика)
  widgets/                   order_map, plate (номер + машина карточкасы), sheet (жылма панель)
  features/
    role_screen.dart         "Кардар" / "Айдоочу" тандоо
    order_screen.dart        кардар жана айдоочу үчүн бир экран (isDriver белгиси менен)
```
