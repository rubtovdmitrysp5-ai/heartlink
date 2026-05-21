# HeartLink

HeartLink — современное iOS-приложение для пары на SwiftUI. Интерфейс приложения полностью на русском языке, кодовая структура и комментарии — на английском.

## Что уже включено

- SwiftUI app shell с `TabView`, `NavigationStack` и MVVM.
- Onboarding, authentication flow, главный экран, чат, воспоминания, цели, игры, настроение и защита.
- Firebase integration layer: Authentication, Firestore, Storage, Messaging, Analytics, Crashlytics.
- Sample mode: приложение показывает демо-данные, если `GoogleService-Info.plist` ещё не добавлен.
- WidgetKit extension: home screen и lock screen widget для дней вместе.
- Launch screen и концепт app icon.
- GitHub Actions для macOS-сборки через XcodeGen.
- GitHub Pages web-preview в виде iPhone-рамки с интерактивными экранами приложения.

## Как работать на Windows бесплатно

На Windows можно редактировать проект, хранить его на GitHub и смотреть web-preview. Нативную iOS-сборку делает GitHub Actions на macOS runner.

1. Создайте публичный репозиторий на GitHub.
2. Загрузите файлы проекта.
3. Включите GitHub Pages в настройках репозитория.
4. Откройте вкладку Actions и дождитесь workflow `Pages`.
5. Для iOS-проверки workflow `iOS` установит XcodeGen, создаст Xcode project и запустит `xcodebuild`.

Локально preview можно открыть на Windows:

```text
web-preview/index.html
```

Внутри preview есть iPhone-рамка, onboarding, вход, главная, чат, воспоминания, цели, игры, настроение, защита и bottom tab bar.

## Как открыть на Mac

```bash
brew install xcodegen
xcodegen generate
open HeartLink.xcodeproj
```

В Xcode выберите signing team, добавьте `GoogleService-Info.plist` в `HeartLink/Resources`, затем запустите схему `HeartLink`.

## Firebase

Создайте Firebase-проект и iOS app с bundle id:

```text
com.example.heartlink
```

Скачайте `GoogleService-Info.plist` и положите его в:

```text
HeartLink/Resources/GoogleService-Info.plist
```

Затем включите:

- Authentication: Email/Password
- Cloud Firestore
- Cloud Storage
- Cloud Messaging
- Crashlytics
- Analytics

Security rules лежат в `firestore.rules` и `storage.rules`.

## Структура

```text
HeartLink/
  App/
  Models/
  ViewModels/
  Services/
  Views/
  Resources/
HeartLinkWidgets/
web-preview/
.github/workflows/
```

## Важные ограничения

- Xcode и iOS Simulator работают только на macOS.
- App Store публикация требует Apple Developer Program.
- Push notifications в production требуют Apple Developer account и APNs key.
- Фото и голосовые сообщения требуют корректных Firebase Storage rules и лимитов тарифа.
