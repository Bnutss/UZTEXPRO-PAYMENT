# UzTexPro — Мобильное приложение для управления платежами

Корпоративное Flutter-приложение для сотрудников холдинга **UzTex**, обеспечивающее доступ к платёжным операциям, пропускам, подписанию заявок и бонусной системе с мобильного устройства.

---

## Возможности

| Раздел | Описание |
|---|---|
| **Платежи** | Просмотр и управление платёжными поручениями |
| **Пропуска** | Список пропусков сотрудников с детальной информацией |
| **Подписание заявок** | Согласование и отклонение заявок на закупку материалов |
| **Бонусы** | Просмотр, утверждение и удаление бонусных начислений |
| **Настройки** | Смена темы (светлая/тёмная), языка интерфейса (RU/UZ/EN), политика конфиденциальности |

### Ключевые особенности
- Биометрическая аутентификация (Face ID / отпечаток пальца)
- Тёмная и светлая тема
- Мультиязычный интерфейс: русский, узбекский, английский
- Кэширование данных для быстрой загрузки без интернета
- JWT-авторизация с безопасным хранением токена

---

## Стек технологий

- **Flutter** 3.x / **Dart** 3.x
- **HTTP** — `http` — запросы к REST API
- **Безопасное хранилище** — `flutter_secure_storage`
- **Биометрия** — `local_auth`
- **Интернационализация** — `intl`
- **Скелетная анимация загрузки** — `shimmer`
- **Локальные настройки** — `shared_preferences`

---

## Структура проекта

```
lib/
├── main.dart                        # Точка входа, глобальные константы (API, storage)
├── app/
│   └── pro_app.dart                 # Корневой виджет приложения, тема, роутинг
├── core/
│   ├── localization/
│   │   ├── app_strings.dart         # Строки локализации (RU / UZ / EN)
│   │   └── locale_notifier.dart     # ValueNotifier смены языка
│   └── storage/
│       └── app_storage.dart         # Обёртка над SharedPreferences
├── notifiers/
│   └── theme_notifier.dart          # ValueNotifier смены темы
└── features/
    ├── auth/
    │   └── login_page.dart          # Экран входа + биометрия
    ├── home/
    │   ├── menu_page.dart           # Главное меню
    │   └── main_page.dart           # Раздел платежей
    ├── passes/
    │   ├── passes_page.dart         # Список пропусков
    │   └── pass_detail_page.dart    # Детальная карточка пропуска
    ├── bonuses/
    │   ├── bonuses_page.dart        # Список бонусов
    │   └── bonus_detail_page.dart   # Детальная карточка бонуса
    ├── sign_requests/
    │   ├── sign_requests_page.dart       # Список заявок на подпись
    │   └── sign_request_detail_page.dart # Детали заявки + подпись
    └── settings/
        ├── settings_screen.dart     # Настройки приложения
        └── confidentiality_page.dart # Политика конфиденциальности
```

---

## Установка и запуск

### Требования
- Flutter SDK `>= 3.5.3`
- Dart SDK `>= 3.5.3`
- Android SDK (для Android-сборки) / Xcode (для iOS-сборки)

### Шаги

```bash
# Клонировать репозиторий
git clone <repo-url>
cd uztexpro_pay

# Установить зависимости
flutter pub get

# Запустить в режиме отладки
flutter run

# Собрать APK
flutter build apk --release

# Собрать IPA (iOS)
flutter build ios --release
```

---

## API

Приложение работает с REST API по базовому адресу:

```
https://pro.uztex.uz/api/v1
```

Аутентификация — Bearer JWT-токен в заголовке `Authorization`.

---

## Разработка

### Добавление нового языка

1. Открыть `lib/core/localization/app_strings.dart`
2. Добавить перевод в метод `of(BuildContext context)` по коду локали
3. Добавить код языка в `lib/features/settings/settings_screen.dart`

### Добавление нового раздела

1. Создать папку `lib/features/<название>/`
2. Добавить страницу в новую папку
3. Импортировать `../../core/localization/app_strings.dart` и `../../core/localization/locale_notifier.dart`
4. Добавить пункт меню в `lib/features/home/menu_page.dart`
