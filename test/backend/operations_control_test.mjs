// Local PostgreSQL integration test. pg_net and pg_cron are simulated; no network.
// PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node test/backend/operations_control_test.mjs
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite}=await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const pg=new PGlite();
const query=(sql,args=[])=>pg.query(sql,args);
const one=async(sql,args=[]) => (await query(sql,args)).rows[0];
const scalar=async(sql,args=[]) => Object.values(await one(sql,args))[0];
let passed=0;
const test=async(name,run)=>{await run();passed++;console.log(`PASS ${name}`)};
try {
await pg.exec(`create role anon; create role authenticated; create role service_role bypassrls;
create schema extensions; create schema net; create schema cron;
create table cron.job(jobid bigint,jobname text,active boolean,schedule text);
insert into cron.job values(1,'api-football-enrichment-1',true,'15 3 * * 2'),(2,'unrelated-job',true,'* * * * *');
create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
create function cron.alter_job(job_id bigint,active boolean) returns void language sql as $$ update cron.job set active=$2 where jobid=$1 $$;
create table net.requests (id bigint generated always as identity, body jsonb);
create function net.http_post(url text, headers jsonb,body jsonb,timeout_milliseconds integer) returns bigint language sql as $$ insert into net.requests(body) values ($3) returning id $$;
create view public.api_football_mvp_leagues as select * from (values(1,'Championnat A'),(2,'Championnat B'),(3,'Coupe C')) as v(api_football_league_id,league_name);`);
await pg.exec(await readFile(new URL('../../supabase/migrations/20261001100000_operations_control.sql',import.meta.url),'utf8'));
await test('migration preserves existing weekly schedule',async()=>{
 const c=await one('select * from ops_competitions where league_id=1');
 assert.equal(c.enrichment_enabled,true);assert.equal(c.enrichment_day,2);assert.equal(c.enrichment_timezone,'UTC');assert.equal(c.enrichment_time,'03:15:00');
});
await query("select ops_configure('https://test.invalid','test-secret',false,'admin')");
const cycle=await scalar("select ops_enqueue(array[1,2],'Test','manual','admin')");
await test('duplicate and unknown leagues refused atomically',async()=>{
 await assert.rejects(()=>query("select ops_enqueue(array[1],'Duplicate','manual','admin')"),/déjà/);
 await assert.rejects(()=>query("select ops_enqueue(array[999],'Unknown','manual','admin')"),/inconnue/);
 assert.equal(await scalar('select count(*) from ops_cycles'),1);
});
let active=async()=>one("select * from ops_tasks where status='running'");
let t;
await test('one worker; claim delivered only once; wrong tokens fenced',async()=>{
 await query('select ops_dispatch()');t=await active();
 await query('select ops_dispatch()');assert.equal(await scalar('select count(*) from net.requests'),1);
 assert.ok(await scalar('select ops_claim($1,$2)',[t.id,t.stage_token]));
 assert.equal(await scalar('select ops_claim($1,$2)',[t.id,t.stage_token]),null);
 assert.equal(await scalar('select ops_checkpoint($1,gen_random_uuid())',[t.id]),false);
 assert.equal(await scalar('select ops_checkpoint($1,$2)',[t.id,t.stage_token]),true);
});
await test('pause retains current stage and prevents dispatch; resume continues immediately',async()=>{
 await query("select ops_control('pause_cycle',$1,'admin')",[cycle]);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);
 assert.equal(await scalar("select count(*) from ops_tasks where status='running'"),0);
 assert.equal(await scalar('select stage from ops_tasks where id=$1',[t.id]),1);
 await query("select ops_control('resume_cycle',$1,'admin')",[cycle]);
 const next=await active();assert.equal(next.id,t.id);assert.equal(next.stage,1);assert.notEqual(next.stage_token,t.stage_token);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);assert.equal((await active()).stage,1);
});
await test('four actual stages succeed then next league starts without a fixed delay',async()=>{
 for(let i=1;i<4;i++){t=await active();assert.equal(t.stage,i);await query('select ops_finish($1,$2)',[t.id,t.stage_token]);}
 assert.equal((await active()).league_id,2);
 const done=await one('select * from ops_tasks where league_id=1');assert.equal(done.stage,4);assert.equal(done.status,'succeeded');
 assert.equal(await scalar('select samples from ops_duration_overview where league_id=1'),1);
});
await test('stop active worker revokes checkpoints; cancelled work never succeeds',async()=>{
 t=await active();await query("select ops_control('cancel_task',$1,'admin')",[t.id]);
 assert.equal(await scalar('select ops_checkpoint($1,$2)',[t.id,t.stage_token]),false);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);
 assert.equal(await scalar('select status from ops_tasks where id=$1',[t.id]),'cancelled');
});
await test('lease expiry fails visibly; stale completion ignored; next work proceeds',async()=>{
 await query("select ops_enqueue(array[1,2],'Timeout','manual','admin')");await query('select ops_dispatch()');t=await active();
 await query("update ops_tasks set lease_until=now()-interval '1 second' where id=$1",[t.id]);
 await query('select ops_dispatch()');assert.equal((await active()).league_id,2);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);
 assert.equal(await scalar('select status from ops_tasks where id=$1',[t.id]),'failed');
 assert.equal(await scalar("select count(*) from ops_events where kind='timeout'"),1);
 const current=await active();await query("select ops_control('cancel_cycle',$1,'admin')",[current.cycle_id]);await query('select ops_finish($1,$2)',[current.id,current.stage_token]);
});
await test('scheduler handles once-per-day, disabled leagues and weekly enrichment',async()=>{
 await query("update ops_competitions set enabled=false,enrichment_enabled=false");
 await query("select ops_save_competition(1,'Championnat A',true,'00:00','admin',true,extract(dow from now() at time zone 'Europe/Paris')::integer,'00:00')");
 await query("update ops_competitions set enrichment_timezone='Europe/Paris' where league_id=1");
 await query("select ops_configure('https://test.invalid','test-secret',true,'admin')");
 assert.equal(await scalar('select active from cron.job where jobid=1'),false);
 assert.equal(await scalar('select active from cron.job where jobid=2'),true);
 await query('select ops_tick()');const daily=await active();assert.equal(daily.job_kind,'daily');
 await query('select ops_tick()');assert.equal(await scalar("select count(*) from ops_cycles where source='scheduled'"),1);
 for(let i=0;i<4;i++){const current=await active();await query('select ops_finish($1,$2)',[current.id,current.stage_token]);}
 await query('select ops_tick()');const weekly=await active();assert.equal(weekly.job_kind,'enrichment');
 await query("select ops_control('cancel_cycle',$1,'admin')",[weekly.cycle_id]);await query('select ops_finish($1,$2)',[weekly.id,weekly.stage_token]);
 await query('select ops_tick()');assert.equal(await scalar("select count(*) from ops_cycles where source='scheduled'"),2);
});
await test('whole-cycle cancellation cancels waiting leagues and survives dispatch outages',async()=>{
 const id=await scalar("select ops_enqueue(array[2,3],'Stop','manual','admin')");await query('select ops_dispatch()');t=await active();
 await query("select ops_control('cancel_cycle',$1,'admin')",[id]);
 assert.equal(await scalar("select count(*) from ops_tasks where cycle_id=$1 and status='cancelled'",[id]),1);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);
 const next=await scalar("select ops_enqueue(array[2,3],'Outage','manual','admin')");await query('select ops_dispatch()');t=await active();
 await pg.exec(`create or replace function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer) returns bigint language plpgsql as $$ begin raise exception 'network unavailable'; end $$;`);
 await query('select ops_finish($1,$2)',[t.id,t.stage_token]);
 assert.equal(await scalar('select stage from ops_tasks where id=$1',[t.id]),1);
 assert.equal(await scalar('select status from ops_tasks where id=$1',[t.id]),'pending');
 assert.ok(await scalar("select count(*) from ops_events where kind='dispatch_error'"));
 assert.equal(await scalar('select pending from ops_cycle_overview where id=$1',[next]),2);
});
await test('browser roles cannot read secrets or invoke control RPCs',async()=>{
 for(const role of ['anon','authenticated']){
  assert.equal(await scalar("select has_table_privilege($1,'public.ops_configuration','SELECT')",[role]),false);
  assert.equal(await scalar("select has_table_privilege($1,'public.ops_cycle_overview','SELECT')",[role]),false);
  assert.equal(await scalar("select has_function_privilege($1,'public.ops_control(text,uuid,text)','EXECUTE')",[role]),false);
 }
});
console.log(`${passed} PostgreSQL integration scenarios passed.`);
} catch(e) {console.error(e.message,e.where??'',e.internalQuery??'');process.exitCode=1;} finally {await pg.close()}
