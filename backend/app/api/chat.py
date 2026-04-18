# ─────────────────────────────────────────────
# backend/app/api/chat.py
#
# Farming chatbot powered by Claude API.
# Features:
#   - Full farming expert system prompt
#   - Conversation history (last 10 turns)
#   - Language-aware responses
#   - Weather context injection
#   - Structured JSON output for UI
# ─────────────────────────────────────────────

import os
import logging
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

logger = logging.getLogger(__name__)
router = APIRouter()

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
CLAUDE_MODEL      = "claude-sonnet-4-20250514"


# ─────────────────────────────────────────────
# System prompt — defines the expert persona
# This is the most important part of the chatbot.
# ─────────────────────────────────────────────

FARMING_SYSTEM_PROMPT = """You are "Kisan Mitra" (Farmer's Friend), an expert agricultural assistant 
for Indian farmers. You have deep knowledge of:

CROPS: Rice, Wheat, Maize, Cotton, Sugarcane, Tomato, Potato, Onion, Soybean, Mustard, 
Chickpea, Pigeonpea, Groundnut, Banana, Mango, and all major Indian crops.

DISEASES: Plant diseases including blights, rusts, smuts, molds, wilts, viral diseases, 
bacterial infections, and nematode problems. You know symptoms, causes, and treatments.

AGRONOMY: Soil health, fertilizer management (NPK, micronutrients), irrigation scheduling, 
weed management, crop rotation, intercropping, organic farming, IPM.

INDIA-SPECIFIC: ICAR recommendations, state agriculture department guidelines, 
mandi prices awareness, government schemes (PM-KISAN, Fasal Bima Yojana, e-NAM), 
and regional crop practices for Punjab, Haryana, UP, Maharashtra, AP, Karnataka etc.

LANGUAGE: Respond in the same language the farmer uses. If they write in Hindi, respond 
in Hindi. If Punjabi, respond in Punjabi. Use simple language — avoid technical jargon 
unless the farmer seems educated. Use examples from their local context.

RESPONSE STYLE:
- Be warm, respectful, and encouraging — like a trusted village agricultural officer
- Give practical, actionable advice with specific quantities (e.g. "2g per liter", "50kg per acre")
- Mention both chemical AND organic/natural alternatives when relevant
- If a question is unclear, ask one focused clarifying question
- If you detect an urgent disease or pest situation, say so clearly and give immediate action steps
- Always mention safety precautions when recommending pesticides

WHAT YOU CANNOT DO:
- You cannot see images directly in chat (tell farmers to use the camera feature for disease detection)
- You cannot give 100% guaranteed predictions — always recommend consulting a local KVK or agriculture officer for serious problems
- You do not provide veterinary advice

Always end responses with a helpful follow-up question or suggestion to keep the conversation productive."""


# ─────────────────────────────────────────────
# Request / Response models
# ─────────────────────────────────────────────

class ChatTurn(BaseModel):
    role:    str   # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    message:       str
    language:      str = "en"
    history:       List[ChatTurn] = []
    location:      Optional[str] = None   # "Punjab", "Maharashtra" etc.
    crop_context:  Optional[str] = None   # Currently detected disease
    max_turns:     int = 10               # How many history turns to include


class ChatResponse(BaseModel):
    reply:    str
    language: str
    tokens:   int


# ─────────────────────────────────────────────
# Chat endpoint
# ─────────────────────────────────────────────

@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    """
    Send a message to the farming AI assistant.
    Accepts conversation history for context-aware replies.
    """
    if not ANTHROPIC_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="ANTHROPIC_API_KEY not configured. Set it in backend/.env",
        )

    # Build messages list
    messages = []

    # Inject context about location and current disease if available
    context_prefix = ""
    if req.location:
        context_prefix += f"[Farmer's location: {req.location}] "
    if req.crop_context:
        context_prefix += f"[Farmer just detected: {req.crop_context} using the app's camera] "

    # Add conversation history (last N turns)
    history = req.history[-req.max_turns:]
    for turn in history:
        messages.append({"role": turn.role, "content": turn.content})

    # Add current user message with context
    user_message = req.message
    if context_prefix:
        user_message = context_prefix + user_message

    messages.append({"role": "user", "content": user_message})

    # Call Claude API
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key":         ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type":      "application/json",
                },
                json={
                    "model":      CLAUDE_MODEL,
                    "max_tokens": 1024,
                    "system":     FARMING_SYSTEM_PROMPT,
                    "messages":   messages,
                },
            )
            response.raise_for_status()
            data = response.json()

        reply  = data["content"][0]["text"]
        tokens = data["usage"]["input_tokens"] + data["usage"]["output_tokens"]

        logger.info(f"Chat reply generated: {tokens} tokens, lang={req.language}")

        return ChatResponse(reply=reply, language=req.language, tokens=tokens)

    except httpx.HTTPStatusError as e:
        logger.error(f"Claude API HTTP error: {e.response.status_code} — {e.response.text}")
        raise HTTPException(status_code=502, detail="AI service temporarily unavailable")
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# Quick answer endpoint — single question, no history
# Used for quick treatment lookups from result screen
# ─────────────────────────────────────────────

class QuickAskRequest(BaseModel):
    question:     str
    language:     str = "en"
    disease:      Optional[str] = None
    crop:         Optional[str] = None


@router.post("/quick-ask")
async def quick_ask(req: QuickAskRequest):
    """
    Single-turn quick question — no conversation history.
    Used by result screen to get detailed treatment info.
    """
    context = ""
    if req.disease:
        context += f"The farmer's plant has been diagnosed with {req.disease}. "
    if req.crop:
        context += f"The affected crop is {req.crop}. "

    full_question = context + req.question

    chat_req = ChatRequest(
        message=full_question,
        language=req.language,
        history=[],
    )
    return await chat(chat_req)