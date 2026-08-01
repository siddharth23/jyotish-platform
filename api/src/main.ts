/**
 * API entry point.
 *
 * LICENSING CONSTRAINT
 *   This service must never compute an astrological chart. It receives computed
 *   chart JSON from clients and stores it.
 *
 *   The calculation engine is AGPL-3.0. Invoking it from this process would place
 *   this entire repository under AGPL and oblige us to publish its source.
 *
 *   See docs/AGPL-BOUNDARY.md.
 */

export function main(): void {
  // TODO: bootstrap configuration, database, routes and workers.
  throw new Error('Not yet implemented.');
}
