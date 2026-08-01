# Chart module

**Storage only.**

Receives computed chart snapshots from clients and persists them as immutable JSONB, keyed by
birth data hash, ayanamsa, house system and engine version.

This module does not compute anything. If you find yourself wanting to add a computation here
— for a migration, an admin repair, a batch job — stop and read `docs/AGPL-BOUNDARY.md`.
