import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("exploration archive reader enforces owner, retention, service ACL, legacy compatibility and failed checkpoints", async () => {
  const db = new PGlite();
  const owner = "11111111-1111-4111-8111-111111111111",
    foreign = "22222222-2222-4222-8222-222222222222",
    session = "33333333-3333-4333-8333-333333333333",
    id = "44444444-4444-4444-8444-444444444444";
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
 create table lector_generator_conversations(id uuid,user_id uuid,mode text,expires_at timestamptz);
 create table lector_generator_turns(user_id uuid,conversation_id uuid,status text,started_at timestamptz,usage jsonb);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261013220000_generator_exploration_archive_reader.sql",
      ),
    );
    await db.query(
      `insert into lector_generator_conversations values($1,$2,'workshop',now()+interval '24 hours')`,
      [session, owner],
    );
    const insert = async (status: string, time: string, report: unknown) =>
      db.query(
        `insert into lector_generator_turns values($1,$2,$3,now()+$4::interval,$5::jsonb)`,
        [
          owner,
          session,
          status,
          time,
          JSON.stringify({ evaluations: [report] }),
        ],
      );
    await insert("complete", "-4 hours", {
      id,
      evaluated: 62,
      rows: [],
      oldFormat: true,
    });
    const next = "55555555-5555-4555-8555-555555555555";
    await insert("failed", "-1 hour", {
      id: next,
      evaluated: 70,
      checkpoint: true,
    });
    const read = async (user = owner, evaluation: string | null = id) =>
      (await db.query<{ report: any }>(
        `select lector_generator_exploration_read($1,$2,$3) report`,
        [user, session, evaluation],
      )).rows[0].report;
    assert.equal((await read()).oldFormat, true);
    assert.equal((await read(owner, null)).id, next);
    await assert.rejects(() => read(foreign), /Unauthorized/);
    const permissions = await db.query<{ allowed: boolean }>(
      `select has_function_privilege('authenticated','lector_generator_exploration_read(uuid,uuid,uuid)','execute') allowed`,
    );
    assert.equal(permissions.rows[0].allowed, false);
    await db.exec("set role service_role");
    assert.equal((await read()).evaluated, 62);
    await db.exec("reset role");
    await db.query(
      `update lector_generator_conversations set expires_at=now()-interval '1 minute'`,
    );
    await assert.rejects(() => read(), /Session expired/);
    // Rollback removes only the accessor; the existing archives remain untouched.
    await db.exec(
      "drop function lector_generator_exploration_read(uuid,uuid,uuid)",
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from lector_generator_turns",
      )).rows[0].n,
      2,
    );
  } finally {
    await db.close();
  }
});
