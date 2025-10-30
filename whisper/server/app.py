import os
import tempfile
import logging
from typing import Dict, List
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel
import requests
import urllib.parse

# =========================================================
# Logging
# =========================================================
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL,
                    format="time=%(asctime)s level=%(levelname)s msg=%(message)s")
logger = logging.getLogger("phowhisper")

# =========================================================
# Config
# =========================================================
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "kiendt/PhoWhisper-large-ct2")
CT2_DEVICE = os.getenv("CT2_DEVICE", "cuda")  # "cuda" | "cpu"
CT2_COMPUTE_TYPE = os.getenv("CT2_COMPUTE_TYPE", "float16")

MAX_UPLOAD_MB = 50
ALLOWED_EXTS = {".wav", ".mp3", ".m4a", ".mp4", ".webm", ".ogg"}

NER_URL = os.getenv("NER_URL", "http://host.docker.internal:8060/ner")
BE_GRAVE_BASE = os.getenv("BE_GRAVE_BASE",
                          "http://host.docker.internal:5000/o")

# =========================================================
# FastAPI
# =========================================================
app = FastAPI(title="Simple PhoWhisper")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"]
)

_model_cache: Dict[str, WhisperModel] = {}


def get_model(model_name: str) -> WhisperModel:
    """Load Whisper model once."""
    if model_name not in _model_cache:
        logger.info("Loading model %s ...", model_name)
        _model_cache[model_name] = WhisperModel(
            model_name, device=CT2_DEVICE, compute_type=CT2_COMPUTE_TYPE
        )
    return _model_cache[model_name]


# =========================================================
# Helper: Gọi NER
# =========================================================
def call_ner_api(text: str) -> List[str]:
    print(">>> [DEBUG] GOING TO NER WITH TEXT:", repr(text))
    try:
        resp = requests.post(NER_URL, json={"text": text}, timeout=5)
        print(">>> [DEBUG] NER STATUS:", resp.status_code)
        print(">>> [DEBUG] NER RAW RESPONSE TEXT:", resp.text)

        resp.raise_for_status()
        data = resp.json()
        persons = data.get("persons", [])
        if isinstance(persons, list):
            return [str(p) for p in persons]
        return []
    except Exception as e:
        logger.error("call_ner_api error: %s", e)
        return []


# =========================================================
# API: audio -> text -> NER -> trả JSON cho BE
# =========================================================
@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile = File(...),
                     model: str = Form(DEFAULT_MODEL)):
    raw = await file.read()
    if not raw:
        raise HTTPException(400, "Empty file")

    suffix = os.path.splitext(file.filename or "")[-1].lower()
    if suffix not in ALLOWED_EXTS:
        raise HTTPException(400, f"Unsupported file: {suffix}")

    if len(raw) > MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(400, f"File too large (> {MAX_UPLOAD_MB}MB)")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(raw)
        tmp_path = tmp.name

    try:
        mdl = get_model(model)
        segments, info = mdl.transcribe(tmp_path, task="transcribe",
                                        language="vi")
        text = " ".join([s.text.strip() for s in segments if s.text]).strip()

        # 1️⃣ Gọi NER
        persons = call_ner_api(text)
        main_person = persons[0] if persons else None

        # 2️⃣ Tạo intent + be_url cho backend
        intent = "o_ten_nguoi_mat" if main_person else None
        be_url = None
        if main_person:
            encoded = urllib.parse.quote(main_person)
            be_url = f"{BE_GRAVE_BASE}?ten_nguoi_mat={encoded}"

        # 3️⃣ In log terminal
        print("\n================ TRANSCRIPT ================")
        print(text)
        print("============== PERSON (PER) ===============")
        print(main_person if main_person else "(không phát hiện tên người)")
        print("============== AI RESP (TO BE) ============")
        print({
            "text": text,
            "intent": intent,
            "be_url": be_url,
            "params": {"person": main_person}
        })
        print("===========================================\n", flush=True)

        # 4️⃣ Trả JSON đúng format BE mong đợi
        return JSONResponse({
            "text": text,
            "intent": intent,
            "be_url": be_url,
            "params": {"person": main_person}
        })

    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


@app.get("/healthz")
def health():
    return {
        "ok": True,
        "model": DEFAULT_MODEL,
        "device": CT2_DEVICE,
        "compute_type": CT2_COMPUTE_TYPE,
        "ner_url": NER_URL,
        "be_grave_base": BE_GRAVE_BASE
    }
