import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import { fileTypeFromBuffer } from 'file-type';
import { GoogleGenAI } from '@google/genai';
import multer from 'multer';
import sharp from 'sharp';

const app = express();
const rateLimitWindowMs = Number(process.env.RATE_LIMIT_WINDOW_MS || 60_000);
const rateLimitMax = Number(process.env.RATE_LIMIT_MAX || 30);
const rateLimitBuckets = new Map();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 8 * 1024 * 1024,
  },
});

app.use(cors());
app.use(express.json());

app.get('/health', (request, response) => {
  response.json({ ok: true });
});

app.use(requireSharedSecret);
app.use(rateLimitRequests);

app.post('/recognize-car', upload.single('image'), async (request, response) => {
  try {
    if (!process.env.GEMINI_API_KEY) {
      response.status(500).json({ error: 'GEMINI_API_KEY is not configured.' });
      return;
    }

    if (!request.file) {
      response.status(400).json({ error: 'Missing image file field.' });
      return;
    }

    const country = String(request.body.country || 'unknown country');
    const city = String(request.body.city || 'unknown city');
    const detectedType = await fileTypeFromBuffer(request.file.buffer);
    const mimeType = normalizeImageMimeType(
      detectedType?.mime || request.file.mimetype,
    );
    const base64Image = request.file.buffer.toString('base64');

    if (!mimeType) {
      response.status(400).json({
        error: 'Unsupported image type.',
        detail: `Received MIME type ${request.file.mimetype || 'unknown'}.`,
      });
      return;
    }

    const ai = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
    });

    const result = await ai.models.generateContent({
      model: process.env.GEMINI_MODEL || 'gemini-2.5-flash',
      contents: [
        {
          role: 'user',
          parts: [
            {
              text: [
                'Identify the car in this image for a car spotting app.',
                `Location context: ${city}, ${country}.`,
                'Return only strict JSON with this shape:',
                '{"candidates":[{"carName":"string","make":"string","model":"string","generation":"string","yearRange":"string","bodyType":"string","category":"Cars|Supercars|Hypercars|Sports Cars|JDM|Japanese|Italian|German|British|American|French|Swedish|Korean|Muscle|Luxury|Vintage|Classic|SUVs|Off-road|EVs|Sedans|Hatchbacks|Trucks|Bikes|Superbikes|Cruisers|Adventure Bikes|Dirt Bikes|Scooters|Hot Wheels|RC|Karts","confidence":0.0,"suggestedRarity":"Common|Uncommon|Rare|Ultra Rare|Legendary|Mythic","reason":"string","licensePlateVisible":false,"faceVisible":false,"syntheticImageRisk":0.0,"manipulationRisk":0.0,"securityNote":"string","privacyRegions":[{"type":"plate|face","x":0.0,"y":0.0,"width":0.0,"height":0.0,"confidence":0.0}]}]}',
                'Give up to 3 candidates. If the image does not clearly show a vehicle, model car, RC car, kart, or bike, return an empty candidates array.',
                'Use confidence from 0 to 1. Rarity should be based on how unusual the car is likely to be in the given country.',
                'Choose the most specific category possible. Use Hypercars for ultra-exclusive cars, Supercars for exotic performance cars, Sports Cars for attainable performance cars, and origin/culture categories like Italian, German, British, American, Japanese, JDM, French, Swedish, or Korean when that identity is stronger.',
                'Use JDM only for Japanese domestic market or enthusiast JDM-style cars. Use Japanese for general Japanese cars.',
                'Use Muscle/Luxury/Classic when that identity is stronger, and SUVs/Off-road/EVs/Sedans/Hatchbacks/Trucks for body-type categories.',
                'Classify motorcycles as Bikes, Superbikes, Cruisers, Adventure Bikes, Dirt Bikes, or Scooters. Classify toy die-cast cars as Hot Wheels, radio-controlled models as RC, and go-karts as Karts.',
                'For privacy/security, estimate whether license plates or bystander faces are visible. Estimate syntheticImageRisk and manipulationRisk from 0 to 1. If either risk is high, explain briefly in securityNote.',
                'If a license plate or face is visible, include privacyRegions bounding boxes. Coordinates must be normalized from 0 to 1 relative to the full image: x is left, y is top, width and height are box size. Add slight padding around each sensitive object. Do not include boxes for normal car parts.',
              ].join('\n'),
            },
            {
              inlineData: {
                mimeType,
                data: base64Image,
              },
            },
          ],
        },
      ],
      config: {
        responseMimeType: 'application/json',
      },
    });

    const text = result.text?.trim() || '{"candidates":[]}';
    const parsed = parseJsonObject(text);
    const normalized = normalizeRecognitionResponse(parsed);
    const privacy = await createPrivacySafeImage(
      request.file.buffer,
      normalized.candidates[0],
    );

    response.json({
      ...normalized,
      ...privacy,
    });
  } catch (error) {
    console.error(error);
    response.status(500).json({
      error: 'Recognition failed.',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
});

function parseJsonObject(text) {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      return { candidates: [] };
    }
    return JSON.parse(match[0]);
  }
}

