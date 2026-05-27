# Racers Vault Recognizer

Small HTTP backend for car recognition. The Flutter app sends an image, country,
and city to this service. The service calls Gemini Vision and returns vehicle
candidates plus privacy/security signals.

## Setup

```powershell
cd "D:\car vault\car_vault\backend\recognizer"
npm install
Copy-Item .env.example .env
```

Edit `.env` and set:

```text
GEMINI_API_KEY=your_key_here
PORT=8787
RATE_LIMIT_MAX=30
RATE_LIMIT_WINDOW_MS=60000
# Optional. If set, clients must send x-racers-vault-secret.
RECOGNIZER_SHARED_SECRET=
```

## Run

```powershell
npm run dev
```

Health check:

```text
http://127.0.0.1:8787/health
```

## Run Flutter Against This Backend

Android emulator uses `10.0.2.2` to reach your PC:

```powershell
flutter run --dart-define=RECOGNIZER_URL=http://10.0.2.2:8787/recognize-car
```

Real Android phone must use your PC's LAN IP address:

```powershell
flutter run --dart-define=RECOGNIZER_URL=http://YOUR_PC_IP:8787/recognize-car
```

Your phone and PC must be on the same Wi-Fi, and Windows Firewall must allow
Node.js to accept local network connections.

## API

`POST /recognize-car`

Multipart form fields:

- `image`: photo file
- `country`: user country
- `city`: user city

Response:

```json
{
  "candidates": [
    {
      "carName": "Porsche 911 GT3 RS",
      "make": "Porsche",
      "model": "911 GT3 RS",
      "generation": "992",
      "yearRange": "2022-present",
      "bodyType": "Coupe",
      "category": "Supercars",
      "confidence": 0.87,
      "suggestedRarity": "Ultra Rare",
      "reason": "Large rear wing and GT3 RS body cues",
      "licensePlateVisible": true,
      "faceVisible": false,
      "syntheticImageRisk": 0.08,
      "manipulationRisk": 0.05,
      "securityNote": "Plate may be visible. Queue for blur before public use.",
      "privacyRegions": [
        {
          "type": "plate",
          "x": 0.41,
          "y": 0.64,
          "width": 0.18,
          "height": 0.06,
          "confidence": 0.82
        }
      ]
    }
  ],
  "blurStatus": "processed",
  "processedMimeType": "image/jpeg",
  "processedImageBase64": "..."
}
```

Security notes:

- Requests are rate-limited in memory by IP.
- Set `RECOGNIZER_SHARED_SECRET` in production and send the same value from a
  trusted API gateway or backend. Do not ship that secret in a public app build.
- License plate and face fields are detection flags.
- `privacyRegions` contains normalized bounding boxes for exact face/plate blur.
- The backend returns an auto-blurred JPEG as `processedImageBase64` when
  plate/face risk is detected. Flutter uploads that processed image instead of
  the raw selected image.
- If the model flags a privacy risk but gives no usable boxes, the backend falls
  back to a conservative blur region.
