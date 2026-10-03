# She Tribe app (Flutter)

One Flutter codebase for **Android, iOS and the web**, with a layout that adapts from phones to tablets and desktop browsers.

- **Sign in with WhatsApp:** enter your number, get a 6-digit code on WhatsApp.
- **Events:** the First Circle event with Early Bird, Regular and Premium tickets.
- **Pay with Google Pay (UPI QR):** scan the QR (or tap "Open my UPI app"), pay, enter the 12-digit transaction ID. You confirm it in the app's **Payments** tab and the ticket turns on.
- **Membership:** Free, Member and Circle. A paid membership lasts a year and unlocks the member directory.
- **Community:** Ask & Offer wall, and a directory only members can open and only women who opt in appear in.
- **Me:** profile, the commitment card, sign out, delete account.

It starts in **demo mode** (sample data, no accounts, nothing real is charged). In demo mode the sign-in code is **123456** and you are your own admin, so you can walk through the whole flow.

## What changes without a payment gateway (read this)

| | With a gateway (Razorpay) | What you have now |
|---|---|---|
| Confirming a payment | Instant, automatic | **You approve each payment** by matching the amount and transaction ID in your Google Pay history. Fine for a few dozen people per event; slow if hundreds pay at once. |
| Subscriptions | Auto-renewing | **A membership is a one-year pass.** UPI QR is a one-off payment, so nothing renews itself. The app has a Renew button that adds a year on top. |
| Fraud protection | Gateway checks the payment | A member could type someone else's transaction ID. The app blocks reusing the same ID twice and shows you the amount, note and ID, but **you are the check**: look for the money in Google Pay before approving. |

**Two things to test with a real ₹1 payment before you announce it:**
1. Whether the "Open my UPI app" button works with your Google Pay account type. Apps sometimes refuse amount-filled links to personal UPI IDs, while the same payload scanned as a QR works. If the button fails, scanning the QR from another phone, or copying the UPI ID, still works.
2. If your UPI ID is a personal one, ask your bank about limits on receiving many payments. A business/merchant UPI ID (for example through Google Pay for Business) usually behaves better.

## What it costs

| Item | Cost |
|---|---|
| Flutter, Dart, VS Code / Android Studio | Free |
| Backend: Supabase free plan | Free |
| Web hosting: Cloudflare Pages, Netlify or GitHub Pages | Free |
| UPI payments | No fee to you. UPI payments to individuals and merchants carry no fee to the receiver |
| **WhatsApp codes (Meta)** | **Not free.** About ₹0.12 per code in India at the published list rate, so 100 sign-ups is roughly ₹12. Check Meta's current rate card. Setting up the account and testing with a test number is free. |
| Google Play listing | One-time $25 (only if you publish to the Play Store) |
| Apple App Store listing | $99 per year (only if you publish to the App Store) |

If you want **no** per-message cost at all, the alternative is "reverse" verification: the member sends a code to your WhatsApp number (messages members send you are free) and your server reads it. It's a different flow, and I haven't built it. Say if you want it.

## Testing with a dummy code

**1. Instant, no setup (demo mode).** Run the app without any keys:

```
flutter pub get
flutter run -d chrome
```
Enter any 10-digit number, then the code **123456**. Reserve a ticket, enter any 12 digits as the transaction ID (for example `401234567890`), then open the **Payments** tab and approve it. The ticket appears under Events. Try Membership the same way.

**2. Live backend with a dummy number.** After setup (below), set these secrets so that one number never sends a real WhatsApp message and always accepts your dummy code:
```
supabase secrets set OTP_TEST_NUMBERS=+919999900000 OTP_TEST_CODE=123456
```
Sign in with 99999 00000 and code 123456. The dummy code works **only** for numbers listed in `OTP_TEST_NUMBERS`; real numbers always get a random code over WhatsApp. Use a number you don't give to a real person.

## What I tested, and what I could not

**Tested here and passing**
- The payment and membership rules, on a real PostgreSQL database: price decided by the server, repeat requests reuse the same payment, changing ticket tier cancels the old request, transaction ID must be 12 digits and can't be reused, members can't approve their own payments or edit their own tickets, approval turns on the ticket or membership, a rejected payment can be retried, early renewal adds a year, cancelled members keep access until their paid period ends, sold-out and member prices work, free tickets confirm instantly. Run again with `supabase/tests/run_sql_tests.sh`.
- The WhatsApp code logic (12 tests with the dummy code): normalising Indian numbers, a code works once, five wrong tries lock it, codes expire after 5 minutes, the dummy code does not work for real numbers, sending is rate-limited, and the stored code is hashed. Run with `node --experimental-strip-types --test supabase/tests/otp.test.ts`.
- All Dart and TypeScript files parse without syntax errors.

**NOT tested (I could not do this in my environment)**
- The Flutter app was never compiled or run. Expect small fixes on the first `flutter analyze`; paste any errors to me.
- Real WhatsApp delivery, the live Supabase sign-in handoff, and a real UPI payment. Those need your accounts.

## Setup

**1. Install Flutter** (flutter.dev), then in this folder:
```
flutter create --org com.shetribe --project-name she_tribe .
flutter pub get
dart run flutter_launcher_icons
```
On Android also add `<uses-permission android:name="android.permission.INTERNET"/>` inside `<manifest>` in `android/app/src/main/AndroidManifest.xml`.