async function createPrivacySafeImage(buffer, primaryCandidate) {
  const needsPlateBlur = Boolean(primaryCandidate?.licensePlateVisible);
  const needsFaceBlur = Boolean(primaryCandidate?.faceVisible);

  if (!needsPlateBlur && !needsFaceBlur) {
    return {
      blurStatus: 'not_needed',
      processedMimeType: '',
      processedImageBase64: '',
    };
  }

  const normalizedImage = await sharp(buffer)
    .rotate()
    .jpeg({ quality: 86, mozjpeg: true })
    .toBuffer();
  const metadata = await sharp(normalizedImage).metadata();
  const width = metadata.width || 0;
  const height = metadata.height || 0;

  if (width < 120 || height < 120) {
    return {
      blurStatus: 'failed',
      processedMimeType: '',
      processedImageBase64: '',
    };
  }

  const regions = privacyBlurRegions({
    width,
    height,
    candidateRegions: primaryCandidate?.privacyRegions,
    needsPlateBlur,
    needsFaceBlur,
  });
  const composites = [];

  for (const region of regions) {
    const blurredRegion = await sharp(normalizedImage)
      .extract(region)
      .blur(28)
      .jpeg({ quality: 82 })
      .toBuffer();
    composites.push({
      input: blurredRegion,
      left: region.left,
      top: region.top,
    });
  }

  const redacted = await sharp(normalizedImage)
    .composite(composites)
    .jpeg({ quality: 86, mozjpeg: true })
    .toBuffer();

  return {
    blurStatus: 'processed',
    processedMimeType: 'image/jpeg',
    processedImageBase64: redacted.toString('base64'),
  };
}

function privacyBlurRegions({
  width,
  height,
  candidateRegions,
  needsPlateBlur,
  needsFaceBlur,
}) {
  const boxedRegions = Array.isArray(candidateRegions)
    ? candidateRegions
        .filter((region) => {
          if (region.type === 'plate') {
            return needsPlateBlur;
          }
          if (region.type === 'face') {
            return needsFaceBlur;
          }
          return false;
        })
        .map((region) => normalizedBoxToRegion(region, width, height))
        .filter(Boolean)
    : [];

  if (boxedRegions.length > 0) {
    return boxedRegions;
  }

  const regions = [];
  if (needsPlateBlur) {
    regions.push(toRegion({
      width,
      height,
      left: 0.24,
      top: 0.58,
      regionWidth: 0.52,
      regionHeight: 0.28,
    }));
  }

  if (needsFaceBlur) {
    regions.push(toRegion({
      width,
      height,
      left: 0.18,
      top: 0.08,
      regionWidth: 0.64,
      regionHeight: 0.42,
    }));
  }

  return regions;
}

function normalizedBoxToRegion(region, imageWidth, imageHeight) {
  const padding = region.type === 'face' ? 0.025 : 0.018;
  const x = clamp(region.x - padding, 0, 1);
  const y = clamp(region.y - padding, 0, 1);
  const right = clamp(region.x + region.width + padding, 0, 1);
  const bottom = clamp(region.y + region.height + padding, 0, 1);

  if (right <= x || bottom <= y) {
    return null;
  }

  return toRegion({
    width: imageWidth,
    height: imageHeight,
    left: x,
    top: y,
    regionWidth: right - x,
    regionHeight: bottom - y,
  });
}

function toRegion({ width, height, left, top, regionWidth, regionHeight }) {
  const region = {
    left: Math.round(width * left),
    top: Math.round(height * top),
    width: Math.round(width * regionWidth),
    height: Math.round(height * regionHeight),
  };

  region.left = clampInteger(region.left, 0, width - 1);
  region.top = clampInteger(region.top, 0, height - 1);
  region.width = clampInteger(region.width, 1, width - region.left);
  region.height = clampInteger(region.height, 1, height - region.top);
  return region;
}

