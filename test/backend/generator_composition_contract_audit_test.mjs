// Local SQL validation only. No Supabase calls, provider collection or model.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { PGlite } = await import(Deno.env.get('PGLITE_MODULE') ?? 'npm:@electric-sql/pglite@0.5.8');
const pg = new PGlite();
try {
 const prior = await readFile('supabase/migrations/20261014090000_generator_request_audit.sql','utf8');
 const oldSummary = prior.slice(prior.indexOf('create function public.lector_generator_audit_summary'),prior.indexOf('create or replace function public.lector_generator_cleanup'));
 await pg.exec('create role anon; create role authenticated; create role service_role; create table conversation_sentinel(id int); insert into conversation_sentinel values(1); create table ticket_sentinel(id int); insert into ticket_sentinel values(2);');
 await pg.exec(oldSummary);
 await pg.exec('revoke all on function public.lector_generator_audit_summary(jsonb) from public,anon,authenticated;grant execute on function public.lector_generator_audit_summary(jsonb) to service_role;');
 const migration = await readFile('supabase/migrations/20261015090000_generator_composition_contract_audit.sql','utf8');
 await pg.exec(migration);
 const value={failure_contract:{code:'composition_details_missing',queryId:'q2',dossierKeys:['hockey:425260']},request:{requestId:'real-request'},failure_message:'Missing dossier',privateReasoning:'must not be retained',apiToken:'must not be retained'};
 const {rows} = await pg.query('select lector_generator_audit_summary($1::jsonb) result',[JSON.stringify(value)]);
 assert.deepEqual(rows[0].result.failure_contract,value.failure_contract);assert.ok(!JSON.stringify(rows).includes('must not'));
 const acl = async()=> (await pg.query("select not has_function_privilege('anon','public.lector_generator_audit_summary(jsonb)','execute') and not has_function_privilege('authenticated','public.lector_generator_audit_summary(jsonb)','execute') and has_function_privilege('service_role','public.lector_generator_audit_summary(jsonb)','execute') safe")).rows[0].safe;
 assert.equal(await acl(),true);
 await pg.exec(oldSummary.replace('create function','create or replace function'));
 assert.equal(await acl(),true);
 assert.equal((await pg.query('select count(*)::int n from conversation_sentinel')).rows[0].n,1);
 assert.equal((await pg.query('select count(*)::int n from ticket_sentinel')).rows[0].n,1);
 console.log(JSON.stringify({migration:true,rollback:true,aclPreserved:true,conversationsPreserved:true,ticketsPreserved:true,privateFieldsExcluded:true}));
} finally { await pg.close(); }
