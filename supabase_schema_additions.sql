-- إضافات مقترحة لمخطط HANI SOFTWARE V2.
-- شغّلها بعد مراجعة المخطط الأساسي في مشروع Supabase تجريبي.

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open','pending','closed')),
  admin_reply text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reseller_price_rules (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services(id) on delete cascade,
  role text not null check (role in ('customer','dealer','distributor')),
  price numeric(14,2) not null check (price >= 0),
  currency text not null check (currency in ('USD','SDG')),
  active boolean not null default true,
  unique(service_id, role)
);

create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  instructions text,
  active boolean not null default false,
  sort_order int not null default 0
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
alter table public.reseller_price_rules enable row level security;
alter table public.payment_methods enable row level security;
alter table public.announcements enable row level security;

create policy "ticket owner or admin read" on public.support_tickets
for select to authenticated using (user_id = auth.uid() or public.current_user_role() = 'admin');
create policy "ticket owner create" on public.support_tickets
for insert to authenticated with check (user_id = auth.uid());
create policy "admin update tickets" on public.support_tickets
for update to authenticated using (public.current_user_role() = 'admin') with check (public.current_user_role() = 'admin');

create policy "active payment methods readable" on public.payment_methods
for select to anon, authenticated using (active or public.current_user_role() = 'admin');
create policy "admin manage payment methods" on public.payment_methods
for all to authenticated using (public.current_user_role() = 'admin') with check (public.current_user_role() = 'admin');

create policy "active announcements readable" on public.announcements
for select to anon, authenticated using (active or public.current_user_role() = 'admin');
create policy "admin manage announcements" on public.announcements
for all to authenticated using (public.current_user_role() = 'admin') with check (public.current_user_role() = 'admin');

create policy "reseller prices visible by role" on public.reseller_price_rules
for select to authenticated using (
  active and role = public.current_user_role()
  or public.current_user_role() = 'admin'
);
create policy "admin manage reseller prices" on public.reseller_price_rules
for all to authenticated using (public.current_user_role() = 'admin') with check (public.current_user_role() = 'admin');

grant select on public.payment_methods, public.announcements to anon, authenticated;
grant select on public.reseller_price_rules to authenticated;
grant select, insert on public.support_tickets to authenticated;
-- لا تمنح صلاحيات تعديل تذاكر الدعم أو الأسعار من المتصفح للعميل.
-- MFA يتم تفعيله عبر Supabase Auth، ولا تخزن أسرار TOTP في جداول عامة.
