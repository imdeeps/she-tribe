create schema if not exists t;
create or replace function t.as_user(u uuid) returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), true);
  set local role authenticated;
end $$;
create or replace function t.as_root() returns void language plpgsql as $$
begin reset role; end $$;
grant usage on schema t to authenticated;
grant execute on all functions in schema t to authenticated;

create or replace function t.expect_error(sql text, needle text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    if position(lower(needle) in lower(sqlerrm)) = 0 then
      raise exception 'FAIL: wrong error for [%]: got "%", wanted "%"', sql, sqlerrm, needle;
    end if;
    return;
  end;
  raise exception 'FAIL: expected an error for [%]', sql;
end $$;

do $$
declare
  admin_id uuid := gen_random_uuid(); alice uuid := gen_random_uuid(); bob uuid := gen_random_uuid();
  carol uuid := gen_random_uuid(); dave uuid := gen_random_uuid(); eve uuid := gen_random_uuid();
  ev uuid; early uuid; regular uuid; premium uuid;
  p1 jsonb; p2 jsonb; p3 jsonb; pid uuid; n int; endt timestamptz; txt text;
  pend record;
begin
  perform t.as_root();
  insert into auth.users(id,email) values (admin_id,'a@x'),(alice,'al@x'),(bob,'b@x'),(carol,'c@x'),(dave,'d@x'),(eve,'e@x');
  insert into phone_accounts(user_id,phone) values (admin_id,'+919000000000'),(alice,'+919000000001'),(bob,'+919000000002'),(carol,'+919000000003'),(dave,'+919000000004'),(eve,'+919000000005');
  insert into admins(user_id) values (admin_id);
  insert into profiles(id,full_name,directory_opt_in) values (admin_id,'Admin',false),(alice,'Alice',true),(bob,'Bob',true),(carol,'Carol',false),(dave,'Dave',false),(eve,'Eve',false);
  select id into ev from events limit 1;
  select id into early from ticket_tiers where name='Early Bird';
  select id into regular from ticket_tiers where name='Regular';
  select id into premium from ticket_tiers where name='Premium';

  -- 1. alice reserves Early Bird: server sets price, reference format
  perform t.as_user(alice);
  p1 := request_ticket_payment(ev, early);
  assert p1->>'status' = 'awaiting', 'status awaiting';
  assert (p1->>'amount_inr')::int = 499, 'price from server is 499';
  assert p1->>'reference' ~ '^ST-[A-HJ-NP-Z2-9]{6}$', 'reference format: ' || (p1->>'reference');
  -- 2. asking again returns the same open payment
  p2 := request_ticket_payment(ev, early);
  assert p2->>'id' = p1->>'id', 'same payment reused';
  -- 3. switching tier cancels the old request and creates a new one at the new price
  p3 := request_ticket_payment(ev, premium);
  assert p3->>'id' <> p1->>'id' and (p3->>'amount_inr')::int = 1499, 'new payment for premium';
  perform t.as_root();
  assert (select status from payments where id = (p1->>'id')::uuid) = 'cancelled', 'old payment cancelled';
  -- go back to early for the rest
  perform t.as_user(alice);
  p1 := request_ticket_payment(ev, early);
  assert (p1->>'amount_inr')::int = 499, 'back to 499';
  pid := (p1->>'id')::uuid;

  -- 4. UTR validation
  perform t.expect_error(format('select submit_payment(%L, %L)', pid, '12345'), '12-digit');
  perform t.expect_error(format('select submit_payment(%L, %L)', pid, 'abcdefghijkl'), '12-digit');
  perform submit_payment(pid, '4 0 1 2 3 4 5 6 7 8 9 0'); -- spaces are stripped
  assert (select utr from payments where id = pid) = '401234567890', 'utr stored without spaces';
  -- cannot submit twice
  perform t.expect_error(format('select submit_payment(%L, %L)', pid, '401234567891'), 'no longer');
  -- while submitted, re-requesting returns the same payment
  p2 := request_ticket_payment(ev, early);
  assert p2->>'id' = pid::text and p2->>'status' = 'submitted', 'submitted payment returned unchanged';

  -- 5. bob cannot reuse alice's transaction ID
  perform t.as_user(bob);
  p2 := request_ticket_payment(ev, early);
  perform t.expect_error(format('select submit_payment(%L, %L)', (p2->>'id')::uuid, '401234567890'), 'already been used');
  -- bob cannot submit alice's payment
  perform t.expect_error(format('select submit_payment(%L, %L)', pid, '555555555555'), 'no longer');

  -- 6. non-admins cannot review or list
  perform t.as_user(alice);
  perform t.expect_error(format('select review_payment(%L, true)', pid), 'not allowed');
  perform t.expect_error('select * from list_pending_payments()', 'not allowed');
  -- clients cannot write payments/registrations/memberships directly
  perform t.expect_error(format('insert into payments(kind,label,amount_inr,reference,status,user_id) values (''ticket'',''x'',0,''ST-HACK00'',''approved'',%L)', alice), 'row-level security');
  perform t.as_user(alice);
  update registrations set status='paid' where user_id = alice;
  get diagnostics n = row_count;
  assert n = 0, 'alice cannot mark her own ticket paid (rows updated: ' || n || ')';
  perform t.expect_error(format('insert into memberships(user_id,plan_code,status,current_end) values (%L,''member'',''active'',now()+interval ''1 year'')', alice), 'row-level security');

  -- 7. admin sees the pending payment with name + phone and approves it
  perform t.as_user(admin_id);
  select * into pend from list_pending_payments() where id = pid;
  assert pend.payer_name = 'Alice' and pend.payer_phone = '+919000000001' and pend.utr = '401234567890', 'admin sees payer details';
  perform review_payment(pid, true);
  perform t.as_user(alice);
  assert (select status from registrations where user_id = alice) = 'paid', 'ticket is paid after approval';
  perform t.expect_error(format('select request_ticket_payment(%L, %L)', ev, early), 'already registered');
  perform t.as_user(admin_id);
  perform t.expect_error(format('select review_payment(%L, true)', pid), 'not waiting');

  -- 8. rejection leaves the ticket unpaid and lets the person try again
  perform t.as_user(bob);
  p2 := request_ticket_payment(ev, early);
  perform submit_payment((p2->>'id')::uuid, '777777777777');
  perform t.as_user(admin_id);
  perform review_payment((p2->>'id')::uuid, false);
  perform t.as_user(bob);
  assert (select status from registrations where user_id = bob) = 'pending', 'rejected stays pending';
  p3 := request_ticket_payment(ev, early);
  assert p3->>'status' = 'awaiting' and p3->>'id' <> p2->>'id', 'fresh request after rejection';
  -- the rejected transaction ID can be used again (it was never accepted)
  perform submit_payment((p3->>'id')::uuid, '777777777777');

  -- 9. membership: pay, approve, check dates, directory access
  perform t.as_user(bob);
  assert (select count(*) from profiles) = 1, 'non-member sees only own profile';
  perform t.as_user(alice);
  p1 := request_membership_payment('member');
  assert (p1->>'amount_inr')::int = 1499, 'member price 1499';
  perform submit_payment((p1->>'id')::uuid, '888888888881');
  perform t.as_user(admin_id);
  perform review_payment((p1->>'id')::uuid, true);
  perform t.as_user(alice);
  select current_end into endt from memberships where user_id = alice;
  assert endt > now() + interval '364 days' and endt < now() + interval '366 days', 'one year membership';
  assert is_member(alice), 'alice is a member';
  assert (select count(*) from profiles) = 2, 'member sees self + opted-in members (bob)';
  assert not exists (select 1 from profiles where full_name = 'Carol'), 'members do not see people who did not opt in';

  -- 10. early renewal adds a year on top
  p1 := request_membership_payment('member');
  perform submit_payment((p1->>'id')::uuid, '888888888882');
  perform t.as_user(admin_id);
  perform review_payment((p1->>'id')::uuid, true);
  perform t.as_user(alice);
  select current_end into endt from memberships where user_id = alice;
  assert endt > now() + interval '729 days', 'renewal extends from current end';

  -- 11. member price applies for members
  perform t.as_root();
  update ticket_tiers set member_price_inr = 399 where id = regular;
  insert into memberships(user_id,plan_code,status,current_end) values (carol,'member','active', now()+interval '1 month');
  perform t.as_user(carol);
  p1 := request_ticket_payment(ev, regular);
  assert (p1->>'amount_inr')::int = 399, 'member price applied: ' || (p1->>'amount_inr');
  perform t.as_user(dave);
  p1 := request_ticket_payment(ev, regular);
  assert (p1->>'amount_inr')::int = 799, 'non-member pays full price';

  -- 12. cancelled member keeps access until the paid period ends
  perform t.as_root();
  update memberships set status='cancelled' where user_id = carol;
  assert is_member(carol), 'cancelled but still inside paid period';
  update memberships set current_end = now() - interval '1 day' where user_id = carol;
  assert not is_member(carol), 'expired member loses access';

  -- 13. sold out
  update ticket_tiers set seats = 1 where id = regular;
  perform t.as_user(dave);
  perform submit_payment((p1->>'id')::uuid, '999999999991');
  perform t.as_user(admin_id);
  perform review_payment((p1->>'id')::uuid, true);
  perform t.as_user(eve);
  perform t.expect_error(format('select request_ticket_payment(%L, %L)', ev, regular), 'sold out');

  -- 14. free tier is confirmed immediately
  perform t.as_root();
  update ticket_tiers set price_inr = 0 where id = early; 
  delete from payments where user_id = eve; delete from registrations where user_id = eve;
  perform t.as_user(eve);
  p1 := request_ticket_payment(ev, early);
  assert p1->>'status' = 'approved' and (select status from registrations where user_id = eve) = 'paid', 'free ticket confirmed';

  -- 15. unauthenticated callers are rejected
  perform t.as_user(null);
  perform t.expect_error(format('select request_ticket_payment(%L, %L)', ev, early), 'sign in');

  perform t.as_root();
  raise notice 'ALL SQL BEHAVIOUR TESTS PASSED';
end $$;
