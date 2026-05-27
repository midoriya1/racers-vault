const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const recognizerUrl = Deno.env.get('RECOGNIZER_URL');
  if (!recognizerUrl) {
    return jsonResponse({ error: 'Recognizer URL is not configured.' }, 500);
  }

  const contentType = request.headers.get('content-type');
  if (!contentType?.includes('multipart/form-data')) {
    return jsonResponse({ error: 'Expected multipart form data.' }, 400);
  }

  try {
    const body = await request.arrayBuffer();
    const headers = new Headers({ 'content-type': contentType });
    const sharedSecret = Deno.env.get('RECOGNIZER_SHARED_SECRET');
    if (sharedSecret) {
      headers.set('x-racers-vault-secret', sharedSecret);
    }

    const upstream = await fetch(recognizerUrl, {
      method: 'POST',
      headers,
      body,
    });

    const responseBody = await upstream.arrayBuffer();
    return new Response(responseBody, {
      status: upstream.status,
      headers: {
        ...corsHeaders,
        'content-type':
          upstream.headers.get('content-type') ?? 'application/json',
      },
    });
  } catch (error) {
    return jsonResponse(
      {
        error: 'Recognizer proxy failed.',
        detail: error instanceof Error ? error.message : String(error),
      },
      502,
    );
  }
});

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}
