"""Reject stale hockey deliveries using their real calendar collection time."""
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo


def require_current_hockey_publication(payload, now=None):
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError('The publication check requires an explicit timezone')
    if payload.get('sport') != 'hockey' or payload.get('schemaVersion') != 1:
        raise ValueError('Invalid hockey publication')
    for field in ('capturedAt', 'baseCapturedAt'):
        value = payload.get(field, payload.get('capturedAt'))
        try:
            at = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
            if at.tzinfo is None:
                raise ValueError()
        except (TypeError, ValueError):
            raise ValueError(f'Invalid hockey publication timestamp: {field}') from None
        age = now - at
        if age < -timedelta(seconds=30):
            raise ValueError(f'Hockey publication timestamp is in the future: {field}')
        if age > timedelta(hours=36):
            raise ValueError(
                f'Publication hockey périmée ({field}: {value}). '
                'Actualiser la collecte puis publier avant de livrer la démo.'
            )
    today = now.astimezone(ZoneInfo('Europe/Paris')).date().isoformat()
    if not payload.get('windowStart', '') <= today <= payload.get('windowEnd', ''):
        raise ValueError('Hockey publication does not cover the current Paris day')
