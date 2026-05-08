import logging
import os
from typing import List, Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)
router = APIRouter()

HUGGING_FACE_API_KEY = os.getenv("HUGGING_FACE_API_KEY", "")
HUGGING_FACE_API_URL = os.getenv(
    "HUGGING_FACE_API_URL",
    "https://router.huggingface.co/v1/chat/completions",
)
HUGGING_FACE_MODEL = os.getenv(
    "HUGGING_FACE_MODEL",
    "katanemo/Arch-Router-1.5B:hf-inference",
)

FARMING_SYSTEM_PROMPT = """You are an AI agricultural assistant for Indian farmers.
Perform all reasoning internally and return only the final answer to the farmer.

Follow this process internally:
1. Detect the user's language.
2. Translate the user's message into simple English internally if needed.
3. Understand the problem and identify:
   - crop, if mentioned
   - possible issue or disease
   - the farmer's intent
4. Use agricultural knowledge and careful reasoning.
5. Generate the final answer in the farmer's original language.

Response requirements:
- Use simple, farmer-friendly language
- Prefer short bullet points
- Be clear, practical, and respectful
- Focus on Indian farming context when relevant
- If the query is unclear or confidence is low, ask 1 or 2 short clarifying questions instead of guessing

Safety rules:
- Never invent pesticide, fungicide, herbicide, or fertilizer product names
- Never invent doses, spray schedules, waiting periods, or chemical treatments
- Do not give unsafe or harmful advice
- If unsure, clearly say you are not fully sure

When answering:
- If possible, include:
  - Problem
  - Step-by-step solution
  - Prevention tips, if useful
- Do not mention your internal steps, translation, or chain-of-thought
- Return only the final helpful answer in the original user language

Important limits:
- You cannot see images directly in chat unless the user typed the details
- Do not claim certainty when the diagnosis is uncertain
- Avoid hallucinations and unsupported specifics"""


class ChatTurn(BaseModel):
    role: str = Field(..., min_length=1, max_length=20)
    content: str = Field(..., min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    language: str = Field(default="en", min_length=2, max_length=10)
    history: List[ChatTurn] = []
    location: Optional[str] = Field(default=None, max_length=120)
    crop_context: Optional[str] = Field(default=None, max_length=80)
    max_turns: int = Field(default=10, ge=1, le=10)


class ChatResponse(BaseModel):
    reply: str
    language: str
    tokens: int


def _build_messages(req: ChatRequest) -> list[dict[str, str]]:
    context_prefix = ""
    if req.language:
        context_prefix += f"[Preferred app language: {req.language}] "
    if req.location:
        context_prefix += f"[Farmer's location: {req.location}] "
    if req.crop_context:
        context_prefix += (
            f"[Farmer just detected: {req.crop_context} using the app's camera] "
        )

    history = req.history[-req.max_turns :]
    messages = [
        {"role": turn.role, "content": turn.content}
        for turn in history
    ]

    user_message = req.message
    if context_prefix:
        user_message = context_prefix + user_message

    messages.append({"role": "user", "content": user_message})
    return messages


def _extract_reply(data: object) -> tuple[str, int]:
    if isinstance(data, dict):
        choices = data.get("choices")
        if isinstance(choices, list) and choices:
            first_choice = choices[0]
            if isinstance(first_choice, dict):
                message = first_choice.get("message")
                if isinstance(message, dict):
                    content = message.get("content")
                    if isinstance(content, str) and content.strip():
                        usage = data.get("usage", {})
                        if not isinstance(usage, dict):
                            usage = {}
                        tokens = int(usage.get("total_tokens", 0) or 0)
                        return content.strip(), tokens

        generated_text = data.get("generated_text")
        if isinstance(generated_text, str) and generated_text.strip():
            return generated_text.strip(), 0

        error = data.get("error")
        if isinstance(error, str) and error.strip():
            raise HTTPException(status_code=502, detail=error.strip())

    if isinstance(data, list) and data:
        first_item = data[0]
        if isinstance(first_item, dict):
            generated_text = first_item.get("generated_text")
            if isinstance(generated_text, str) and generated_text.strip():
                return generated_text.strip(), 0

    raise HTTPException(status_code=502, detail="Hugging Face returned no usable reply")


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    if not HUGGING_FACE_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="HUGGING_FACE_API_KEY not configured. Set it in backend environment variables.",
        )

    payload = {
        "model": HUGGING_FACE_MODEL,
        "messages": [
            {"role": "system", "content": FARMING_SYSTEM_PROMPT},
            *_build_messages(req),
        ],
        "max_tokens": 1024,
        "temperature": 0.4,
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                HUGGING_FACE_API_URL,
                headers={
                    "Authorization": f"Bearer {HUGGING_FACE_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            response.raise_for_status()
            data = response.json()

        reply, tokens = _extract_reply(data)
        logger.info(
            "Hugging Face chat reply generated: model=%s tokens=%s lang=%s",
            HUGGING_FACE_MODEL,
            tokens,
            req.language,
        )
        return ChatResponse(reply=reply, language=req.language, tokens=tokens)
    except httpx.HTTPStatusError as exc:
        logger.error(
            "Hugging Face API HTTP error: %s - %s",
            exc.response.status_code,
            exc.response.text,
        )
        raise HTTPException(status_code=502, detail="AI service temporarily unavailable")
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Chat error: %s", exc)
        raise HTTPException(status_code=500, detail="Internal server error")


class QuickAskRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=4000)
    language: str = Field(default="en", min_length=2, max_length=10)
    disease: Optional[str] = Field(default=None, max_length=80)
    crop: Optional[str] = Field(default=None, max_length=80)


@router.post("/quick-ask")
async def quick_ask(req: QuickAskRequest) -> ChatResponse:
    context = ""
    if req.disease:
        context += f"The farmer's plant has been diagnosed with {req.disease}. "
    if req.crop:
        context += f"The affected crop is {req.crop}. "

    return await chat(
        ChatRequest(
            message=context + req.question,
            language=req.language,
            history=[],
        )
    )
