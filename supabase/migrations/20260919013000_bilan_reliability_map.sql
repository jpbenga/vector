-- Pre-computed data for the interactive Bilan reliability map.
-- Readings, scenarios and cautions intentionally remain separate metrics.
create or replace function public.match_reading_bilan_reading_summary(
  p_since timestamptz,
  p_until timestamptz
)
returns table (
  reading_id text,
  reading_label text,
  total bigint,
  confirmed bigint,
  contradicted bigint,
  not_evaluable bigint,
  context_only bigint,
  pending bigint,
  evaluable bigint,
  confirmation_rate numeric,
  home_evaluable bigint,
  home_confirmed bigint,
  home_confirmation_rate numeric,
  away_evaluable bigint,
  away_confirmed bigint,
  away_confirmation_rate numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  with scoped as (
    select *
    from public.match_reading_bilan
    where kickoff_at >= p_since
      and kickoff_at <= p_until
      and announcement_kind = 'reading'
  ),
  grouped as (
    select
      reading_id,
      max(reading_label) as reading_label,
      count(*) as total,
      count(*) filter (where verdict = 'confirmed') as confirmed,
      count(*) filter (where verdict = 'contradicted') as contradicted,
      count(*) filter (where verdict = 'not_evaluable') as not_evaluable,
      count(*) filter (where verdict = 'context_only') as context_only,
      count(*) filter (where verdict is null) as pending,
      count(*) filter (where verdict in ('confirmed', 'contradicted')) as evaluable,
      count(*) filter (
        where subject_side = 'home'
          and verdict in ('confirmed', 'contradicted')
      ) as home_evaluable,
      count(*) filter (
        where subject_side = 'home' and verdict = 'confirmed'
      ) as home_confirmed,
      count(*) filter (
        where subject_side = 'away'
          and verdict in ('confirmed', 'contradicted')
      ) as away_evaluable,
      count(*) filter (
        where subject_side = 'away' and verdict = 'confirmed'
      ) as away_confirmed
    from scoped
    group by reading_id
  )
  select
    reading_id,
    reading_label,
    total,
    confirmed,
    contradicted,
    not_evaluable,
    context_only,
    pending,
    evaluable,
    round(100.0 * confirmed / nullif(evaluable, 0), 1) as confirmation_rate,
    home_evaluable,
    home_confirmed,
    round(100.0 * home_confirmed / nullif(home_evaluable, 0), 1)
      as home_confirmation_rate,
    away_evaluable,
    away_confirmed,
    round(100.0 * away_confirmed / nullif(away_evaluable, 0), 1)
      as away_confirmation_rate
  from grouped
  order by evaluable desc, reading_label;
$$;

grant execute on function public.match_reading_bilan_reading_summary(
  timestamptz,
  timestamptz
) to anon, authenticated;
