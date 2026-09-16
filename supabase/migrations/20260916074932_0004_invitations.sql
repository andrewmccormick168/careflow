-- Applied to careflow (alsgbnbzzdsfixgsaiak) 2026-09-16.
-- See docs/architecture.md §9 for the design this implements.

create table public.invitations (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references public.companies(id),
  email            text not null,
  email_normalized text generated always as (lower(trim(email))) stored,
  role_id          uuid not null references public.roles(id),
  token_hash       text not null,
  status           text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  expires_at       timestamptz not null,
  invited_by       uuid not null references auth.users(id),
  accepted_at      timestamptz,
  created_at       timestamptz not null default now()
);
-- Only one pending invitation per (company, normalised email) at a time.
create unique index invitations_pending_unique
  on public.invitations (company_id, email_normalized)
  where status = 'pending';

revoke insert, update, delete on public.invitations from public, anon, authenticated;
alter table public.invitations enable row level security;

create policy invitations_select on public.invitations for select
using ( public.has_company_capability(company_id, 'settings.manage') or public.is_platform_admin() );
-- No insert/update/delete policies: invitations are created and accepted
-- exclusively via the two functions below.

create or replace function public.create_invitation(
  target_company_id uuid,
  p_email            text,
  p_role_key         text
)
returns table (invitation_id uuid, raw_token text)
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_role_id       uuid;
  v_raw_token     text;
  v_token_hash    text;
  v_invitation_id uuid;
begin
  if not public.has_company_capability(target_company_id, 'settings.manage') then
    raise exception 'not authorised';
  end if;

  select id into v_role_id from public.roles where key = p_role_key;
  if v_role_id is null then
    raise exception 'invalid role key: %', p_role_key;
  end if;

  v_raw_token  := encode(gen_random_bytes(32), 'hex');
  v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');

  insert into public.invitations (company_id, email, role_id, token_hash, expires_at, invited_by)
  values (target_company_id, p_email, v_role_id, v_token_hash, now() + interval '7 days', auth.uid())
  returning id into v_invitation_id;

  perform public.insert_audit_event(
    target_company_id, auth.uid(), 'invitation_created', 'invitations', v_invitation_id,
    null, jsonb_build_object('email', lower(trim(p_email)), 'role', p_role_key), null, null
  );

  -- Raw token returned once, here, to the authorised caller only.
  -- Never logged; the table stores only its hash.
  return query select v_invitation_id, v_raw_token;
end;
$$;
revoke execute on function public.create_invitation(uuid, text, text) from public;
grant execute on function public.create_invitation(uuid, text, text) to authenticated;

create or replace function public.accept_invitation(p_token text)
returns table (company_id uuid, role_key text)
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_token_hash  text;
  v_inv         record;
  v_auth_email  text;
  v_verified    boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select email, (email_confirmed_at is not null)
    into v_auth_email, v_verified
  from auth.users where id = auth.uid();

  if not coalesce(v_verified, false) then
    raise exception 'email not verified';
  end if;

  v_token_hash := encode(digest(p_token, 'sha256'), 'hex');

  select * into v_inv from public.invitations
  where token_hash = v_token_hash
  for update;

  if v_inv is null then
    raise exception 'invalid invitation';
  end if;

  if lower(trim(v_auth_email)) is distinct from v_inv.email_normalized then
    raise exception 'authenticated email does not match invitation';
  end if;

  if v_inv.status <> 'pending' then
    raise exception 'invitation is not pending';
  end if;

  if v_inv.expires_at <= now() then
    update public.invitations set status = 'expired' where id = v_inv.id;
    raise exception 'invitation has expired';
  end if;

  if not exists (select 1 from public.companies c where c.id = v_inv.company_id and c.status = 'active') then
    raise exception 'target company is not active';
  end if;

  if exists (
    select 1 from public.company_memberships cm
    where cm.user_id = auth.uid() and cm.company_id = v_inv.company_id and cm.status = 'active'
  ) then
    raise exception 'an active membership already exists for this company';
  end if;

  insert into public.company_memberships (company_id, user_id, role_id, invited_by)
  values (v_inv.company_id, auth.uid(), v_inv.role_id, v_inv.invited_by);

  update public.invitations set status = 'accepted', accepted_at = now() where id = v_inv.id;

  perform public.insert_audit_event(
    v_inv.company_id, auth.uid(), 'invitation_accepted', 'invitations', v_inv.id,
    null, null, null, null
  );

  return query select v_inv.company_id, (select key from public.roles where id = v_inv.role_id);
end;
$$;
revoke execute on function public.accept_invitation(text) from public;
grant execute on function public.accept_invitation(text) to authenticated;
