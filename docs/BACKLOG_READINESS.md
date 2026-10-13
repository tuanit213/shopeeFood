# Backlog and Jira Readiness

Review date: 2026-10-12  
Jira space: `DeliveryApp` (`SCRUM`)

## Current Jira evidence

- Sprint 0: 12 work items, 38 story points, 29 To Do, 9 In Progress, 0 Done; sprint dates 2026-09-22 to 2026-10-06.
- Sprint 1: 14 work items, 56 story points, all To Do; dates 2026-10-06 to 2026-10-20; sprint has not been started.
- Sprint 2: 11 work items, 55 story points, all To Do; dates 2026-10-20 to 2026-11-03.
- Many work items are unassigned even though members have been added to the space.
- Jira status does not yet reflect the code already implemented on local branches.

## Priority backlog before review

| Priority | Work | Owner | Evidence required |
| --- | --- | --- | --- |
| P0 | Reconcile Jira statuses with Git commits and test results | Trần Hoàng Anh Tuấn | Links from each completed item to commit/test evidence. |
| P0 | Push reviewed backend/catalog branch to GitHub | Trần Hoàng Anh Tuấn | Remote branch and commit SHA visible. |
| P0 | Publish SRS and review report | Trần Hoàng Anh Tuấn | `docs/SRS.md` and `docs/REVIEW_READINESS_2026-10-13.md`. |
| P0 | Deploy Flutter Web frontend to VPS | Văn Công Tín | Public URL, HTTPS response, screenshot, and rollback command. |
| P0 | Deploy rules, indexes, and Functions to isolated staging | Lê Công Tuấn | Firebase project ID and deployment output. |
| P0 | Validate customer flow against deployed staging backend | Thiều Trung Kiên | Login/catalog/cart/createOrder smoke-test evidence. |
| P0 | Validate map, address, and tracking flows | Nguyễn Trường Khải | Address/map screenshots and test evidence. |
| P1 | Add approved restaurant/menu dataset | Lê Công Tuấn | Non-empty manifest with provenance and seed report. |
| P1 | Integrate driver app with the same staging order lifecycle | Nguyễn Trường Khải | Assignment-to-completion E2E trace. |
| P1 | Update README with architecture and deploy instructions | Văn Công Tín | Reviewer can set up project from repository only. |

## Suggested assignment by member

| Member | Focus |
| --- | --- |
| Trần Hoàng Anh Tuấn | Team lead, Jira reconciliation, GitHub branches, integration gate, final report. |
| Lê Công Tuấn | Firebase Functions, catalog seed, Firestore rules/indexes, staging deployment. |
| Thiều Trung Kiên | Customer Flutter UI, checkout/createOrder integration, demo smoke flow. |
| Nguyễn Trường Khải | Address V2, map/GPS/route, driver lifecycle integration. |
| Văn Công Tín | Tests, README/SRS evidence, Flutter Web build, VPS/Nginx deployment. |

## Jira hygiene required

1. Close or complete the expired Sprint 0 only after statuses are reconciled.
2. Start at most one active sprint.
3. Assign every active work item to a real member.
4. Move items to Done only with a linked commit and passing acceptance evidence.
5. Separate `local/emulator done` from `staging deployed` so the board does not overstate completion.
