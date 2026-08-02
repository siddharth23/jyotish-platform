import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  FlagAuditService,
  FlagAuditError,
  InMemoryFlagAuditRepository,
} from '../dist/modules/admin/flags/flag_audit.js';

/** A service with a fixed clock and predictable ids, so assertions are exact. */
function makeService() {
  const repository = new InMemoryFlagAuditRepository();
  let counter = 0;
  const service = new FlagAuditService(
    repository,
    () => new Date('2026-08-02T12:00:00Z'),
    () => `id-${++counter}`,
  );
  return { service, repository };
}

const validChange = {
  flagKey: 'paid_evaluation',
  kind: 'disabled',
  actor: 'ops@jyotish.de',
  reason: 'No astrologer available; 72h SLA at risk.',
};

describe('US-006 AC3 — every flag change is audited', () => {
  test('records a change with actor, reason and version', async () => {
    const { service } = makeService();
    const entry = await service.record(validChange, 7);

    assert.equal(entry.flagKey, 'paid_evaluation');
    assert.equal(entry.kind, 'disabled');
    assert.equal(entry.actor, 'ops@jyotish.de');
    assert.equal(entry.reason, 'No astrologer available; 72h SLA at risk.');
    assert.equal(entry.version, 7);
    assert.equal(entry.at.toISOString(), '2026-08-02T12:00:00.000Z');
  });

  test('captures before and after state', async () => {
    const { service } = makeService();
    const entry = await service.record(
      { ...validChange, before: { enabled: true }, after: { enabled: false } },
      2,
    );
    assert.equal(entry.before, '{"enabled":true}');
    assert.equal(entry.after, '{"enabled":false}');
  });

  test('absent before/after are null, not the string "undefined"', async () => {
    const { service } = makeService();
    const entry = await service.record({ ...validChange, kind: 'created' }, 1);
    assert.equal(entry.before, null);
    assert.equal(entry.after, null);
  });
});

describe('An incomplete change is refused', () => {
  // The refusal is the point. An optional audit is complete right up until the
  // incident that needed it.
  test('no actor', async () => {
    const { service } = makeService();
    await assert.rejects(
      () => service.record({ ...validChange, actor: '' }, 1),
      (error) => error instanceof FlagAuditError && error.code === 'MISSING_ACTOR',
    );
  });

  test('no reason', async () => {
    const { service } = makeService();
    await assert.rejects(
      () => service.record({ ...validChange, reason: '' }, 1),
      (error) => error instanceof FlagAuditError && error.code === 'MISSING_REASON',
    );
  });

  test('whitespace does not count as a reason', async () => {
    const { service } = makeService();
    await assert.rejects(
      () => service.record({ ...validChange, reason: '   ' }, 1),
      (error) => error instanceof FlagAuditError && error.code === 'MISSING_REASON',
    );
  });

  test('no flag key', async () => {
    const { service } = makeService();
    await assert.rejects(
      () => service.record({ ...validChange, flagKey: '' }, 1),
      (error) => error instanceof FlagAuditError && error.code === 'MISSING_FLAG_KEY',
    );
  });

  test('a refused change writes nothing', async () => {
    const { service, repository } = makeService();
    await assert.rejects(() => service.record({ ...validChange, actor: '' }, 1));
    assert.deepEqual(await repository.list(), []);
  });
});

describe('History', () => {
  test('is newest first', async () => {
    const { service } = makeService();
    await service.record({ ...validChange, reason: 'first' }, 1);
    await service.record({ ...validChange, reason: 'second' }, 2);
    await service.record({ ...validChange, reason: 'third' }, 3);

    const history = await service.history('paid_evaluation');
    assert.deepEqual(
      history.map((entry) => entry.reason),
      ['third', 'second', 'first'],
    );
  });

  test('filters by flag', async () => {
    const { service } = makeService();
    await service.record(validChange, 1);
    await service.record({ ...validChange, flagKey: 'career_analysis' }, 2);

    const history = await service.history('career_analysis');
    assert.equal(history.length, 1);
    assert.equal(history[0].flagKey, 'career_analysis');
  });

  test('honours a limit', async () => {
    const { service } = makeService();
    for (let i = 0; i < 5; i++) {
      await service.record({ ...validChange, reason: `change ${i}` }, i + 1);
    }
    assert.equal((await service.history('paid_evaluation', 2)).length, 2);
    assert.equal((await service.recent(3)).length, 3);
  });

  test('the trail is append-only — a later change does not alter an earlier entry',
    async () => {
      const { service } = makeService();
      const first = await service.record({ ...validChange, reason: 'off' }, 1);
      await service.record({ ...validChange, kind: 'enabled', reason: 'on' }, 2);

      const history = await service.history('paid_evaluation');
      const stillThere = history.find((entry) => entry.id === first.id);
      assert.equal(stillThere.reason, 'off');
      assert.equal(stillThere.kind, 'disabled');
      assert.equal(stillThere.version, 1);
    });
});
