"""Owner-scoped, read-only conversation incident audit. No paid model calls."""
import datetime
import json
import os
import urllib.parse

from deploy_generator_remote import PROJECT, request


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REF") != "refs/heads/codex/multisport-hockey" or os.environ.get("GITHUB_REPOSITORY") != "jpbenga/vector":
        raise ValueError("Incident diagnostics run on the demo branch only.")
    now = datetime.datetime.now(datetime.timezone.utc)
    value = os.environ.get("GENERATOR_DIAGNOSTIC_SINCE", "").strip()
    since = datetime.datetime.fromisoformat(value.replace("Z", "+00:00")) if value else now - datetime.timedelta(hours=1)
    if since.tzinfo is None or not now - datetime.timedelta(days=2) <= since <= now:
        raise ValueError("Diagnostic start must include a timezone and fall within the past two days.")
    since = since.astimezone(datetime.timezone.utc)
    # Formatting after datetime parsing prevents SQL interpolation of raw input.
    cutoff = since.isoformat()
    token = os.environ["SUPABASE_ACCESS_TOKEN"]
    base = f"https://api.supabase.com/v1/projects/{PROJECT}"
    account = "lower(email) in ('jpaulbengiar@gmail.com','jpaulbenga@gmail.com')"

    def query(sql):
        return request(base + "/database/query", token, {"query": sql, "read_only": True})

    def messages_since(messages):
        result = []
        for message in messages or []:
            try:
                at = datetime.datetime.fromisoformat(message.get("at", "").replace("Z", "+00:00"))
                if at < since:
                    continue
            except (TypeError, ValueError):
                continue
            result.append(message)
        return result[-30:]

    rows = query(f"""select c.id,c.revision,c.updated_at,
        c.state->'intent' as intent,c.state->'context' as context,
        c.state->'messages' as messages,c.state->'conversation' as memory,
        c.state->'catalog' as catalog
        from public.lector_generator_conversations c join auth.users u on u.id=c.user_id
        where {account} and c.updated_at >= '{cutoff}'::timestamptz
        order by c.updated_at desc limit 6""")
    print(json.dumps({"incident_window": {"since": cutoff, "until": now.isoformat()},
        "incident_conversations": [{**row, "messages": messages_since(row.get("messages"))} for row in rows]}, ensure_ascii=False))
    turns = query(f"""select t.request_id,t.conversation_id,t.started_at,t.status,t.usage,
        t.response->'intent' as intent,t.response->'context' as context,
        t.response->'catalog' as catalog,t.response->'messages' as messages,
        t.response->'conversation' as memory
        from public.lector_generator_turns t join auth.users u on u.id=t.user_id
        where {account} and t.started_at >= '{cutoff}'::timestamptz
        order by t.started_at asc limit 30""")
    for turn in turns:
        turn["messages"] = messages_since(turn.get("messages"))
        print(json.dumps({"incident_turn": turn}, ensure_ascii=False))

    # Public source dimensions and fixture boundaries at the incident start.
    # No source documents or player profiles are emitted into workflow logs.
    publication = query(f"""with head as (
        select captured_at,overview from public.sport_feed_snapshots
        where sport='hockey' and captured_at <= '{cutoff}'::timestamptz
        order by captured_at desc limit 1
      ) select captured_at,
        length(coalesce(overview#>'{{playerRadar,profiles}}','[]')::text) as player_profile_characters,
        jsonb_array_length(coalesce(overview#>'{{playerRadar,profiles}}','[]')) as player_profiles,
        jsonb_array_length(overview->'items') as total_matches,
        (select coalesce(jsonb_agg(jsonb_build_object(
          'matchId',f->>'id','home',f#>>'{{home,name}}','away',f#>>'{{away,name}}',
          'startsAt',f->>'startsAt','parisDay',((f->>'startsAt')::timestamptz at time zone 'Europe/Paris')::date,
          'readings',jsonb_array_length(coalesce(f->'readings','[]'))
        ) order by f->>'startsAt'),'[]') from jsonb_array_elements(overview->'items') f
          where f->>'competitionId'='57'
            and (f->>'startsAt')::timestamptz >= '{cutoff}'::timestamptz
            and (f->>'startsAt')::timestamptz < '{cutoff}'::timestamptz + interval '14 hours'
        ) as nhl_night_matches from head""")
    print(json.dumps({"incident_publication_dimensions": publication}, ensure_ascii=False))

    # Retained application failure events only; no headers, credentials, request
    # bodies or unrelated user messages. The account-scoped turn IDs above
    # establish which events are pertinent to the incident.
    sql = "select timestamp,event_message from function_edge_logs where event_message like '%generator_failure%' order by timestamp desc limit 30"
    params = urllib.parse.urlencode({"iso_timestamp_start": cutoff, "iso_timestamp_end": now.isoformat(), "sql": sql})
    try:
        logs = request(base + "/analytics/endpoints/logs?" + params, token)
        safe = []
        for row in logs.get("result", []):
            try:
                event = json.loads(row.get("event_message", ""))
            except (ValueError, TypeError):
                continue
            if event.get("event") == "generator_failure":
                safe.append({"timestamp": row.get("timestamp"), **{k: event.get(k) for k in ("event", "stage", "elapsed_ms", "timeout")}})
        print(json.dumps({"incident_failure_events": safe}))
    except RuntimeError as error:
        print(json.dumps({"incident_invocations_unavailable": str(error)}))


if __name__ == "__main__":
    main()
