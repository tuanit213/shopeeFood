# Review Readiness - 2026-10-13

## Executive status

| Area | Status | Evidence / blocker |
| --- | --- | --- |
| Backlog | AMBER | Structured Jira backlog exists, but the expired sprint shows 0 Done and many items are unassigned. |
| GitHub | AMBER | Remote `main` exists at `4abd47e`; current backend work is on local branch `feature/real-catalog-staging` at `b5d8f5b` with uncommitted changes. |
| SRS | GREEN | `docs/SRS.md` documents actors, requirements, trust boundaries, acceptance criteria, and gaps. |
| Jira | AMBER | Space and sprints are available; statuses/assignees require reconciliation with code evidence. |
| Backend | GREEN (local) | Functions unit tests and Auth + Firestore + Functions emulator `createOrder` integration pass. |
| Frontend | GREEN (local) | `flutter analyze` passes and all 98 Flutter tests pass. |
| VPS deploy | RED | No VPS host/domain/SSH credentials or verified public URL are available. Deployment files are prepared. |
| Firebase staging | RED | No isolated staging Firebase project and no approved non-empty catalog dataset are configured. |

## Verified commands

### Flutter frontend

```powershell
& 'C:\Users\LOQ\development\flutter\bin\flutter.bat' pub get
& 'C:\Users\LOQ\development\flutter\bin\flutter.bat' analyze
& 'C:\Users\LOQ\development\flutter\bin\flutter.bat' test
```

Observed on 2026-10-12:

- Analyze: `No issues found!`
- Tests: `98` passed, `All tests passed!`

### Firebase Functions backend

```powershell
npm --prefix functions test
firebase emulators:exec --only firestore,auth,functions --project shopeefood-6a82f "npm --prefix functions run test:emulator"
```

Observed on 2026-10-12:

- Functions unit tests: `3 passed`
- Emulator integration: exit code `0`
- Assertions passed: authentication, idempotency, immutable snapshots, pricing, and `ORDER_PLACED` event.
- Environment warning: Functions requests Node 20 while the host currently runs Node 24.

### Catalog seed guard

```powershell
node tools\seed_catalog.mjs --emulator
```

Observed: dry-run succeeds, but all dataset counts are `0`.

## Architecture statement for review

- Frontend: Flutter customer application; a separate Flutter driver MVP also exists.
- Backend: Firebase Authentication, Firestore, security rules/indexes, and callable Cloud Functions.
- VPS: hosts the compiled Flutter Web static application through Nginx. Firebase backend services remain deployed on Firebase infrastructure.
- Trusted order flow: Flutter sends IDs and quantities to `createOrder`; the function loads server catalog data, validates availability, calculates pricing, writes immutable snapshots, and applies idempotency.

## Demonstration order

1. Open Jira backlog and explain sprint/epic structure.
2. Open GitHub and show the exact branch/commit used for the demo.
3. Open `docs/SRS.md` and identify functional/non-functional requirements.
4. Run `flutter analyze` and `flutter test`.
5. Run Functions unit tests and emulator integration.
6. Demonstrate customer app: auth, catalog, cart, address, checkout, order tracking.
7. Demonstrate driver MVP separately and state that production integration is pending.
8. Open the VPS frontend URL and explain Firebase backend deployment separately.
9. Finish with known gaps and the next sprint plan; do not claim staging/VPS completion without the URL and deployment output.

## Immediate completion checklist

- [ ] Review and commit current Phase 2.5 changes.
- [ ] Push `feature/real-catalog-staging` to GitHub.
- [ ] Update Jira assignments and statuses with commit links.
- [ ] Supply approved catalog data with provenance.
- [ ] Create/select an isolated Firebase staging project.
- [ ] Deploy Firestore rules, indexes, and Functions to staging.
- [ ] Provide VPS host/domain and deploy the Flutter Web image.
- [ ] Run public smoke tests and capture evidence.
