import logging
import os
import re
from typing import List, Optional, Tuple

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

SUPPORTED_CHAT_LANGUAGES = {"en", "hi", "pa"}
LOCALIZATION_LANGUAGES = {"hi", "pa"}
LANGUAGE_NAMES = {
    "en": "English",
    "hi": "Hindi",
    "pa": "Punjabi",
}
SCRIPT_NAMES = {
    "hi": "Devanagari script",
    "pa": "Gurmukhi script",
}

ENGLISH_PLANNER_PROMPT = """You are a careful agricultural assistant for Indian farmers.
Do all reasoning in English and return only the final English answer.

Rules:
- Be practical, brief, and respectful.
- Prefer 2 to 4 short bullets, or 1 to 2 short clarifying questions.
- If crop, crop stage, location, or visible symptom is missing for fertilizer, pesticide, spray, disease, or irrigation advice, ask for that missing detail instead of guessing.
- Never invent product names, doses, spray schedules, waiting periods, or field records.
- If you are unsure, clearly say what detail is missing.
- Stay focused on Indian farming conditions when relevant.

Use these grounding notes when they help:
{grounding_notes}
"""

LOCALIZATION_PROMPT_TEMPLATE = """You are translating farming advice for Indian farmers.
Translate the English source into natural {language_name} written only in {script_name}.

Rules:
- Keep the meaning exact.
- Keep the same safety level.
- Use short farmer-friendly sentences.
- Do not add new facts, doses, brands, or chemicals.
- Do not transliterate full sentences into another script.
- Return only the translated answer.
"""

SCRIPT_PATTERNS = {
    "hi": re.compile(r"[\u0900-\u097F]"),
    "pa": re.compile(r"[\u0A00-\u0A7F]"),
}

INTENT_KEYWORDS = {
    "fertilizer": {
        "fertilizer",
        "fertiliser",
        "urea",
        "dap",
        "npk",
        "potash",
        "manure",
        "khad",
    },
    "pesticide": {
        "pesticide",
        "spray",
        "fungicide",
        "herbicide",
        "insecticide",
        "medicine",
        "dose",
        "dosage",
        "quantity",
    },
    "irrigation": {
        "water",
        "irrigation",
        "drip",
        "sprinkler",
        "watering",
    },
    "weather": {
        "weather",
        "rain",
        "rainfall",
        "temperature",
        "humidity",
        "forecast",
    },
    "disease": {
        "disease",
        "blight",
        "rust",
        "spot",
        "virus",
        "fungus",
        "mold",
        "symptom",
        "leaf curl",
    },
}

CROP_KEYWORDS = {
    "wheat": {"wheat", "gehun", "gehu", "kanak"},
    "rice": {"rice", "paddy", "dhan"},
    "maize": {"maize", "corn", "makka"},
    "cotton": {"cotton"},
    "tomato": {"tomato"},
    "potato": {"potato", "aloo"},
    "sugarcane": {"sugarcane", "ganna"},
    "mustard": {"mustard", "sarson"},
    "chickpea": {"chickpea", "gram", "chana"},
}

CROP_GROUNDING = {
    "wheat": [
        "Wheat is usually a rabi crop.",
        "Important irrigation stages often include crown root initiation, booting, and grain filling.",
        "Avoid giving exact fertilizer doses unless growth stage or soil status is known.",
    ],
    "rice": [
        "Rice usually needs water management advice that depends on transplanting or direct seeding stage.",
        "Standing water guidance depends on field stage and local rainfall.",
    ],
    "tomato": [
        "Tomato disease and spray advice depends heavily on visible symptom and crop stage.",
        "Avoid wet foliage when fungal disease risk is high.",
    ],
    "cotton": [
        "Cotton pest advice depends on pest identity and infestation level.",
        "Avoid brand-specific spray recommendations without confirmed pest details.",
    ],
}

