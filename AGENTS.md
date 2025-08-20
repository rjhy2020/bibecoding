# Repository Guidelines

## Project Overview
EnglishPlease is an LLM‑powered English learning app. Users ask for an expression in chat; a server function generates native‑like phrases and 10 short practice sentences. The app then runs a speaking loop: show meaning → user speaks → STT transcribes → score (WER/pronunciation) → map to FSRS ratings (Again/Hard/Good/Easy) for spaced review. Stack: Flutter (client) with Firebase Auth/Firestore/Functions/Storage (backend). All keys and LLM/STT calls run in Cloud Functions.

## How to access Windows
Use /mnt

## Git
git@github.com:rjhy2020/bibecoding.git
When you do a task and commit it, make sure the title is in Korean.

## Project Structure & Module Organization
- `lib/`: app code (pages, widgets, services, models)
- `test/`: unit/widget tests (`*_test.dart`)
- `assets/`: fonts/images (declare in `pubspec.yaml`)
- Platform folders: `android/`, `ios/`, `web/`
- Entry point: `lib/main.dart`

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies
- `flutter run -d chrome` — run on web for fast dev
- `flutter analyze` — static checks; keep 0 warnings
- `dart format .` — 2‑space formatting
- `flutter test` — run all tests
- `flutter test --coverage` — coverage report

## Coding Style & Naming Conventions
- Dart style; 2‑space indent; prefer `final/const` and small widgets
- Names: Classes `PascalCase`, files `snake_case.dart`, members `lowerCamelCase`
- Lints: `flutter_lints` (see `analysis_options.yaml`); fix warnings before commit

## Testing Guidelines
- Framework: `flutter_test`
- Mirror `lib/` layout in `test/`; files end with `_test.dart`
- Write focused tests per behavior; prioritize services/models, then widgets

## Commit & Pull Request Guidelines
- Conventional Commits: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Small, atomic commits; explain “why” in the body when non‑obvious
- PRs: clear description, linked issues, screenshots for UI, passing analyze/tests

## Security & Configuration Tips
- Never commit secrets; route LLM/STT via Functions
- Use Firestore rules (least privilege) and App Check
- Use per‑env config (CI or untracked `.env`); do not hard‑code keys
