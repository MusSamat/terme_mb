# Tappjet Mobile (`tappjet_mb`)

Нативное Flutter-приложение (iOS + Android) — порт мобильного клиента `tappjet_ft`.
Полное ТЗ: `../tappjet_mb_TZ.md`.

## Что уже есть (skeleton — этап 1 ТЗ)

- Дизайн-система: палитры, типографика, радиусы/тени, ролевая тема (guest/passenger/
  driver), light/dark — `lib/theme/*` (перенос из `tailwind.config.ts` + `role-colors.ts`).
- Шрифты Nunito + Fredoka — `assets/fonts/` (Fredoka без кириллицы → фолбэк Nunito 900).
- Локали ru + kg — `assets/l10n/` (скопированы из `tappjet_ft/src/messages`, ~1646 ключей).
- Навигация go_router + floating pill-nav с центральным create-FAB — `lib/app/*`, `lib/widgets/pill_nav.dart`.
- API-слой (dio + cookie jar + refresh-interceptor), token store, socket-обёртка — `lib/api/*`, `lib/socket/*`.
- Riverpod-провайдеры: auth, роль, тема, dio/socket — `lib/providers/*`.
- Экраны-заглушки под все маршруты §6.1 — `lib/screens/screens.dart`.

## Сгенерировать нативные платформы (нужен установленный Flutter)

Каталоги `android/` и `ios/` генерирует сам инструмент. В корне проекта:

```bash
cd /home/musa/projects/tappjet_mb
flutter create . --org kg.tappjet --project-name tappjet_mb --platforms=android,ios
flutter pub get
```

> `flutter create .` добавит только недостающие нативные файлы и не тронет `lib/`.
> Проект уже под git — при желании закоммить skeleton до генерации, чтобы видеть diff.

## Запуск

```bash
flutter run \
  --dart-define=API_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=WS_URL=http://10.0.2.2:3000
```

(`10.0.2.2` — хост-машина из Android-эмулятора; для iOS-симулятора — `localhost`.)

## Кодогенерация (когда появятся freezed/retrofit-модели)

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Подключение к бэкенду (ТЗ step 2)

Слой API готов (`lib/api/`): dio-клиент с refresh-интерцептором, `PagedResult`,
модели с `fromJson`, сервисы по доменам (`api/services/`), провайдеры
(`providers/data_providers.dart`). Экраны сейчас читают mock через провайдеры.

**Чтобы подключить реальный бэкенд:**
```bash
flutter run \
  --dart-define=USE_MOCK=false \
  --dart-define=API_URL=https://api.tappjet.kg/api/v1 \
  --dart-define=WS_URL=wss://api.tappjet.kg
```
Флаг `AppConfig.useMock` (env `USE_MOCK`) переключает провайдеры между mock и
`GET /trips` и т.д. Готовый шаблон — `TripsService` + `tripsFeedProvider`;
остальные домены (bookings/requests/chat/notifications/loyalty/cities) добавляются
по тому же образцу. `apiBootstrapProvider` привязывает refresh к `AuthService`.

Следующие шаги: досоздать сервисы остальных доменов, перевести экраны с
`mock*()` на `ref.watch(...Provider)`, вписать реальный auth-flow вместо DEV-входа,
подключить сокет (`SocketClient`) к чату/уведомлениям.

## Структура — см. ТЗ §4.
