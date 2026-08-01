# Astrologer console

Web application for vetted astrologers to claim orders, analyse charts and write evaluations.

## The engine runs here, in the browser

This console loads the WebAssembly build of the AGPL engine. That is permitted: it executes in
the astrologer's browser, a client-side context.

It must be loaded and executed **in the browser only**. Do not move chart computation into a
server-rendered path, an API route, or any Node process. See `docs/AGPL-BOUNDARY.md`.

## Features

Order queue with claim locking · chart workbench (D1, divisionals, dashas, yogas, transits) ·
structured report authoring with autosave · AI first-draft assistant requiring explicit
approval · four-eyes QA review · payout statements.