INTENT_GROUNDING = {
    "fertilizer": [
        "Balanced nutrition is safer than talking only about urea.",
        "Crop, growth stage, and soil condition are required before giving specific fertilizer advice.",
    ],
    "pesticide": [
        "Integrated pest management comes before chemical advice.",
        "Confirmed crop, pest, and infestation details are required before any spray recommendation.",
    ],
    "irrigation": [
        "Irrigation advice depends on crop and crop stage.",
        "Critical stages are usually more important than a fixed calendar schedule.",
    ],
    "weather": [
        "Weather advice should be localized to village, district, or nearest town.",
    ],
    "disease": [
        "Disease advice depends on crop and visible symptom.",
        "When diagnosis is uncertain, ask for symptom details or camera result first.",
    ],
}


class ChatTurn(BaseModel):
    role: str = Field(..., min_length=1, max_length=20)
    content: str = Field(..., min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    language: str = Field(default="en", min_length=2, max_length=10)
    history: List[ChatTurn] = Field(default_factory=list)
    location: Optional[str] = Field(default=None, max_length=120)
    crop_context: Optional[str] = Field(default=None, max_length=80)
    max_turns: int = Field(default=10, ge=1, le=10)


class ChatResponse(BaseModel):
    reply: str
    language: str
    tokens: int


class QuickAskRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=4000)
    language: str = Field(default="en", min_length=2, max_length=10)
    disease: Optional[str] = Field(default=None, max_length=80)
    crop: Optional[str] = Field(default=None, max_length=80)


def _normalize_language(language: str) -> str:
    normalized = (language or "en").strip().lower()
    if "-" in normalized:
        normalized = normalized.split("-", 1)[0]
    return normalized or "en"


def _resolve_chat_language(language: str) -> str:
    normalized = _normalize_language(language)
    if normalized in SUPPORTED_CHAT_LANGUAGES:
        return normalized
    logger.warning(
        "Unsupported chatbot language '%s'; falling back to English.",
        normalized,
    )
    return "en"


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
    messages = [{"role": turn.role, "content": turn.content} for turn in history]

    user_message = req.message
    if context_prefix:
        user_message = context_prefix + user_message

    messages.append({"role": "user", "content": user_message})
    return messages


def _extract_reply(data: object) -> Tuple[str, int]:
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


def _normalize_reply(reply: str) -> str:
    cleaned = reply.strip()
    cleaned = re.sub(r"^(assistant|answer)\s*:\s*", "", cleaned, flags=re.IGNORECASE)
    return cleaned.strip()


def _tokenize(text: str) -> List[str]:
    return [token for token in re.findall(r"\w+", text.lower()) if len(token) > 1]


def _has_severe_repetition(reply: str) -> bool:
    tokens = _tokenize(reply)
    if len(tokens) < 5:
        return False

    adjacent_repeats = sum(
        1 for previous, current in zip(tokens, tokens[1:]) if previous == current
    )
    counts = {token: tokens.count(token) for token in set(tokens)}
    most_frequent = max(counts.values(), default=0)
    repeated_token_dominates = most_frequent >= 3 and most_frequent >= (
        len(tokens) + 2
    ) // 3
    return adjacent_repeats > 0 or repeated_token_dominates


def _has_expected_script(reply: str, language: str) -> bool:
    pattern = SCRIPT_PATTERNS.get(language)
    if pattern is None:
        return True
    return bool(pattern.search(reply))


def _latin_char_count(reply: str) -> int:
    return len(re.findall(r"[A-Za-z]", reply))


def _reply_quality_is_acceptable(reply: str, language: str) -> bool:
    if not reply.strip():
        return False
    if _has_severe_repetition(reply):
        return False
    if not _has_expected_script(reply, language):
        return False

    if language in LOCALIZATION_LANGUAGES:
        target_script_chars = len(SCRIPT_PATTERNS[language].findall(reply))
        if target_script_chars < 8:
            return False
        if _latin_char_count(reply) > target_script_chars // 2 + 10:
            return False
    return True


def _english_reply_is_acceptable(reply: str) -> bool:
    if not reply.strip():
        return False
    if _has_severe_repetition(reply):
        return False
    if re.search(r"[\u0900-\u0A7F]", reply):
        return False
    return True


def _keyword_matches(text: str, keywords: set[str]) -> bool:
    lowered = text.lower()
    return any(keyword in lowered for keyword in keywords)


def _detect_intent(text: str) -> str:
    lowered = text.lower()
    for intent, keywords in INTENT_KEYWORDS.items():
        if _keyword_matches(lowered, keywords):
            return intent
    return "general"


