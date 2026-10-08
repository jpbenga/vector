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
        where {account} and c.updated_at >= now() - interval '6 hours'
        order by c.updated_at desc limit 3""")
    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=6)
    def reported_pairs(messages):
        pairs = []
        for index, message in enumerate(messages or []):
            text = str(message.get("text", ""))
            if message.get("role") != "user" or not re.search(r"\b(top|cinq|5|vendredi)\b", text, re.I):
                continue
            try:
                if datetime.datetime.fromisoformat(message.get("at", "").replace("Z", "+00:00")) < cutoff:
                    continue
            except ValueError:
                continue
            following = messages[index+1] if index+1 < len(messages) else {}
            pairs.append({"at": message.get("at"), "request": text,
                "reply": following.get("text") if following.get("role") == "assistant" else None})
        return pairs[-4:]
    print(json.dumps({"incident_conversations": [{"revision": r["revision"], "updated_at": r["updated_at"], "intent": r["intent"], "budget": r["budget"], "message_count": len(r.get("messages") or []), "match_count": r["match_count"], "reported_pairs": reported_pairs(r.get("messages"))} for r in rows]}, ensure_ascii=False))
    turns = query(f"""select t.conversation_id, t.started_at, t.status, t.usage,
        t.response->'intent' as intent from public.lector_generator_turns t
        join auth.users u on u.id=t.user_id where {account}
        and t.started_at >= now() - interval '6 hours'
        order by t.started_at desc limit 8""")
    print(json.dumps({"incident_turns": [{k: v for k, v in t.items() if k != "conversation_id"} for t in turns]}, ensure_ascii=False))
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
