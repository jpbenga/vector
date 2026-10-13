import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("request audit remains owner-only after expiry, drops large facts and preserves existing decisions", async () => {
  const db = new PGlite();
  const owner = "11111111-1111-4111-8111-111111111111",
    other = "22222222-2222-4222-8222-222222222222",
    session = "33333333-3333-4333-8333-333333333333",
    request = "44444444-4444-4444-8444-444444444444";
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
      create table lector_generator_retention(id boolean,audit_days int);
      insert into lector_generator_retention values(true,30);
      create table lector_generator_conversations(id uuid primary key,user_id uuid,mode text,expires_at timestamptz);
      create table lector_generator_turns(request_id uuid,user_id uuid,conversation_id uuid references lector_generator_conversations on delete cascade,started_at timestamptz,status text,usage jsonb);
      create table lector_generator_session_audit(request_id uuid primary key,user_id uuid,started_at timestamptz,status text,usage jsonb);
      create table lector_generator_proposal_audit(generated_at timestamptz);
      create table retained_decisions(id int primary key,snapshot jsonb);
      create function lector_generator_cleanup() returns integer language sql as $$select 0$$;
      revoke all on function lector_generator_cleanup() from public,anon,authenticated;
      grant execute on function lector_generator_cleanup() to service_role;
      insert into retained_decisions values(1,'{"ticket":"preserved"}');`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261014090000_generator_request_audit.sql",
      ),
    );
    await db.query(
      `insert into lector_generator_conversations values($1,$2,'workshop',now()-interval '1 minute')`,
      [session, owner],
    );
    await db.query(
      `insert into lector_generator_turns values($1,$2,$3,now(),'failed',$4::jsonb)`,
      [
        request,
        owner,
        session,
        JSON.stringify({
          release: { revision: "fixed" },
          request: { message: "real request" },
          auditReports: [{ evaluated: 20, complete: false }],
          ticketRefs: [{ id: "ticket" }],
          evaluations: [{ large: "not-in-audit" }],
          ai: [{ tokens: 42 }],
          timings_ms: { model: 123 },
          failure_stage: "model",
        }),
      ],
    );
    const read = async (user = owner) =>
      (await db.query<{ r: any }>(
        "select lector_generator_request_audit_read($1,$2) r",
        [user, request],
      )).rows[0].r;
    assert.equal((await read()).audit.release.revision, "fixed");
    await assert.rejects(() => read(other), /Unauthorized/);
    await db.exec("select lector_generator_cleanup()");
    const report = await read();
    assert.equal(report.audit.request.message, "real request");
    assert.equal(report.audit.auditReports[0].evaluated, 20);
    assert.equal(report.audit.evaluations, undefined);
    assert.equal(
      (await db.query("select * from retained_decisions")).rows.length,
      1,
    );
    await assert.rejects(() => read(other), /Unauthorized/);
    const acl = await db.query<{ allowed: boolean }>(
      `select has_function_privilege('authenticated','lector_generator_request_audit_read(uuid,uuid)','execute') allowed`,
    );
    assert.equal(acl.rows[0].allowed, false);
    const event = "55555555-5555-4555-8555-555555555555";
    await db.query("select lector_generator_request_audit_write($1,$2,$3)", [
      owner,
      event,
      {
        request: { action: "exploration_compare" },
        release: { revision: "fixed" },
      },
    ]);
    await assert.rejects(
      () =>
        db.query("select lector_generator_request_audit_write($1,$2,$3)", [
          other,
          event,
          {},
        ]),
      /Unauthorized/,
    );
    const writeAcl = await db.query<{ allowed: boolean }>(
      "select has_function_privilege('authenticated','lector_generator_request_audit_write(uuid,uuid,jsonb)','execute') allowed",
    );
    assert.equal(writeAcl.rows[0].allowed, false);
    await db.exec(
      `update lector_generator_session_audit set started_at=now()-interval '31 days';select lector_generator_cleanup()`,
    );
    assert.equal(await read(), null);
  } finally {
    await db.close();
  }
});