def _detect_crop(text: str, crop_context: Optional[str]) -> Optional[str]:
    combined = " ".join(part for part in [text, crop_context or ""] if part).lower()
    for crop, keywords in CROP_KEYWORDS.items():
        if _keyword_matches(combined, keywords):
            return crop
    return None


def _build_grounding_notes(
    req: ChatRequest, crop: Optional[str], intent: str
) -> List[str]:
    notes: List[str] = []
    if crop and crop in CROP_GROUNDING:
        notes.extend(CROP_GROUNDING[crop])
    if intent in INTENT_GROUNDING:
        notes.extend(INTENT_GROUNDING[intent])
    if req.location:
        notes.append(f"Farmer location provided in chat context: {req.location}.")
    if req.crop_context:
        notes.append(f"Camera context provided by app: {req.crop_context}.")
    if not notes:
        notes.append("No extra grounding note is available. Stay cautious and ask for missing details.")
    return notes


def _build_safe_fallback(req: ChatRequest) -> Optional[str]:
    language = _normalize_language(req.language)
    crop = _detect_crop(req.message, req.crop_context)
    intent = _detect_intent(req.message)
    has_location = bool((req.location or "").strip())

    if intent == "weather" and not has_location:
        return {
            "en": "To give weather-based advice, tell me your village, district, or nearest town first.",
            "hi": "मौसम के आधार पर सही सलाह देने के लिए अपना गांव, जिला या नजदीकी कस्बा बताइए।",
            "pa": "ਮੌਸਮ ਦੇ ਆਧਾਰ ਤੇ ਸਹੀ ਸਲਾਹ ਲਈ ਆਪਣਾ ਪਿੰਡ, ਜ਼ਿਲ੍ਹਾ ਜਾਂ ਨਜ਼ਦੀਕੀ ਸ਼ਹਿਰ ਦੱਸੋ।",
        }.get(language, "To give weather-based advice, tell me your village, district, or nearest town first.")

    if intent in {"fertilizer", "pesticide", "disease", "irrigation"} and not crop:
        return {
            "en": "Please tell me the crop first. If possible also share the crop stage, the main symptom or pest, and your location.",
            "hi": "पहले फसल का नाम बताइए। अगर संभव हो तो फसल की अवस्था, मुख्य लक्षण या कीट, और अपना स्थान भी बताइए।",
            "pa": "ਪਹਿਲਾਂ ਫਸਲ ਦਾ ਨਾਮ ਦੱਸੋ। ਜੇ ਸੰਭਵ ਹੋਵੇ ਤਾਂ ਫਸਲ ਦੀ ਅਵਸਥਾ, ਮੁੱਖ ਲੱਛਣ ਜਾਂ ਕੀਟ, ਅਤੇ ਆਪਣਾ ਸਥਾਨ ਵੀ ਦੱਸੋ।",
        }.get(language, "Please tell me the crop first.")

    if intent in {"fertilizer", "pesticide", "irrigation"} and crop:
        return {
            "en": f"For safer advice for {crop}, tell me the crop stage and the exact issue first.",
            "hi": f"{crop} के लिए सुरक्षित सलाह देने से पहले फसल की अवस्था और सही समस्या बताइए।",
            "pa": f"{crop} ਲਈ ਸੁਰੱਖਿਅਤ ਸਲਾਹ ਤੋਂ ਪਹਿਲਾਂ ਫਸਲ ਦੀ ਅਵਸਥਾ ਅਤੇ ਅਸਲੀ ਸਮੱਸਿਆ ਦੱਸੋ।",
        }.get(language, f"For safer advice for {crop}, tell me the crop stage and the exact issue first.")

    return None


def _build_planner_prompt(req: ChatRequest, crop: Optional[str], intent: str) -> str:
    grounding_notes = "\n".join(f"- {note}" for note in _build_grounding_notes(req, crop, intent))
    return ENGLISH_PLANNER_PROMPT.format(grounding_notes=grounding_notes)


def _build_localizer_prompt(language: str) -> str:
    return LOCALIZATION_PROMPT_TEMPLATE.format(
        language_name=LANGUAGE_NAMES[language],
        script_name=SCRIPT_NAMES[language],
    )