**2. Supabase (free)**
- Create a project at supabase.com, open SQL Editor and run `supabase/schema.sql` once.
- In the Table Editor, open `payment_settings` and replace `REPLACE-ME@upi` with your real UPI ID. Optionally add your WhatsApp number (with country code) in `support_whatsapp` for the "Need help?" link.
- Free projects pause after about a week of inactivity. Open the dashboard before your event.

**3. WhatsApp sign-in (Meta Cloud API)**
- At developers.facebook.com create an app with the **WhatsApp** product and a WhatsApp Business account. Meta gives you a test number and lets you message a few verified numbers for free while developing.
- Create a message template of category **Authentication** with the **copy code** button (name it `shetribe_login_code`, language English) and wait for approval.
- Create a permanent access token and copy the **Phone number ID**.
- Set the secrets:
```
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase secrets set WHATSAPP_TOKEN=... WHATSAPP_PHONE_NUMBER_ID=... OTP_PEPPER=any-long-random-text
supabase secrets set OTP_TEST_NUMBERS=+919999900000 OTP_TEST_CODE=123456
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy delete-account
```
- Once sign-in works, turn off Authentication > Sign In / Providers > **Allow new users to sign up** so nobody can create accounts around the WhatsApp check, then sign in once more to confirm it still works.
- Meta's API version is configurable with `WHATSAPP_API_VERSION` (default `v23.0`). If Meta retires it, set a newer one.

**4. Make yourself the admin.** Sign in once with your own number, then in the SQL Editor:
```
insert into public.admins (user_id)
select user_id from public.phone_accounts where phone = '+91XXXXXXXXXX';
```
A **Payments** tab appears for you. Only admins can approve payments.

**5. Run or build with your keys** (the anon key is safe in the app; never put a service key in it):
```
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=SITE_URL=https://your-site

flutter build web --release    (same --dart-define flags)
flutter build apk --release    (same flags)
```

## Put it on GitHub and run it

GitHub stores the code, builds the app for you and hosts the web version free. It does **not** run the backend: sign-in, the database and payments stay on Supabase (steps above).

1. Create a **public** repository on github.com. (GitHub Pages is free only for public repos. Nothing secret is in this code: the Supabase anon key is meant to be public, and your UPI ID lives in the database, not here.)
2. Upload the project:
```
git init
git add .
git commit -m "She Tribe app"
git branch -M main
git remote add origin https://github.com/YOUR-NAME/she-tribe.git
git push -u origin main
```
3. In the repo: **Settings > Pages > Build and deployment > Source: GitHub Actions**.
4. Push again (or Actions tab > "Deploy web app to GitHub Pages" > Run workflow). After a couple of minutes the app is at `https://YOUR-NAME.github.io/she-tribe/`.
5. To connect it to your backend, go to **Settings > Secrets and variables > Actions > Variables** and add `SUPABASE_URL` and `SUPABASE_ANON_KEY` (and `SITE_URL`, the address of your landing site where `privacy.html` lives). Then run the workflow again. **Never add your Supabase service key or WhatsApp token to GitHub.**

With no variables set, the deployed site runs in **demo mode** (sample data, code 123456). That is handy for showing the team, but it is public, so don't share the link as your real sign-up page until step 5 is done.

**Android APK:** Actions tab > "Build Android APK" > Run workflow. When it finishes, download `she-tribe-apk` from the run page and share the file on WhatsApp. It installs directly (people must allow installs from unknown sources). It is not signed for the Play Store; that needs your own signing key later. **iOS** can't be shared this way without a paid Apple developer account.

If the first run fails, open the failed step in the Actions tab and send me the log. Because I couldn't compile the app myself, the first build is where any small mistakes will show up.

## Running an event

1. Edit the event's date and venue in the Supabase Table Editor (`events`).
2. People reserve and pay. You'll see a count on the **Payments** tab.
3. For each one: open Google Pay, find the payment (same amount, same transaction ID), then Approve. Reject anything you can't find.
4. `registrations` in the Table Editor shows who is confirmed. `payments` is your record of every payment, including the transaction ID and who approved it.

## App Store and Play Store rules

- **Event tickets** are for a real-world event, so paying by UPI in the app is normally fine on both stores.
- **Memberships** unlock digital features in the app. Apple and Google generally require their own billing for that (and Apple specifically lists QR codes as a banned workaround). Build store versions with `--dart-define=STORE_BUILD=true`: the app then hides membership purchase and shows plans and the member's status only, and members join on the web app. Use the default build for the web app and for APKs you share directly.
- Apple requires in-app **account deletion**. It's built in (Me > Delete account).
- Update your privacy policy to name Supabase and Meta/WhatsApp, and say that payment transaction IDs are stored.

## Folder guide

```
lib/main.dart             app start, demo/live switch
lib/backend.dart          demo data + Supabase calls
lib/app_state.dart        app-wide state
lib/screens/              home, events, pay (QR), community, membership, me, admin, sign-in, profile
supabase/schema.sql       database, security rules, payment functions, starter data
supabase/functions/       send-otp, verify-otp, delete-account (+ _shared logic)
supabase/tests/           SQL payment tests and WhatsApp code tests
```
