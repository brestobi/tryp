import type { VercelRequest, VercelResponse } from '@vercel/node';

const MODEL = 'gemini-2.0-flash';
const MAX_MESSAGE_LENGTH = 1000;
const MAX_HISTORY_ITEMS = 12;

const TRYP_KNOWLEDGE = `
You are the official TRYP website assistant. Answer questions about TRYP using only the verified information below.

TRYP is a local ride platform being built for Limpopo, South Africa. It is designed to make everyday movement simpler for passengers and create opportunity for drivers.

Passengers can use TRYP to set a pickup and destination, review available ride options and trip details, request a ride now, schedule a pickup for a future date and time, and follow ride status and driver details in the app.

Drivers can use a driver-app onboarding flow to register, add profile and vehicle information, submit required documents for review, choose when they are available, view relevant ride requests, and potentially post intercity trips.

TRYP Business is being shaped for organisations needing local transport, scheduled movement, staff movement, business travel, and fleet partnerships.

TRYP is in active rollout. The website must not claim that rides, drivers, pricing, app-store downloads, coverage, payment methods, emergency response, or specific safety tools are currently available unless the user asks about the stated planned experience. Store links will be added before public launch.

Safety: users should review pickup and destination details, confirm ride details, use seatbelts, behave respectfully, and end an interaction and contact local emergency services if they feel unsafe or there is immediate danger. TRYP is not an emergency response service.

For account, payment, trip, or general support questions, direct users to hello@mytryp.co.za. Never ask for passwords, payment card numbers, one-time codes, identity documents, precise live location, or other sensitive personal information.

If the answer is not supported by this information, say that you do not have confirmed information and direct the user to hello@mytryp.co.za. Do not invent prices, ETAs, availability, policies, legal advice, or launch dates.

Keep answers concise, friendly, and practical. Identify yourself as the TRYP assistant when useful. You may answer in English unless the user asks for another language, but do not pretend to be a human support agent.
`;

type ChatMessage = { role: 'user' | 'assistant'; content: string };

function sendJson(res: VercelResponse, status: number, body: Record<string, unknown>) {
  res.status(status).setHeader('Content-Type', 'application/json').json(body);
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return sendJson(res, 405, { error: 'Method not allowed.' });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return sendJson(res, 500, { error: 'The assistant is not configured yet.' });

  const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  const message = typeof body?.message === 'string' ? body.message.trim() : '';
  const history = Array.isArray(body?.history) ? body.history : [];

  if (!message) return sendJson(res, 400, { error: 'Please enter a question.' });
  if (message.length > MAX_MESSAGE_LENGTH) return sendJson(res, 400, { error: 'Please keep your question under 1,000 characters.' });

  const safeHistory: ChatMessage[] = history
    .filter((item: unknown): item is ChatMessage => {
      if (!item || typeof item !== 'object') return false;
      const candidate = item as Partial<ChatMessage>;
      return (candidate.role === 'user' || candidate.role === 'assistant')
        && typeof candidate.content === 'string'
        && candidate.content.length <= MAX_MESSAGE_LENGTH;
    })
    .slice(-MAX_HISTORY_ITEMS);

  const contents = [
    ...safeHistory.map((item) => ({ role: item.role === 'assistant' ? 'model' : 'user', parts: [{ text: item.content }] })),
    { role: 'user', parts: [{ text: message }] },
  ];

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${encodeURIComponent(apiKey)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: TRYP_KNOWLEDGE }] },
        contents,
        generationConfig: { temperature: 0.2, maxOutputTokens: 350 },
      }),
    });

    if (!response.ok) {
      console.error('Gemini request failed', response.status);
      return sendJson(res, 502, { error: 'The assistant is temporarily unavailable. Please try again or email hello@mytryp.co.za.' });
    }

    const data = await response.json() as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
    const answer = data.candidates?.[0]?.content?.parts?.map((part) => part.text || '').join('').trim();
    if (!answer) return sendJson(res, 502, { error: 'I could not generate an answer. Please try again.' });

    return sendJson(res, 200, { answer });
  } catch (error) {
    console.error('Gemini assistant error', error);
    return sendJson(res, 502, { error: 'The assistant is temporarily unavailable. Please try again.' });
  }
}
