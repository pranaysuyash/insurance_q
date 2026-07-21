-- Give canonical analytics ingestion a stable replay key. The old uniqueness
-- key included received_at, which changes on every retry and therefore could
-- not provide idempotency.

alter table public.analytics_events
  add column if not exists event_id text;

-- Preserve historical rows while making the new contract non-null. Including
-- the existing row id keeps old duplicate events distinct; new API rows use a
-- deterministic SHA-256 identity before insertion.
update public.analytics_events
   set event_id = md5(id::text || ':' || event_name || ':' || user_uid || ':' || timestamp::text)
 where event_id is null;

alter table public.analytics_events
  alter column event_id set not null;

-- The historical key is not a valid identity: it can reject distinct events
-- emitted in one batch and cannot deduplicate retries. Remove it after the
-- stable key has been backfilled.
alter table public.analytics_events
  drop constraint if exists analytics_events_received_at_event_name_user_uid_key;

create unique index if not exists analytics_events_event_id_key
  on public.analytics_events (event_id);

comment on column public.analytics_events.event_id is
  'Stable server-derived event identity used for replay-safe ingestion.';
