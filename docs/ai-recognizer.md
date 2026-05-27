# AI Recognizer Setup

The app can run with either:

- Mock recognizer: default, no backend needed.
- Real recognizer: pass `RECOGNIZER_URL` at runtime.

## Local Backend

```powershell
cd "D:\car vault\car_vault\backend\recognizer"
npm install
Copy-Item .env.example .env
npm run dev
```

Put your Gemini API key in `.env`.

## Android Emulator

```powershell
cd "D:\car vault\car_vault"
flutter run --dart-define=RECOGNIZER_URL=http://10.0.2.2:8787/recognize-car
```

## Real Android Phone

Find your PC IPv4 address:

```powershell
ipconfig
```

Then run:

```powershell
flutter run --dart-define=RECOGNIZER_URL=http://YOUR_PC_IP:8787/recognize-car
```

Your phone and PC must be on the same Wi-Fi.
