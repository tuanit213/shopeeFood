# ShopeeFood Project Agents

Project: Flutter ShopeeFood clone with Firebase/Firestore, mobile-first UI, and Android/Web debug flows.

Use agents from `.codex/agents/` when a task matches their scope. Keep changes local unless user explicitly asks to commit or push.

## Primary Agents

### `ux-architect`
Use for:
- UI/UX structure, screen hierarchy, layout rhythm, responsive behavior.
- ShopeeFood visual consistency: spacing, typography, colors, icon/menu systems.
- Reviewing designs before implementation.

Best tasks:
- "review main page UI"
- "make login/register match ShopeeFood"
- "fix responsive overflow"
- "design profile/order empty state"

### `frontend-developer`
Use for:
- Flutter UI implementation, widgets, animations, carousel, hover/press states.
- Performance-sensitive frontend fixes.
- Visual QA after changes.

Best tasks:
- "implement this screen"
- "add animation"
- "fix layout on Android"
- "make banner/category/menu smoother"

### `code-reviewer`
Use before:
- Commit.
- Push.
- Merge branch into `main`.
- Any larger UI/Firebase refactor.

Review priorities:
- Runtime bugs.
- Flutter lifecycle issues.
- Async/Firebase error handling.
- Missing validation.
- Performance regressions.
- Dirty worktree safety.

### `backend-architect`
Use for:
- Firebase Auth and Firestore data architecture.
- User registration/login/profile flow.
- Order, rating, Shopee coin, restaurant, and promotion data models.
- Security rules and app-level data ownership.

Best tasks:
- "profile must use real registered data"
- "design Firestore schema"
- "connect login/register to Firebase"
- "make logout/session flow correct"

### `database-optimizer`
Use for:
- Firestore collection/query/index design.
- Data duplication strategy for fast mobile reads.
- Avoiding fake profile/order stats.
- Query cost and pagination decisions.

Best tasks:
- "optimize Firestore reads"
- "orders should load fast"
- "where to store restaurant/deal data"
- "what indexes are needed"

## Agents Not Copied By Default

`api-tester` is not included because this project currently uses Firebase directly, not a separate REST API.

`product-manager` is not included because this project is still in UI/Firebase build phase. Add it later if planning roadmap, team split, or sprint scope becomes the main task.

## Project Rules

- Do not commit or push unless user explicitly asks.
- Preserve user/team changes in dirty worktree.
- Prefer Flutter-native widgets and existing project structure.
- Use real Firebase/Firestore data where user asks for "thật"; do not add fake stats.
- Run `flutter analyze` after code changes.
- For UI changes, run local preview or Android build when possible.

## Useful Commands

```powershell
cd D:\ProjectCaNhan\ShopeeFood\shopeefood
& 'C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat' analyze
& 'C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat' build web
& 'C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat' build apk --debug
```
