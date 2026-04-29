import logging
import os
from typing import List, Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

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
in Hindi. If Punjabi, respond in Punjabi. Use simple language; avoid technical jargon
unless the farmer seems educated. Use examples from their local context.

RESPONSE STYLE:
- Be warm, respectful, and encouraging like a trusted village agricultural officer
- Give practical, actionable advice with specific quantities when relevant
- Mention both chemical and natural alternatives when relevant
- If a question is unclear, ask one focused clarifying question
- If you detect an urgent disease or pest situation, say so clearly and give immediate steps
- Always mention safety precautions when recommending pesticides

WHAT YOU CANNOT DO:
- You cannot see images directly in chat
- You cannot give 100% guaranteed predictions
- You do not provide veterinary advice

Always end responses with a helpful follow-up question or suggestion."""


class ChatTurn(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    language: str = "en"
    history: List[ChatTurn] = []
    location: Optional[str] = None
    crop_context: Optional[str] = None
    max_turns: int = 10


class ChatResponse(BaseModel):
    reply: str
    language: str
    tokens: int


def _build_messages(req: ChatRequest) -> list[dict[str, str]]:
    context_prefix = ""
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
        raise HTTPException(status_code=500, detail=str(exc))


class QuickAskRequest(BaseModel):
    question: str
    language: str = "en"
    disease: Optional[str] = None
    crop: Optional[str] = None


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
