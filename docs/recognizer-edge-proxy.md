# Recognizer Edge Proxy

Use this when you want the Flutter app to call Supabase first, then let
Supabase forward the request to the private recognizer backend.

Flow:

```text
Flutter app
-> Supabase Edge Function: recognize-car
-> deployed recognizer backend
-> Gemini
```

The Flutter app sends the user's Supabase access token in the `Authorization`
header. Supabase verifies that token before the function runs. The function then
adds `x-racers-vault-secret` before forwarding to the recognizer backend.

## 1. Deploy The Recognizer Backend

Deploy `backend/recognizer` to Render, Railway, Fly.io, Cloud Run, or similar.

Set backend env vars:

```text
GEMINI_API_KEY=your_gemini_key
PORT=8787
RATE_LIMIT_MAX=30
RATE_LIMIT_WINDOW_MS=60000
RECOGNIZER_SHARED_SECRET=make_a_long_random_secret
```

The recognizer URL should end with:

```text
/recognize-car
```

Example:

```text
https://racers-vault-recognizer.example.com/recognize-car
```

## 2. Set Supabase Function Secrets

From the project root:

```powershell
supabase secrets set RECOGNIZER_URL="https://YOUR_BACKEND/recognize-car"
supabase secrets set RECOGNIZER_SHARED_SECRET="same_long_random_secret"
```

## 3. Deploy The Edge Function

```powershell
supabase functions deploy recognize-car
```

Do not pass `--no-verify-jwt`. The function should require a logged-in Supabase
user.

Your function endpoint will look like:

```text
https://YOUR_PROJECT_REF.functions.supabase.co/recognize-car
```

## 4. Run Or Build Flutter

Use the Supabase function URL as `RECOGNIZER_URL`:

```powershell
flutter run `
  --dart-define=SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY" `
  --dart-define=RECOGNIZER_URL="https://YOUR_PROJECT_REF.functions.supabase.co/recognize-car"
```

Release build:

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY" `
  --dart-define=RECOGNIZER_URL="https://YOUR_PROJECT_REF.functions.supabase.co/recognize-car"
```

## 5. Quick Test

After signing in inside the app, scan/import a photo. If the token is missing or
expired, Supabase will reject the request before it reaches the recognizer.

If the function returns `Recognizer URL is not configured`, set the Supabase
function secrets again.
