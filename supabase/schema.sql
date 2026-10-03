-- She Tribe: database schema for Supabase (free tier). WhatsApp sign-in + UPI (Google Pay) QR payments.
-- Paste this whole file into Supabase > SQL Editor > New query > Run. Run it once on a fresh project.

-- ================================================================ tables

create table public.phone_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  phone text not null unique,                  -- verified WhatsApp number, like +919876543210
  created_at timestamptz not null default now()
);

-- One-time codes. Only the server (service role) touches this table.
create table public.otp_codes (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  consumed boolean not null default false,
  created_at timestamptz not null default now()
);
create index otp_codes_phone_created on public.otp_codes (phone, created_at desc);

create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  business_name text not null default '',
  stage text not null default 'idea' check (stage in ('idea', 'started', 'growing')),
  role_tag text not null default 'Aspiring Entrepreneur',
  looking_for text[] not null default '{}',
  about text not null default '',
  instagram text not null default '',
  directory_opt_in boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  description text not null default '',
  highlights text[] not null default '{}',
  starts_at timestamptz,
  venue text not null default '',
  capacity int,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.ticket_tiers (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  name text not null,
  price_inr int not null check (price_inr >= 0),
  member_price_inr int check (member_price_inr >= 0),
  perks text[] not null default '{}',
  seats int
);

create table public.registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  tier_id uuid not null references public.ticket_tiers (id),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'paid', 'cancelled')),
  amount_inr int not null default 0,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create table public.plans (
  code text primary key,
  name text not null,
  tagline text not null default '',
  price_inr int not null,
  interval text not null default 'year' check (interval in ('year', 'month')),
  perks text[] not null default '{}',
  sort int not null default 0
);

create table public.memberships (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan_code text not null references public.plans (code),
  status text not null default 'active' check (status in ('active', 'cancelled', 'expired')),
  current_end timestamptz,
  updated_at timestamptz not null default now()
);

-- Your UPI details. Edit this one row in the Table Editor.
create table public.payment_settings (
  id int primary key default 1 check (id = 1),
  upi_id text not null,
  payee_name text not null default 'She Tribe',
  support_whatsapp text not null default ''
);

-- Every payment attempt. Kept for your records even if the member deletes their account.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  kind text not null check (kind in ('ticket', 'membership')),
  registration_id uuid references public.registrations (id) on delete set null,
  plan_code text references public.plans (code),
  label text not null,
  amount_inr int not null check (amount_inr >= 0),
  reference text not null unique,              -- short code the member puts in the UPI note
  status text not null default 'awaiting'
    check (status in ('awaiting', 'submitted', 'approved', 'rejected', 'cancelled')),
  utr text,                                    -- 12-digit UPI transaction ID entered by the member
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  decided_at timestamptz,
  decided_by uuid
);
-- the same bank transaction can only ever be used for one payment
create unique index payments_utr_once on public.payments (utr)
  where utr is not null and status in ('submitted', 'approved');

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  author_name text not null default 'Member',
  kind text not null check (kind in ('need', 'offer')),
  text text not null check (char_length(text) between 1 and 200),
  created_at timestamptz not null default now()
);

create table public.commitments (
  user_id uuid primary key references auth.users (id) on delete cascade,
  picks text[] not null default '{}',
  goal text not null default ''
);

-- ================================================================ helper functions

create or replace function public.is_admin(uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where a.user_id = uid);
$$;

-- True for an active member, or a cancelled member whose paid period has not ended.
create or replace function public.is_member(uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = uid
      and m.current_end is not null
      and m.current_end > now()
      and m.status in ('active', 'cancelled')
  );
$$;

create or replace function public.gen_reference()
returns text language plpgsql volatile set search_path = public as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  ref text;
  i int;
begin
  loop
    ref := 'ST-';
    for i in 1..6 loop
      ref := ref || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.payments p where p.reference = ref);
  end loop;
  return ref;
end;
$$;

-- ================================================================ payment functions
-- The app can only call these. Prices and approvals are decided here, never in the app.

