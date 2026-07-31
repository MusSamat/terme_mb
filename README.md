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

## Структура — см. ТЗ §4.