async def _call_hugging_face(
    client: httpx.AsyncClient,
    *,
    system_prompt: str,
    messages: List[dict[str, str]],
    max_tokens: int = 512,
    temperature: float = 0.3,
) -> Tuple[str, int]:
    payload = {
        "model": HUGGING_FACE_MODEL,
        "messages": [{"role": "system", "content": system_prompt}, *messages],
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    response = await client.post(
        HUGGING_FACE_API_URL,
        headers={
            "Authorization": f"Bearer {HUGGING_FACE_API_KEY}",
            "Content-Type": "application/json",
        },
        json=payload,
    )
    response.raise_for_status()
    reply, tokens = _extract_reply(response.json())
    return _normalize_reply(reply), tokens


async def _generate_multilingual_reply(
    client: httpx.AsyncClient, req: ChatRequest
) -> Tuple[str, int]:
    language = _normalize_language(req.language)
    crop = _detect_crop(req.message, req.crop_context)
    intent = _detect_intent(req.message)

    safe_fallback = _build_safe_fallback(req)
    if safe_fallback:
        return safe_fallback, 0

    english_reply, english_tokens = await _call_hugging_face(
        client,
        system_prompt=_build_planner_prompt(req, crop, intent),
        messages=_build_messages(req),
        max_tokens=400,
        temperature=0.25,
    )

    if not _english_reply_is_acceptable(english_reply):
        logger.warning(
            "Rejecting weak English planner output before localization: %r",
            english_reply[:400],
        )
        return (
            _build_safe_fallback(req)
            or "Please tell me the crop, crop stage, symptom, and location so I can give safer advice.",
            english_tokens,
        )

    localized_reply, localized_tokens = await _call_hugging_face(
        client,
        system_prompt=_build_localizer_prompt(language),
        messages=[
            {
                "role": "user",
                "content": (
                    f"Translate this farming answer into natural {LANGUAGE_NAMES[language]}.\n\n"
                    f"English source:\n{english_reply}"
                ),
            }
        ],
        max_tokens=420,
        temperature=0.2,
    )

    if not _reply_quality_is_acceptable(localized_reply, language):
        logger.warning(
            "Rejecting low-quality localized reply: lang=%s reply=%r",
            language,
            localized_reply[:400],
        )
        return (
            _build_safe_fallback(req)
            or {
                "hi": "कृपया फसल, उसकी अवस्था, मुख्य लक्षण और अपना स्थान बताइए ताकि मैं सुरक्षित सलाह दे सकूं।",
                "pa": "ਕਿਰਪਾ ਕਰਕੇ ਫਸਲ, ਉਸ ਦੀ ਅਵਸਥਾ, ਮੁੱਖ ਲੱਛਣ ਅਤੇ ਆਪਣਾ ਸਥਾਨ ਦੱਸੋ ਤਾਂ ਜੋ ਮੈਂ ਸੁਰੱਖਿਅਤ ਸਲਾਹ ਦੇ ਸਕਾਂ।",
            }[language],
            english_tokens + localized_tokens,
        )

    return localized_reply, english_tokens + localized_tokens


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest) -> ChatResponse:
    if not HUGGING_FACE_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="HUGGING_FACE_API_KEY not configured. Set it in backend environment variables.",
        )

    language = _resolve_chat_language(req.language)

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            if language in LOCALIZATION_LANGUAGES:
                reply, tokens = await _generate_multilingual_reply(client, req)
            else:
                crop = _detect_crop(req.message, req.crop_context)
                intent = _detect_intent(req.message)
                reply, tokens = await _call_hugging_face(
                    client,
                    system_prompt=_build_planner_prompt(req, crop, intent),
                    messages=_build_messages(req),
                    max_tokens=512,
                    temperature=0.25,
                )
                if not _english_reply_is_acceptable(reply):
                    raise HTTPException(
                        status_code=502,
                        detail="AI reply quality was too low for the requested language",
                    )

        logger.info(
            "Hugging Face chat reply generated: model=%s tokens=%s lang=%s",
            HUGGING_FACE_MODEL,
            tokens,
            language,
        )
        return ChatResponse(reply=reply, language=language, tokens=tokens)
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