create or replace function public.request_ticket_payment(p_event uuid, p_tier uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t public.ticket_tiers;
  e public.events;
  reg public.registrations;
  pay public.payments;
  price int;
  paid_count int;
begin
  if uid is null then raise exception 'Please sign in again.'; end if;

  select * into e from public.events where id = p_event and is_published;
  select * into t from public.ticket_tiers where id = p_tier and event_id = p_event;
  if e.id is null or t.id is null then raise exception 'This ticket is not available.'; end if;

  select * into reg from public.registrations where event_id = p_event and user_id = uid;
  if reg.id is not null and reg.status = 'paid' then
    raise exception 'You are already registered for this event.';
  end if;

  -- A payment already waiting for review is returned unchanged.
  if reg.id is not null then
    select * into pay from public.payments
      where registration_id = reg.id and status = 'submitted' limit 1;
    if pay.id is not null then return to_jsonb(pay); end if;
  end if;

  if t.seats is not null then
    select count(*) into paid_count from public.registrations
      where tier_id = t.id and status = 'paid';
    if paid_count >= t.seats then raise exception 'Sorry, this ticket type is sold out.'; end if;
  end if;

  price := case when public.is_member(uid) and t.member_price_inr is not null
                then t.member_price_inr else t.price_inr end;

  -- Reuse an open request for the same ticket and price, otherwise cancel it and start fresh.
  if reg.id is not null then
    select * into pay from public.payments
      where registration_id = reg.id and status = 'awaiting'
        and amount_inr = price and reg.tier_id = p_tier
      order by created_at desc limit 1;
    if pay.id is not null then return to_jsonb(pay); end if;
    update public.payments set status = 'cancelled'
      where registration_id = reg.id and status = 'awaiting';
  end if;

  insert into public.registrations (event_id, tier_id, user_id, status, amount_inr)
  values (p_event, p_tier, uid, case when price = 0 then 'paid' else 'pending' end, price)
  on conflict (event_id, user_id) do update
    set tier_id = excluded.tier_id, status = excluded.status, amount_inr = excluded.amount_inr
  returning * into reg;

  insert into public.payments (user_id, kind, registration_id, label, amount_inr, reference, status, decided_at)
  values (uid, 'ticket', reg.id, e.title || ' - ' || t.name, price, public.gen_reference(),
          case when price = 0 then 'approved' else 'awaiting' end,
          case when price = 0 then now() else null end)
  returning * into pay;

  return to_jsonb(pay);
end;
$$;

create or replace function public.request_membership_payment(p_plan text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  pl public.plans;
  pay public.payments;
begin
  if uid is null then raise exception 'Please sign in again.'; end if;
  select * into pl from public.plans where code = p_plan;
  if pl.code is null then raise exception 'This membership is not available.'; end if;

  select * into pay from public.payments
    where user_id = uid and kind = 'membership' and plan_code = p_plan
      and status = 'submitted' limit 1;
  if pay.id is not null then return to_jsonb(pay); end if;

  select * into pay from public.payments
    where user_id = uid and kind = 'membership' and plan_code = p_plan
      and status = 'awaiting' and amount_inr = pl.price_inr
    order by created_at desc limit 1;
  if pay.id is not null then return to_jsonb(pay); end if;

  update public.payments set status = 'cancelled'
    where user_id = uid and kind = 'membership' and status = 'awaiting';

  insert into public.payments (user_id, kind, plan_code, label, amount_inr, reference)
  values (uid, 'membership', pl.code, pl.name, pl.price_inr, public.gen_reference())
  returning * into pay;

  return to_jsonb(pay);
end;
$$;

create or replace function public.submit_payment(p_payment uuid, p_utr text)
returns void language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_utr text := regexp_replace(coalesce(p_utr, ''), '\s', '', 'g');
  n int;
begin
  if uid is null then raise exception 'Please sign in again.'; end if;
  if v_utr !~ '^[0-9]{12}$' then
    raise exception 'Enter the 12-digit UPI transaction ID shown in your payment app.';
  end if;

  update public.payments
     set status = 'submitted', utr = v_utr, submitted_at = now()
   where id = p_payment and user_id = uid and status = 'awaiting';
  get diagnostics n = row_count;
  if n = 0 then raise exception 'This payment can no longer be updated.'; end if;
exception
  when unique_violation then
    raise exception 'That transaction ID has already been used.';
end;
$$;

create or replace function public.list_pending_payments()
returns table (
  id uuid, reference text, label text, kind text, amount_inr int, utr text,
  payer_name text, payer_phone text, submitted_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin(auth.uid()) then raise exception 'Not allowed.'; end if;
  return query
    select p.id, p.reference, p.label, p.kind, p.amount_inr, p.utr,
           coalesce(pr.full_name, ''), coalesce(pa.phone, ''), p.submitted_at
      from public.payments p
      left join public.profiles pr on pr.id = p.user_id
      left join public.phone_accounts pa on pa.user_id = p.user_id
     where p.status = 'submitted'
     order by p.submitted_at;
end;
$$;

create or replace function public.review_payment(p_payment uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  pay public.payments;
  pl public.plans;
  cur timestamptz;
  base timestamptz;
begin
  if not public.is_admin(uid) then raise exception 'Not allowed.'; end if;

  select * into pay from public.payments where id = p_payment for update;
  if pay.id is null or pay.status <> 'submitted' then
    raise exception 'This payment is not waiting for review.';
  end if;

  if not p_approve then
    update public.payments set status = 'rejected', decided_at = now(), decided_by = uid
     where id = pay.id;
    return;
  end if;

  update public.payments set status = 'approved', decided_at = now(), decided_by = uid
   where id = pay.id;

  if pay.kind = 'ticket' then
    update public.registrations set status = 'paid' where id = pay.registration_id;
  elsif pay.kind = 'membership' and pay.user_id is not null then
    select * into pl from public.plans where code = pay.plan_code;
    select m.current_end into cur from public.memberships m where m.user_id = pay.user_id;
    -- Renewing early adds time on top of what they already have.
    base := greatest(now(), coalesce(cur, now()));
    insert into public.memberships (user_id, plan_code, status, current_end, updated_at)
    values (pay.user_id, pay.plan_code, 'active',
            base + case when pl.interval = 'month' then interval '1 month' else interval '1 year' end,
            now())
    on conflict (user_id) do update
      set plan_code = excluded.plan_code, status = 'active',
          current_end = excluded.current_end, updated_at = now();
  end if;
end;
$$;

revoke all on function public.request_ticket_payment(uuid, uuid) from public, anon;
revoke all on function public.request_membership_payment(text) from public, anon;
revoke all on function public.submit_payment(uuid, text) from public, anon;
revoke all on function public.list_pending_payments() from public, anon;
revoke all on function public.review_payment(uuid, boolean) from public, anon;
grant execute on function public.request_ticket_payment(uuid, uuid) to authenticated;
grant execute on function public.request_membership_payment(text) to authenticated;
grant execute on function public.submit_payment(uuid, text) to authenticated;
grant execute on function public.list_pending_payments() to authenticated;
grant execute on function public.review_payment(uuid, boolean) to authenticated;

-- ================================================================ security (RLS)

alter table public.phone_accounts enable row level security;
alter table public.otp_codes enable row level security;      -- no policies: server only
alter table public.admins enable row level security;
alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.ticket_tiers enable row level security;
alter table public.registrations enable row level security;
alter table public.plans enable row level security;
alter table public.memberships enable row level security;
alter table public.payment_settings enable row level security;
alter table public.payments enable row level security;
alter table public.posts enable row level security;
alter table public.commitments enable row level security;

create policy "own phone" on public.phone_accounts
  for select to authenticated using (user_id = auth.uid());
create policy "own admin row" on public.admins
  for select to authenticated using (user_id = auth.uid());

create policy "own profile read" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "directory read for members" on public.profiles
  for select to authenticated using (directory_opt_in and public.is_member(auth.uid()));
create policy "own profile insert" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "own profile update" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "published events" on public.events
  for select to authenticated using (is_published);
create policy "tiers of published events" on public.ticket_tiers
  for select to authenticated
  using (exists (select 1 from public.events e where e.id = event_id and e.is_published));

create policy "own registrations" on public.registrations
  for select to authenticated using (user_id = auth.uid());
create policy "plans readable" on public.plans
  for select to authenticated using (true);
create policy "own membership" on public.memberships
  for select to authenticated using (user_id = auth.uid());
create policy "payment settings readable" on public.payment_settings
  for select to authenticated using (true);
create policy "own payments" on public.payments
  for select to authenticated using (user_id = auth.uid());

create policy "posts readable" on public.posts
  for select to authenticated using (true);
create policy "posts insert own" on public.posts
  for insert to authenticated with check (user_id = auth.uid());
create policy "posts delete own" on public.posts
  for delete to authenticated using (user_id = auth.uid());

create policy "own commitment" on public.commitments
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ================================================================ starter data
-- PLACEHOLDERS: change the UPI ID first. Prices are editable in the Table Editor any time.

insert into public.payment_settings (id, upi_id, payee_name)
values (1, 'REPLACE-ME@upi', 'She Tribe');

insert into public.plans (code, name, tagline, price_inr, interval, perks, sort) values
  ('member', 'She Tribe Member', 'Monthly networking and member-only perks', 1499, 'year',
    array['Monthly networking','Member directory','Member-only workshops','Collaboration opportunities','Discounts','Business spotlights'], 1),
  ('circle', 'She Tribe Circle', 'Small-group depth and curated introductions', 3999, 'year',
    array['Everything in Member','Small-group mastermind','Monthly accountability','Expert sessions','Business clinics','Curated introductions'], 2);

with ev as (
  insert into public.events (title, subtitle, description, highlights, venue, capacity, is_published)
  values (
    'SHE TRIBE: The First Circle',
    'For women who dream. Women who build. Women who grow.',
    'An intimate, interactive meet-up for women who are building, growing or dreaming of building something of their own. You do not need a business to belong.',
    array['Who''s in the room?','60-second SHE intro','Idea to Business conversation','The SHE TRIBE Hot Seat','Collaboration Circle','Ask & Offer wall','Networking bingo','Commitment card'],
    'Venue to be announced, Chennai',
    50,
    true
  )
  returning id
)
insert into public.ticket_tiers (event_id, name, price_inr, perks)
select ev.id, t.name, t.price, t.perks from ev,
  (values
    ('Early Bird', 499,  array['Entry to the First Circle','Welcome gift','SHE TRIBE card']),
    ('Regular',    799,  array['Entry to the First Circle','Welcome gift','SHE TRIBE card']),
    ('Premium',    1499, array['Professional headshot','5-minute business spotlight','Priority networking','Business directory listing'])
  ) as t(name, price, perks);

-- Make yourself the admin AFTER you have signed in once with your WhatsApp number:
--   insert into public.admins (user_id)
--   select user_id from public.phone_accounts where phone = '+91XXXXXXXXXX';
