# CLAUDE.md — Tappjet Mobile (`tappjet_mb`)

Нативное Flutter-приложение (iOS + Android). Порт мобильного клиента `tappjet_ft`.
**Полное ТЗ — источник истины: `../tappjet_mb_TZ.md`.** Читай его перед задачей.

## Стоп перед кодом
Неясно → один вопрос. Два варианта → назови оба, жди выбора. Показывай только
изменённые строки. Новый pub-пакет — только по явному запросу.

## Каноны (не менять)
- Стиль: `../tappjet_ft/tailwind.config.ts`, `globals.css`, `src/lib/role-colors.ts`
  → перенесено в `lib/theme/*`. Цвета/шрифты/радиусы — только через тему, без хардкода.
- API: `../tappjet_ft/src/lib/api/openapi.json` (65 путей). Контракт не меняем.
- Тексты: `../tappjet_ft/src/messages/{ru,kg}.json` → `assets/l10n/`. Только через
  `tr('ns.key')`, новые ключи — в оба файла.

## Стек
Flutter 3 · Riverpod · go_router · dio+retrofit · Hive · flutter_secure_storage ·
easy_localization (ru|kg) · socket_io_client · flutter_map · image_picker.

## Решения
Платформы iOS+Android. Auth = телефон+OTP (Telegram DM) + Telegram bot deep-link;
google/apple/phone_password — за флагом `AppConfig.authProviders`. Админки нет.

## Архитектура
Screen(Widget) → Provider(Riverpod) → Api-service(retrofit) → dio. Виджет не дёргает
dio напрямую. Структура — ТЗ §4.

## Никогда
Менять API/токены/ключи-текстов · хардкодить строки/цвета · refresh-токен в открытом
Hive · SMS при повторном входе · показывать телефон до accepted · тянуть админку.
