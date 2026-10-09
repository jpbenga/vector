"""Read only the account incident requested by the owner; no API model calls."""
import datetime
import json
import os
import re
import time
import urllib.parse

from deploy_generator_remote import PROJECT, request


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REF") != "refs/heads/codex/multisport-hockey" or os.environ.get("GITHUB_REPOSITORY") != "jpbenga/vector":
        raise ValueError("Incident diagnostics run on the demo branch only.")
    token = os.environ["SUPABASE_ACCESS_TOKEN"]
    base = f"https://api.supabase.com/v1/projects/{PROJECT}"
    # Both addresses come directly from the owner's conversation (including the
    # earlier account screenshot). Do not broaden this to other users.
    account = "lower(email) in ('jpaulbengiar@gmail.com','jpaulbenga@gmail.com')"
    def query(sql, read_only=True):
        return request(base + "/database/query", token, {"query": sql, "read_only": read_only})
    rows = query(f"""select c.id, c.revision, c.updated_at,
        c.state->'intent' as intent, c.state#>'{{context,budget}}' as budget,
        c.state->'messages' as messages, c.state->'catalog'->'matchCount' as match_count
        from public.lector_generator_conversations c join auth.users u on u.id=c.user_id
        where {account} and c.updated_at >= now() - interval '12 hours'
        order by c.updated_at desc limit 6""")
    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=12)
    def reported_pairs(messages):
        pairs = []
        for index, message in enumerate(messages or []):
            text = str(message.get("text", ""))
            if message.get("role") != "user" or not re.search(r"radar|\b(deux|2|viking|brann|lyon|lens)\b", text, re.I):
                continue
            try:
                if datetime.datetime.fromisoformat(message.get("at", "").replace("Z", "+00:00")) < cutoff:
                    continue
            except ValueError:
                continue
            following = messages[index+1] if index+1 < len(messages) else {}
            pairs.append({"at": message.get("at"), "request": text,
                "reply": following.get("text") if following.get("role") == "assistant" else None,
                "analysis": following.get("analysis") if following.get("role") == "assistant" else None})
        return pairs[-4:]
    print(json.dumps({"incident_conversations": [{"revision": r["revision"], "updated_at": r["updated_at"], "intent": r["intent"], "budget": r["budget"], "message_count": len(r.get("messages") or []), "match_count": r["match_count"], "reported_pairs": reported_pairs(r.get("messages"))} for r in rows]}, ensure_ascii=False))
    turns = query(f"""select t.conversation_id, t.started_at, t.status, t.usage,
        t.response->'intent' as intent, t.response->'context' as context,
        t.response->'catalog' as catalog, t.response->'messages' as messages from public.lector_generator_turns t
        join auth.users u on u.id=t.user_id where {account}
        and t.started_at >= now() - interval '12 hours'
        order by t.started_at desc limit 12""")
    for turn in turns:
        messages = turn.pop("messages", []) or []
        pairs = reported_pairs(messages)
        if not pairs:
            continue
        turn.pop("conversation_id", None)
        turn["reported_pairs"] = pairs[-1:]
        # API summaries are not needed to diagnose the scope/date/tool steps.
        if isinstance(turn.get("usage"), dict):
            turn["usage"].pop("summary", None)
        print(json.dumps({"incident_turn": turn}, ensure_ascii=False))
    selections = [selection for turn in turns for pair in turn.get("reported_pairs", [])
                  for selection in (pair.get("analysis") or {}).get("selections", [])]
    snapshots = {}
    for selection in selections:
        candidate = selection.get("candidate", {})
        source = str(candidate.get("snapshotId", ""))
        fixture = str(candidate.get("matchId", "")).removeprefix("api-fixture-")
        if not re.fullmatch(r"[0-9a-zA-Z-]+", source) or not fixture.isdigit():
            continue
        snapshots.setdefault(source, set()).add(fixture)
    for source, fixtures in snapshots.items():
        fixture_ids = ",".join("'" + fixture + "'" for fixture in sorted(fixtures))
        original = query(f"""with document as materialized (
            select id,captured_at,payload||'{{}}'::jsonb payload
            from public.match_feed_analysis_snapshots where id::text='{source}'
        ), selected as materialized (
            select *, coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(payload#>'{{raw,fixtures}}','[]')) f
            where f#>>'{{fixture,id}}' in ({fixture_ids})), '[]') fixtures from document
        ), teams as materialized (
            select *, array(select distinct team from jsonb_array_elements(fixtures) f
            cross join lateral (values(f#>>'{{teams,home,id}}'),(f#>>'{{teams,away,id}}')) t(team)) ids from selected
        ) select id,captured_at,fixtures,
            coalesce((select jsonb_agg(f) from jsonb_array_elements(coalesce(payload#>'{{computed,fixtures}}','[]')) f
            where f->>'fixture_id' in ({fixture_ids})), '[]') readings,
            coalesce((select jsonb_agg(jsonb_build_object('team',r->'team','league',r->'league','matches',
            (select coalesce(jsonb_agg(jsonb_build_object('fixture',m->'fixture','date',m->'date','result',m->'result','venue',m->'venue','opponent',m->'opponent','goals',m->'goals')), '[]')
            from jsonb_array_elements(coalesce(r->'matches','[]')) m))) from jsonb_array_elements(coalesce(payload#>'{{raw,recent_league_matches}}','[]')) r
            where r#>>'{{team,id}}'=any(ids)), '[]') team_histories,
            coalesce((select jsonb_agg(jsonb_build_object('player',r->'player','team',r->'team','activity',(select coalesce(jsonb_agg(jsonb_build_object('played_at',a->'played_at','goals',a->'goals','assists',a->'assists')), '[]') from jsonb_array_elements(coalesce(r->'activity','[]')) a)))
            from jsonb_array_elements(coalesce(payload#>'{{raw,player_form_radar}}','[]')) r
            where r#>>'{{team,id}}'=any(ids)), '[]') player_histories from teams""")
        print(json.dumps({"selected_immutable_snapshot": original}, ensure_ascii=False))
    dates = sorted({str(r.get("intent", {}).get("date")) for r in rows if isinstance(r.get("intent"), dict) and r["intent"].get("date")})
    if not dates:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        dates = [(today + datetime.timedelta(days=(5-today.weekday()) % 7)).isoformat()]
    for date in dates[-2:]:
        datetime.date.fromisoformat(date)
        start = time.monotonic()
        try:
            sizes = query(f"""with s as materialized (select public.lector_generator_sources('{date}'::date,'Europe/Paris') v)
                select jsonb_array_length(v) source_count, octet_length(v::text) payload_bytes,
                (select coalesce(sum(jsonb_array_length(x#>'{{payload,raw,fixtures}}')),0) from jsonb_array_elements(v) x where x->>'sport'='football') football_matches
                from s""", False)
            print(json.dumps({"source_probe": sizes, "date": date, "elapsed_seconds": round(time.monotonic()-start, 3)}))
        except RuntimeError as error:
            print(json.dumps({"source_probe_error": str(error), "elapsed_seconds": round(time.monotonic()-start, 3)}))
    now = datetime.datetime.now(datetime.timezone.utc)
    params = urllib.parse.urlencode({"iso_timestamp_start": (now-datetime.timedelta(hours=3)).isoformat(), "iso_timestamp_end": now.isoformat(), "sql": "select timestamp,source,event_message from logs where event_message like '%lector-generator%' order by timestamp desc limit 15"})
    try:
        logs = request(base + "/analytics/endpoints/logs?" + params, token)
        # Only endpoint status lines; never emit metadata, request headers or tokens.
        safe = [{"timestamp": row.get("timestamp"), "source": row.get("source")} for row in logs.get("result", [])]
        print(json.dumps({"generator_invocations": safe}))
    except RuntimeError as error:
        print(json.dumps({"invocations_unavailable": str(error)}))


if __name__ == "__main__":
    main()
