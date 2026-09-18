# Authentication migration

## Current and target identity

The legacy app queried `users` by phone and compared a custom SHA-256
`passwordHash` (and, for very old records, plaintext `password`). That data is
never copied into Firebase Authentication and is no longer written for new
accounts. `FirebaseAuthRepository` is now the identity authority for new
registrations and email sign-ins; its profile is `users/{uid}` with role
`customer` by default.

## Legacy accounts

There is no safe way to turn an existing SHA-256 digest into a Firebase Auth
password. Existing documents are retained, but phone-first login is now
migration-only and does not query `users/*` before authentication. A legacy user
must use password reset/re-registration with the same verified email or complete
an account relink. After relinking, the Firebase UID becomes the canonical
profile owner. Never expose or log the old hash, and never restore public user
document reads to keep the legacy login working.

## Coexistence and removal

SharedPreferences still preserves the demo session and cart. New Firebase
sessions also clear this legacy session on logout. The compatibility fields can
be removed only after all legacy users have reset/relinked and analytics show
no remaining reads of `passwordHash`.
