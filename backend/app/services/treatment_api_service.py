# ─────────────────────────────────────────────
# backend/app/services/treatment_api_service.py
#
# Fetches treatment information from real APIs:
#   1. CABI Crop Protection Compendium (primary)
#   2. EPPO Global Database (secondary)
#   3. USDA PLANTS API (fallback)
#
# On first call, fetches and caches to
# assets/data/treatments.json so the app
# can use it offline after first sync.
# ─────────────────────────────────────────────

import os
import json
import logging
import httpx
import asyncio
from pathlib import Path
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# ── API configuration ─────────────────────────
CABI_API_KEY = os.getenv("CABI_API_KEY", "")  # register at cabi.org

REPO_ROOT = Path(__file__).resolve().parents[3]
CACHE_PATH = REPO_ROOT / "plant_disease_app" / "assets" / "data" / "treatments.json"
CACHE_TTL_DAYS = 7   # Refresh treatments weekly

_logged_missing_cabi_key = False
_logged_eppo_unavailable = False


def _log_missing_cabi_key_once() -> None:
    global _logged_missing_cabi_key
    if _logged_missing_cabi_key:
        return
    logger.warning(
        "CABI_API_KEY not set; skipping live CABI treatment sync and using fallback data.",
    )
    _logged_missing_cabi_key = True


def _log_eppo_unavailable_once() -> None:
    global _logged_eppo_unavailable
    if _logged_eppo_unavailable:
        return
    logger.warning(
        "EPPO live treatment sync is disabled because the configured datasheet endpoint returns 404 responses. Using fallback data instead.",
    )
    _logged_eppo_unavailable = True


# ─────────────────────────────────────────────
# Disease name → API search terms
# ─────────────────────────────────────────────
DISEASE_QUERIES = {
    "early_blight": {
        "common":    "Early Blight",
        "scientific":"Alternaria solani",
        "eppo_code": "ALTESO",
        "crops":     ["tomato", "potato"],
    },
    "late_blight": {
        "common":    "Late Blight",
        "scientific":"Phytophthora infestans",
        "eppo_code": "PHYTIN",
        "crops":     ["tomato", "potato"],
    },
    "leaf_mold": {
        "common":    "Leaf Mould",
        "scientific":"Passalora fulva",
        "eppo_code": "CLAFUL",
        "crops":     ["tomato"],
    },
    "leaf_blast": {
        "common":    "Rice Blast",
        "scientific":"Magnaporthe oryzae",
        "eppo_code": "PYRIOR",
        "crops":     ["rice"],
    },
    "brown_spot": {
        "common":    "Brown Spot",
        "scientific":"Cochliobolus miyabeanus",
        "eppo_code": "HELMMI",
        "crops":     ["rice"],
    },
    "healthy": {
        "common":    "Healthy",
        "scientific":"",
        "eppo_code": "",
        "crops":     [],
    },
}


# ─────────────────────────────────────────────
# CABI API — primary treatment source
# https://www.cabi.org/publishing-products/crop-protection-compendium/
# ─────────────────────────────────────────────

