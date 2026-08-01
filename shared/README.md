# Shared

Types and contracts shared between the app, consoles and API.

Includes the chart snapshot schema — the contract by which clients upload computed charts.
Changing it requires coordinated releases, since older app versions will continue uploading
the previous shape.

**No computation logic here.** This package is consumed by the server, so it must remain free
of any AGPL-derived code.
