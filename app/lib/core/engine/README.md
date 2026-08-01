# Engine wrapper

Wraps the AGPL-licensed `jyotish_engine` package.

**This code runs on the user's device. That is what makes using the AGPL edition possible.**

Rules:

1. Chart computation happens here and nowhere else.
2. The API receives computed results as JSON. It never receives a request to compute.
3. Do not add a fallback that asks a server to compute when the device cannot. There is no
   such server, and there must not be.

See `docs/AGPL-BOUNDARY.md`.