async def fetch_cabi_treatment(disease_key: str) -> dict | None:
    """
    Queries CABI Crop Protection Compendium API.
    Returns structured treatment data including chemical and biological options.
    Register for free academic API key at: https://www.cabi.org/contact/
    """
    if not CABI_API_KEY:
        logger.warning("CABI_API_KEY not set — skipping CABI fetch")
        return None

    query = DISEASE_QUERIES.get(disease_key, {})
    if not query.get("scientific"):
        return None

    url = "https://api.cabi.org/cpc/datasheet"
    headers = {
        "Authorization": f"Bearer {CABI_API_KEY}",
        "Accept":        "application/json",
    }
    params = {
        "q":      query["scientific"],
        "type":   "pest",
        "fields": "management,chemical_control,biological_control,symptoms",
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(url, headers=headers, params=params)
            resp.raise_for_status()
            data = resp.json()

        if not data.get("results"):
            return None

        result = data["results"][0]
        return {
            "source":              "CABI Crop Protection Compendium",
            "disease_name":        result.get("common_name", query["common"]),
            "pathogen":            result.get("scientific_name", query["scientific"]),
            "symptoms":            result.get("symptoms", ""),
            "chemical_treatment":  result.get("chemical_control", ""),
            "biological_treatment":result.get("biological_control", ""),
            "cultural_management": result.get("management", ""),
            "fetched_at":          datetime.utcnow().isoformat(),
        }
    except Exception as e:
        logger.error(f"CABI API error for {disease_key}: {e}")
        return None


# ─────────────────────────────────────────────
# EPPO Global Database — secondary source
# https://gd.eppo.int/  (free, no key needed for basic queries)
# ─────────────────────────────────────────────

async def fetch_eppo_treatment(disease_key: str) -> dict | None:
    """
    Queries EPPO Global Database for pest/disease information.
    EPPO is the European Plant Protection Organization — excellent
    scientific accuracy for fungal and bacterial diseases.
    Free tier available at: https://gd.eppo.int/user/register
    """
    query = DISEASE_QUERIES.get(disease_key, {})
    eppo_code = query.get("eppo_code")
    if not eppo_code:
        return None

    base_url = "https://gd.eppo.int/api"
    headers  = {}
    if EPPO_API_KEY:
        headers["Authorization"] = f"token {EPPO_API_KEY}"

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            # Fetch datasheet
            resp = await client.get(
                f"{base_url}/taxon/{eppo_code}/datasheet",
                headers=headers,
            )
            resp.raise_for_status()
            data = resp.json()

        # Extract relevant sections
        management = ""
        for section in data.get("sections", []):
            title = section.get("title", "").lower()
            if any(t in title for t in ("control", "management", "treatment")):
                management += section.get("content", "") + "\n"

        if not management:
            return None

        return {
            "source":   "EPPO Global Database",
            "eppo_code":eppo_code,
            "treatment":management.strip()[:1500],   # Cap length
            "fetched_at":datetime.utcnow().isoformat(),
        }
    except Exception as e:
        logger.error(f"EPPO API error for {disease_key}: {e}")
        return None


# ─────────────────────────────────────────────
# Merge API data with hardcoded fallback
# ─────────────────────────────────────────────

def build_treatment_entry(
    disease_key: str,
    cabi_data:   dict | None,
    eppo_data:   dict | None,
) -> dict:
    """
    Combines API results with high-quality hardcoded fallback.
    API data is shown when available; fallback used if API fails.
    """
    fallback = _hardcoded_treatments()[disease_key]

    # Prefer CABI (most detailed), then EPPO, then fallback
    if cabi_data:
        treatment_en = (
            f"Disease: {cabi_data['disease_name']} ({cabi_data['pathogen']})\n\n"
            f"Symptoms: {cabi_data['symptoms']}\n\n"
            f"Chemical control: {cabi_data['chemical_treatment']}\n\n"
            f"Biological control: {cabi_data['biological_treatment']}\n\n"
            f"Cultural management: {cabi_data['cultural_management']}"
        ).strip()
        source = "CABI CPC"
    elif eppo_data:
        treatment_en = eppo_data["treatment"]
        source       = "EPPO GD"
    else:
        treatment_en = fallback["en"]["treatment"]
        source       = "built-in"

    return {
        "en": {
            "name":      fallback["en"]["name"],
            "pathogen":  fallback["en"]["pathogen"],
            "symptoms":  fallback["en"]["symptoms"],
            "treatment": treatment_en,
            "severity":  fallback["en"]["severity"],
            "source":    source,
        },
        "hi": fallback["hi"],
        "pa": fallback["pa"],
        "_last_updated": datetime.utcnow().isoformat(),
    }


# ─────────────────────────────────────────────
# Main: fetch all treatments and save to JSON
# ─────────────────────────────────────────────

async def refresh_treatments_json() -> dict:
    """
    Fetches all disease treatments from APIs and saves to
    assets/data/treatments.json for offline use in the app.
    Called by the backend on startup and weekly thereafter.
    """
    logger.info("Refreshing treatments from APIs...")
    treatments = {}

    for disease_key in DISEASE_QUERIES:
        if disease_key == "healthy":
            treatments[disease_key] = _hardcoded_treatments()[disease_key]
            continue

        logger.info(f"  Fetching: {disease_key}")

        # Fetch from both APIs concurrently
        cabi_data, eppo_data = await asyncio.gather(
            fetch_cabi_treatment(disease_key),
            fetch_eppo_treatment(disease_key),
            return_exceptions=False,
        )

        treatments[disease_key] = build_treatment_entry(disease_key, cabi_data, eppo_data)
        logger.info(f"  ✅ {disease_key} → source: {treatments[disease_key]['en']['source']}")

    # Save to JSON for offline use
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        json.dump(treatments, f, ensure_ascii=False, indent=2)

    logger.info(f"Treatments saved to {CACHE_PATH}")
    return treatments


def should_refresh() -> bool:
    """Returns True if treatments.json is missing or older than TTL."""
    if not CACHE_PATH.exists():
        return True
    mtime = datetime.fromtimestamp(CACHE_PATH.stat().st_mtime)
    return datetime.now() - mtime > timedelta(days=CACHE_TTL_DAYS)


def load_treatments() -> dict:
    """Load treatments from cache, or return hardcoded fallback."""
    if CACHE_PATH.exists():
        with open(CACHE_PATH, encoding="utf-8") as f:
            return json.load(f)
    return _hardcoded_treatments()


# Runtime overrides for deployment-safe treatment sync behavior.
REPO_ROOT = Path(__file__).resolve().parents[3]
CACHE_PATH = REPO_ROOT / "plant_disease_app" / "assets" / "data" / "treatments.json"
_logged_missing_cabi_key = False
_logged_eppo_unavailable = False


def _log_missing_cabi_key_once() -> None:
    global _logged_missing_cabi_key
    if _logged_missing_cabi_key:
        return
    logger.warning(
        "CABI_API_KEY not set; skipping live CABI treatment sync and using fallback data.",
    )
    _logged_missing_cabi_key = True


def _log_eppo_unavailable_once() -> None:
    global _logged_eppo_unavailable
    if _logged_eppo_unavailable:
        return
    logger.warning(
        "EPPO live treatment sync is disabled because the configured datasheet endpoint returns 404 responses. Using fallback data instead.",
    )
    _logged_eppo_unavailable = True


async def fetch_cabi_treatment(disease_key: str) -> dict | None:
    if not CABI_API_KEY:
        _log_missing_cabi_key_once()
        return None

    query = DISEASE_QUERIES.get(disease_key, {})
    if not query.get("scientific"):
        return None

    url = "https://api.cabi.org/cpc/datasheet"
    headers = {
        "Authorization": f"Bearer {CABI_API_KEY}",
        "Accept": "application/json",
    }
    params = {
        "q": query["scientific"],
        "type": "pest",
        "fields": "management,chemical_control,biological_control,symptoms",
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(url, headers=headers, params=params)
            resp.raise_for_status()
            data = resp.json()

        if not data.get("results"):
            return None

        result = data["results"][0]
        return {
            "source": "CABI Crop Protection Compendium",
            "disease_name": result.get("common_name", query["common"]),
            "pathogen": result.get("scientific_name", query["scientific"]),
            "symptoms": result.get("symptoms", ""),
            "chemical_treatment": result.get("chemical_control", ""),
            "biological_treatment": result.get("biological_control", ""),
            "cultural_management": result.get("management", ""),
            "fetched_at": datetime.utcnow().isoformat(),
        }
    except Exception as exc:
        logger.error("CABI API error for %s: %s", disease_key, exc)
        return None


async def fetch_eppo_treatment(disease_key: str) -> dict | None:
    if disease_key not in DISEASE_QUERIES:
        return None
    _log_eppo_unavailable_once()
    return None


def load_treatments() -> dict:
    if CACHE_PATH.exists():
        try:
            with open(CACHE_PATH, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            logger.warning("Failed to read cached treatments from %s: %s", CACHE_PATH, exc)
    return _hardcoded_treatments()


# ─────────────────────────────────────────────
# High-quality hardcoded fallback
# (used when APIs are unavailable)
# ─────────────────────────────────────────────

def _hardcoded_treatments() -> dict:
    return {
        "early_blight": {
            "en": {
                "name": "Early Blight",
                "pathogen": "Alternaria solani",
                "symptoms": "Concentric brown rings on lower leaves forming a target-board pattern. Yellow halo around lesions. Starts on oldest leaves, moves upward.",
                "treatment": (
                    "1. Apply Chlorothalonil 75WP @ 2g/L or Mancozeb 75WP @ 2.5g/L every 7-10 days.\n"
                    "2. Remove and destroy all infected leaves immediately — do not compost.\n"
                    "3. Switch to drip or furrow irrigation — keep foliage dry.\n"
                    "4. Apply copper oxychloride 50WP @ 3g/L as a preventive spray.\n"
                    "5. Maintain good plant spacing (50-60cm) for air circulation.\n"
                    "6. Rotate with non-solanaceous crops for minimum 3 years.\n"
                    "Organic option: Neem oil 2ml/L + baking soda 5g/L spray weekly."
                ),
                "severity": "moderate",
                "source": "built-in",
            },
            "hi": {
                "treatment": (
                    "1. क्लोरोथैलोनिल 75WP @ 2g/L या मैनकोजेब 75WP @ 2.5g/L हर 7-10 दिन में लगाएं।\n"
                    "2. सभी संक्रमित पत्तियां तुरंत हटाएं और नष्ट करें।\n"
                    "3. ड्रिप सिंचाई का उपयोग करें — पत्तियों को गीला न करें।\n"
                    "4. कॉपर ऑक्सीक्लोराइड @ 3g/L निवारक स्प्रे के रूप में लगाएं।"
                )
            },
            "pa": {
                "treatment": (
                    "1. ਕਲੋਰੋਥੈਲੋਨਿਲ @ 2g/L ਹਰ 7-10 ਦਿਨਾਂ ਵਿੱਚ ਲਗਾਓ।\n"
                    "2. ਸੰਕ੍ਰਮਿਤ ਪੱਤੇ ਤੁਰੰਤ ਹਟਾਓ।\n"
                    "3. ਡ੍ਰਿਪ ਸਿੰਚਾਈ ਵਰਤੋ।"
                )
            },
        },
        "late_blight": {
            "en": {
                "name": "Late Blight",
                "pathogen": "Phytophthora infestans",
                "symptoms": "Water-soaked grey-green patches on leaves rapidly turning brown-black. White mold visible on leaf undersides in humid conditions. Can destroy entire field in 5-7 days.",
                "treatment": (
                    "1. EMERGENCY: Apply Metalaxyl + Mancozeb (Ridomil Gold) @ 2.5g/L immediately.\n"
                    "2. Also apply Dimethomorph 50WP @ 1g/L as alternate spray.\n"
                    "3. Spray Copper Oxychloride 50WP @ 3g/L preventively before disease appears.\n"
                    "4. Drain waterlogged fields — Phytophthora thrives in wet conditions.\n"
                    "5. Remove and bury (do NOT compost) all infected material.\n"
                    "6. Avoid nitrogen excess — promotes lush growth susceptible to disease.\n"
                    "7. Use resistant varieties: Arka Rakshak (tomato), Kufri Girdhari (potato)."
                ),
                "severity": "high",
                "source": "built-in",
            },
            "hi": {
                "treatment": (
                    "1. आपातकाल: मेटालैक्सिल + मैनकोजेब @ 2.5g/L तुरंत लगाएं।\n"
                    "2. जलभराव वाले क्षेत्रों को तुरंत निकालें।\n"
                    "3. सभी संक्रमित सामग्री को हटाकर दफनाएं।\n"
                    "4. प्रतिरोधी किस्में उगाएं: अर्का रक्षक (टमाटर)।"
                )
            },
            "pa": {
                "treatment": (
                    "1. ਐਮਰਜੈਂਸੀ: ਮੈਟਲਐਕਸਿਲ @ 2.5g/L ਤੁਰੰਤ ਲਗਾਓ।\n"
                    "2. ਪਾਣੀ ਭਰੇ ਖੇਤਾਂ ਤੋਂ ਪਾਣੀ ਕੱਢੋ।\n"
                    "3. ਸੰਕ੍ਰਮਿਤ ਪੌਦੇ ਦੱਬ ਦਿਓ।"
                )
            },
        },
        "leaf_mold": {
            "en": {
                "name": "Leaf Mold",
                "pathogen": "Passalora fulva (syn. Cladosporium fulvum)",
                "symptoms": "Pale yellow spots on upper leaf surface. Olive-grey to brown velvety mold on lower surface. Mainly affects greenhouse tomatoes. Leaves curl and drop.",
                "treatment": (
                    "1. Reduce greenhouse humidity below 85% — improve ventilation urgently.\n"
                    "2. Apply Propiconazole 25EC @ 1ml/L or Hexaconazole 5SC @ 2ml/L.\n"
                    "3. Alternatively spray Sulfur 80WP @ 3g/L or Mancozeb 75WP @ 2.5g/L.\n"
                    "4. Remove infected leaves and dispose outside the greenhouse.\n"
                    "5. Water in the morning so leaves dry before evening.\n"
                    "6. Increase plant spacing to minimum 50-60cm."
                ),
                "severity": "moderate",
                "source": "built-in",
            },
            "hi": {
                "treatment": (
                    "1. ग्रीनहाउस आर्द्रता 85% से कम करें।\n"
                    "2. प्रोपिकोनाज़ोल @ 1ml/L या सल्फर @ 3g/L लगाएं।\n"
                    "3. पौधों के बीच 50-60cm का अंतर रखें।"
                )
            },
            "pa": {
                "treatment": (
                    "1. ਗ੍ਰੀਨਹਾਊਸ ਨਮੀ 85% ਤੋਂ ਘੱਟ ਕਰੋ।\n"
                    "2. ਪ੍ਰੋਪਿਕੋਨਾਜ਼ੋਲ @ 1ml/L ਲਗਾਓ।"
                )
            },
        },
        "leaf_blast": {
            "en": {
                "name": "Rice Blast",
                "pathogen": "Magnaporthe oryzae",
                "symptoms": "Diamond-shaped lesions with grey centres and brown borders on leaves. Neck blast causes panicle death (white ear). Most damaging rice disease globally.",
                "treatment": (
                    "1. Apply Tricyclazole 75WP @ 0.6g/L at tillering and panicle initiation.\n"
                    "2. Alternatively use Isoprothiolane 40EC @ 1.5ml/L.\n"
                    "3. Apply Silicon fertilizer @ 200kg/ha — silicon strengthens cell walls against blast.\n"
                    "4. Avoid excess nitrogen (esp. urea) — lush growth is more susceptible.\n"
                    "5. Drain fields for 3-4 days if blast appears.\n"
                    "6. Use resistant varieties: IR64, Swarna Sub1, MTU-1010."
                ),
                "severity": "high",
                "source": "built-in",
            },
            "hi": {
                "treatment": (
                    "1. ट्राइसाइक्लाज़ोल @ 0.6g/L कल्ले फूटने और बाली निकलने पर लगाएं।\n"
                    "2. अतिरिक्त यूरिया से बचें।\n"
                    "3. प्रतिरोधी किस्में: IR64, स्वर्णा सब1।"
                )
            },
            "pa": {
                "treatment": (
                    "1. ਟ੍ਰਾਈਸਾਈਕਲਾਜ਼ੋਲ @ 0.6g/L ਲਗਾਓ।\n"
                    "2. ਵਾਧੂ ਯੂਰੀਆ ਤੋਂ ਬਚੋ।"
                )
            },
        },
        "brown_spot": {
            "en": {
                "name": "Brown Spot",
                "pathogen": "Cochliobolus miyabeanus",
                "symptoms": "Brown oval spots with yellow halos on leaves. Spots may have grey centres. Grains become discoloured and shrivelled. Often indicates soil nutrient deficiency.",
                "treatment": (
                    "1. Apply Propiconazole 25EC @ 1ml/L or Mancozeb 75WP @ 2.5g/L.\n"
                    "2. Correct potassium deficiency — apply MOP 25kg/acre.\n"
                    "3. Treat seeds with Thiram 75DS @ 3g/kg before sowing.\n"
                    "4. Avoid water stress — brown spot often follows drought.\n"
                    "5. Apply organic matter (FYM) to improve soil health."
                ),
                "severity": "moderate",
                "source": "built-in",
            },
            "hi": {
                "treatment": (
                    "1. प्रोपिकोनाज़ोल @ 1ml/L या मैनकोजेब @ 2.5g/L लगाएं।\n"
                    "2. पोटेशियम की कमी ठीक करें — MOP 25kg/एकड़।"
                )
            },
            "pa": {
                "treatment": (
                    "1. ਪ੍ਰੋਪਿਕੋਨਾਜ਼ੋਲ @ 1ml/L ਲਗਾਓ।\n"
                    "2. ਪੋਟਾਸ਼ੀਅਮ ਦੀ ਕਮੀ ਦੂਰ ਕਰੋ।"
                )
            },
        },
        "healthy": {
            "en": {
                "name": "Healthy Plant",
                "pathogen": "None detected",
                "symptoms": "No disease symptoms. Normal green leaf colour with good texture.",
                "treatment": (
                    "No treatment needed — your plant is healthy!\n\n"
                    "Maintenance tips:\n"
                    "1. Scout fields every 5-7 days for early disease detection.\n"
                    "2. Apply balanced fertilizers as per crop growth stage.\n"
                    "3. Maintain proper irrigation — avoid both drought and waterlogging.\n"
                    "4. Practice crop rotation to break disease cycles.\n"
                    "5. Remove crop debris after harvest to reduce inoculum."
                ),
                "severity": "none",
                "source": "built-in",
            },
            "hi": {
                "treatment": "उपचार की आवश्यकता नहीं! पौधा स्वस्थ है। नियमित निगरानी जारी रखें।"
            },
            "pa": {
                "treatment": "ਇਲਾਜ ਦੀ ਲੋੜ ਨਹੀਂ! ਪੌਦਾ ਸਿਹਤਮੰਦ ਹੈ। ਨਿਯਮਤ ਨਿਗਰਾਨੀ ਕਰਦੇ ਰਹੋ।"
            },
        },
    }