function clampInteger(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function normalizeRecognitionResponse(value) {
  const candidates = Array.isArray(value?.candidates) ? value.candidates : [];

  return {
    candidates: candidates.slice(0, 3).map((candidate) => ({
      carName: String(candidate.carName || 'Unknown car'),
      make: String(candidate.make || ''),
      model: String(candidate.model || ''),
      generation: String(candidate.generation || ''),
      yearRange: String(candidate.yearRange || ''),
      bodyType: String(candidate.bodyType || ''),
      category: normalizeCategory(candidate.category),
      confidence: clamp(Number(candidate.confidence || 0), 0, 1),
      suggestedRarity: normalizeRarity(candidate.suggestedRarity),
      reason: String(candidate.reason || 'AI recognition result'),
      licensePlateVisible: Boolean(candidate.licensePlateVisible),
      faceVisible: Boolean(candidate.faceVisible),
      syntheticImageRisk: clamp(Number(candidate.syntheticImageRisk || 0), 0, 1),
      manipulationRisk: clamp(Number(candidate.manipulationRisk || 0), 0, 1),
      securityNote: String(candidate.securityNote || ''),
      privacyRegions: normalizePrivacyRegions(candidate.privacyRegions),
    })),
  };
}

function normalizePrivacyRegions(value) {
  const regions = Array.isArray(value) ? value : [];
  return regions
    .map((region) => ({
      type: region?.type === 'face' ? 'face' : region?.type === 'plate' ? 'plate' : '',
      x: clamp(Number(region?.x || 0), 0, 1),
      y: clamp(Number(region?.y || 0), 0, 1),
      width: clamp(Number(region?.width || 0), 0, 1),
      height: clamp(Number(region?.height || 0), 0, 1),
      confidence: clamp(Number(region?.confidence || 0), 0, 1),
    }))
    .filter((region) => {
      return region.type && region.width >= 0.02 && region.height >= 0.02;
    })
    .slice(0, 12);
}

function requireSharedSecret(request, response, next) {
  const expected = process.env.RECOGNIZER_SHARED_SECRET;
  if (!expected) {
    next();
    return;
  }

  if (request.get('x-racers-vault-secret') !== expected) {
    response.status(401).json({ error: 'Recognizer auth failed.' });
    return;
  }

  next();
}

function rateLimitRequests(request, response, next) {
  const now = Date.now();
  const key = request.ip || request.socket.remoteAddress || 'unknown';
  const bucket = rateLimitBuckets.get(key);

  if (!bucket || now - bucket.startedAt > rateLimitWindowMs) {
    rateLimitBuckets.set(key, { startedAt: now, count: 1 });
    next();
    return;
  }

  bucket.count += 1;
  if (bucket.count > rateLimitMax) {
    response.status(429).json({ error: 'Too many recognizer requests. Try again soon.' });
    return;
  }

  next();
}

function normalizeCategory(value) {
  const allowed = [
    'Cars',
    'Supercars',
    'Hypercars',
    'Sports Cars',
    'JDM',
    'Japanese',
    'Italian',
    'German',
    'British',
    'American',
    'French',
    'Swedish',
    'Korean',
    'Muscle',
    'Luxury',
    'Vintage',
    'Classic',
    'SUVs',
    'Off-road',
    'EVs',
    'Sedans',
    'Hatchbacks',
    'Trucks',
    'Bikes',
    'Superbikes',
    'Cruisers',
    'Adventure Bikes',
    'Dirt Bikes',
    'Scooters',
    'Hot Wheels',
    'RC',
    'Karts',
  ];
  return allowed.includes(value) ? value : 'Cars';
}

function normalizeRarity(value) {
  const allowed = ['Common', 'Uncommon', 'Rare', 'Ultra Rare', 'Legendary', 'Mythic'];
  return allowed.includes(value) ? value : 'Rare';
}

function normalizeImageMimeType(value) {
  const supported = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']);
  if (supported.has(value)) {
    return value;
  }

  return null;
}

function clamp(value, min, max) {
  if (Number.isNaN(value)) {
    return min;
  }
  return Math.min(max, Math.max(min, value));
}

const port = Number(process.env.PORT || 8787);
app.listen(port, '0.0.0.0', () => {
  console.log(`Racers Vault recognizer listening on http://0.0.0.0:${port}`);
});
