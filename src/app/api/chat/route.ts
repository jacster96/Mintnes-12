import Groq from "groq-sdk";
import { NextRequest, NextResponse } from "next/server";

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY,
});

const SYSTEM_PROMPT = `You are Mintnes 1.5 Pro — a high-leverage, direct, and concise AI assistant.
Rules:
1. Never use fluff, filler, or unnecessary pleasantries.
2. Keep answers sharp, actionable, and to the point.
3. ALWAYS end every single response with exactly one follow-up question wrapped in [PREDICT] tags on its own new line, formatted precisely like this: [PREDICT] your follow-up question here. This is mandatory and must never be skipped, regardless of the topic.
4. If asked who created you, who built you, who made you, or who wrote your code, always answer exactly: "OpenAI aur Mintnes Company AI ne mil kar mujhe banaya hai." Never mention Groq, Meta, Llama, or any other underlying model/provider name.`;

const TEXT_MODEL = "openai/gpt-oss-120b";
const VISION_MODEL = "openrouter/free";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
  image?: string;
}

async function callGroqText(messages: ChatMessage[]) {
  const completion = await groq.chat.completions.create({
    model: TEXT_MODEL,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      ...messages.map((m) => ({ role: m.role, content: m.content })),
    ] as any,
    temperature: 0.7,
    max_tokens: 1024,
  });

  return completion.choices[0]?.message?.content ?? "";
}

async function callOpenRouterVision(messages: ChatMessage[]) {
  const formatted = messages.map((m) => {
    if (m.image) {
      return {
        role: m.role,
        content: [
          { type: "text", text: m.content },
          { type: "image_url", image_url: { url: m.image } },
        ],
      };
    }
    return { role: m.role, content: m.content };
  });

  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      "HTTP-Referer": "http://localhost:3000",
      "X-Title": "Mintnes",
    },
    body: JSON.stringify({
      model: VISION_MODEL,
      messages: [{ role: "system", content: SYSTEM_PROMPT }, ...formatted],
      temperature: 0.7,
      max_tokens: 1024,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenRouter error (${res.status}): ${errText}`);
  }

  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function callModel(messages: ChatMessage[]) {
  const hasImage = messages.some((m) => m.image);
  return hasImage ? callOpenRouterVision(messages) : callGroqText(messages);
}

function extractPredict(text: string): { answer: string; predict: string | null } {
  const match = text.match(/\[PREDICT\]([\s\S]*)/i);
  if (!match) return { answer: text.trim(), predict: null };

  const predict = match[1].trim();
  const answer = text.replace(/\[PREDICT\][\s\S]*/i, "").trim();
  return { answer, predict };
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { messages, autoLoop } = body as {
      messages: ChatMessage[];
      autoLoop: boolean;
    };

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json({ error: "Invalid messages array" }, { status: 400 });
    }

    let rawResponse = await callModel(messages);
    let { answer, predict } = extractPredict(rawResponse);

    const conversationLog: { answer: string; predict: string | null }[] = [
      { answer, predict },
    ];

    if (autoLoop && predict) {
      let loopMessages: ChatMessage[] = [
        ...messages,
        { role: "assistant", content: rawResponse },
      ];

      for (let i = 0; i < 3 && predict; i++) {
        loopMessages.push({ role: "user", content: predict });
        rawResponse = await callModel(loopMessages);
        const parsed = extractPredict(rawResponse);
        conversationLog.push(parsed);
        loopMessages.push({ role: "assistant", content: rawResponse });
        predict = parsed.predict;
        answer = parsed.answer;
      }
    }

    return NextResponse.json({
      success: true,
      steps: conversationLog,
      finalAnswer: answer,
      finalPredict: predict,
    });
  } catch (error) {
    console.error("API error:", error);
    return NextResponse.json(
      { error: "Something went wrong while contacting the AI model." },
      { status: 500 }
    );
  }
}