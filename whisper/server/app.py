import os
import re
import tempfile
from urllib.parse import quote
from typing import Optional, Literal, Dict, Any, List

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from faster_whisper import WhisperModel

# --------------------
# Config & Globals
# --------------------
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "Systran/faster-whisper-large-v3")
CT2_DEVICE = os.getenv("CT2_DEVICE", os.getenv("WHISPER__INFERENCE_DEVICE", "cuda"))
CT2_COMPUTE_TYPE = os.getenv("CT2_COMPUTE_TYPE", os.getenv("WHISPER__COMPUTE_TYPE", "float16"))
HF_HOME = os.getenv("HF_HOME", "/root/.cache/huggingface")

# Cho phép "x", "×", "*", "nhân", "by"
ADDR_SEP = r"(?:x|×|\*|nhân|by)"

app = FastAPI(title="Whisper GPU Server (OpenAI-compatible)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# Cache nhiều model trong 1 process
_model_cache: Dict[str, WhisperModel] = {}


def get_model(model_name: str) -> WhisperModel:
    if model_name not in _model_cache:
        _model_cache[model_name] = WhisperModel(
            model_name,
            device=CT2_DEVICE,           # "cuda" | "cpu"
            compute_type=CT2_COMPUTE_TYPE  # "float16" | "int8" | "int8_float16" ...
        )
    return _model_cache[model_name]


# --------------------
# BE routing helpers
# --------------------
def _norm_num(s: str) -> str:
    return s.replace(",", ".").strip()

def _norm_text(t: str) -> str:
    t = t.lower().strip()
    t = t.replace("×", "x")
    t = re.sub(r"\s+", " ", t)
    return t

def extract_khu_hang_o_keywords(text: str):
    """
    Bắt theo từ khóa: khu, hàng/dãy, ô (ưu tiên đúng 'ô' để tránh dính 'hello').
    Hỗ trợ số: 12 hoặc 12.3/12,3.
    """
    t = _norm_text(text)
    num = r"(\d+(?:[.,]\d+)?)"

    khu_pat  = re.compile(rf"\bkhu(?:\s*(?:so|số|vuc|vực))?\s*{num}\b")
    hang_pat = re.compile(rf"\b(?:hang|hàng|day|dãy)\s*{num}\b")
    o_pat    = re.compile(rf"\bô\s*(\d+)\b")  # 'ô' là số nguyên (thường vậy)

    found = {}
    m = khu_pat.search(t)
    if m: found["khu"] = _norm_num(m.group(1))
    m = hang_pat.search(t)
    if m: found["hang"] = _norm_num(m.group(1))
    m = o_pat.search(t)
    if m: found["o"] = _norm_num(m.group(1))
    return found

def extract_addr_hyphen(text: str):
    """
    Bắt địa chỉ dạng gạch nối:
      - 3 phần:  a-b-c  -> ('3', 'a-b-c')
      - 2 phần:  a-b    -> ('2', 'a-b')
    Ưu tiên match 3 phần trước.
    """
    t = _norm_text(text)
    num = r"(\d+(?:[.,]\d+)?)"
    pat3 = re.compile(rf"\b{num}\s*-\s*{num}\s*-\s*(\d+)\b")
    pat2 = re.compile(rf"\b{num}\s*-\s*{num}\b")

    m3 = pat3.search(t)
    if m3:
        a, b, c = _norm_num(m3.group(1)), _norm_num(m3.group(2)), _norm_num(m3.group(3))
        return ("3", f"{a}-{b}-{c}")

    m2 = pat2.search(t)
    if m2:
        a, b = _norm_num(m2.group(1)), _norm_num(m2.group(2))
        return ("2", f"{a}-{b}")

    return (None, None)

def extract_addr_by_x(text: str):
    """
    Bắt địa chỉ dạng 'a x b x c' (3 phần) hoặc 'a x b' (2 phần).
    Trả về ('3','a-b-c') / ('2','a-b') / (None,None)
    """
    t = _norm_text(text)
    num = r"(\d+(?:[.,]\d+)?)"
    sep = ADDR_SEP

    pat3 = re.compile(rf"\b{num}\s*{sep}\s*{num}\s*{sep}\s*(\d+)\b")
    pat2 = re.compile(rf"\b{num}\s*{sep}\s*{num}\b")

    m3 = pat3.search(t)
    if m3:
        a, b, c = _norm_num(m3.group(1)), _norm_num(m3.group(2)), _norm_num(m3.group(3))
        return ("3", f"{a}-{b}-{c}")

    m2 = pat2.search(t)
    if m2:
        a, b = _norm_num(m2.group(1)), _norm_num(m2.group(2))
        return ("2", f"{a}-{b}")

    return (None, None)

def route_be_from_text(text: str):
    """
    Thứ tự ưu tiên:
      1) Địa chỉ 3 phần (hyphen hoặc 'x'):  GET /o?dia_chi=a-b-c
      2) Có 'ô' + 'khu' + 'hàng' (keywords): GET /o?ten_khu=...&ten_hang=...&ten_o=...
      3) Địa chỉ 2 phần (hyphen hoặc 'x'):  GET /hang?dia_chi=a-b
      4) Có 'khu' + 'hàng' (keywords):      GET /hang?ten_khu=...&ten_hang=...
      5) Chỉ 'khu' (keywords):              GET /khu?khu=...
      else: None
    """
    # 1) 3 phần theo hyphen/x
    kind, addr = extract_addr_hyphen(text)
    if kind == "3":
        be_url = f"http://localhost:5000/o?dia_chi={quote(addr)}"
        return ("o_dia_chi", be_url, {"dia_chi": addr})

    kind, addr = extract_addr_by_x(text)
    if kind == "3":
        be_url = f"http://localhost:5000/o?dia_chi={quote(addr)}"
        return ("o_dia_chi", be_url, {"dia_chi": addr})

    # keyword bắt khu/hàng/ô (bất kỳ thứ tự)
    found = extract_khu_hang_o_keywords(text)

    # 2) có đủ ô + khu + hàng (dùng query theo tên)
    if all(k in found for k in ("khu", "hang", "o")):
        url = (f"http://localhost:5000/o?"
               f"ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}&ten_o={quote(found['o'])}")
        return ("o_ten", url, {"ten_khu": found["khu"], "ten_hang": found["hang"], "ten_o": found["o"]})

    # 3) 2 phần theo hyphen/x
    kind, addr = extract_addr_hyphen(text)
    if kind == "2":
        url = f"http://localhost:5000/hang?dia_chi={quote(addr)}"
        return ("hang_dia_chi", url, {"dia_chi": addr})

    kind, addr = extract_addr_by_x(text)
    if kind == "2":
        url = f"http://localhost:5000/hang?dia_chi={quote(addr)}"
        return ("hang_dia_chi", url, {"dia_chi": addr})

    # 4) keyword khu + hàng
    if "khu" in found and "hang" in found:
        url = f"http://localhost:5000/hang?ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}"
        return ("hang_ten", url, {"ten_khu": found["khu"], "ten_hang": found["hang"]})

    # 5) chỉ khu
    if "khu" in found:
        url = f"http://localhost:5000/khu?khu={quote(found['khu'])}"
        return ("khu", url, {"khu": found["khu"]})

    return (None, None, {})


# --------------------
# Schemas
# --------------------
class Segment(BaseModel):
    id: int
    start: float
    end: float
    text: str
    avg_logprob: Optional[float] = None
    no_speech_prob: Optional[float] = None
    temperature: Optional[float] = None
    compression_ratio: Optional[float] = None

class VerboseResponse(BaseModel):
    text: str
    language: Optional[str] = None
    language_probability: Optional[float] = None
    duration: Optional[float] = None
    segments: List[Segment] = []
    task: Literal["transcribe", "translate"] = "transcribe"
    model: str
    device: str
    compute_type: str

class SimpleResponse(BaseModel):
    text: str


# --------------------
# Endpoints
# --------------------
@app.get("/healthz")
def health():
    return {"ok": True, "device": CT2_DEVICE, "compute_type": CT2_COMPUTE_TYPE}

@app.get("/v1/models")
def list_models():
    # Trả model mặc định + các model đã load vào cache
    ids = {DEFAULT_MODEL, *list(_model_cache.keys())}
    return {"data": [{"id": m} for m in ids]}

@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: Optional[str] = Form(None),
    language: Optional[str] = Form(None),                  # ví dụ: "vi"
    task: Literal["transcribe", "translate"] = Form("transcribe"),
    initial_prompt: Optional[str] = Form(None),
    response_format: Literal["json", "text", "verbose_json"] = Form("json"),
    temperature: Optional[float] = Form(0.0),
    beam_size: Optional[int] = Form(5),
    best_of: Optional[int] = Form(5),
    vad_filter: Optional[bool] = Form(False),
    word_timestamps: Optional[bool] = Form(False),
):
    """
    OpenAI-compatible:
      - file: audio/video (wav, mp3, m4a, mp4, ...)
      - model: HF repo id (vd: Systran/faster-whisper-large-v3)
      - language: 'vi', 'en', ...
      - task: 'transcribe' | 'translate'
      - response_format: 'json' | 'text' | 'verbose_json'
    """
    model_name = model or DEFAULT_MODEL

    # Lưu file tạm
    try:
        raw = await file.read()
        if not raw:
            raise HTTPException(status_code=400, detail="Empty file")
        suffix = os.path.splitext(file.filename or "")[-1] or ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(raw)
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {e}")

    try:
        wmodel = get_model(model_name)

        transcribe_opts: Dict[str, Any] = dict(
            task=task,
            beam_size=int(beam_size or 5),
            best_of=int(best_of or 5),
            temperature=float(temperature or 0.0),
            vad_filter=bool(vad_filter),
            initial_prompt=initial_prompt,
            condition_on_previous_text=True,
            word_timestamps=bool(word_timestamps),
        )
        if language:
            transcribe_opts["language"] = language  # ép ngôn ngữ

        segments_iter, info = wmodel.transcribe(tmp_path, **transcribe_opts)

        segments = []
        full_text_parts = []
        for s in segments_iter:
            text = (s.text or "").strip()
            seg = Segment(
                id=s.id, start=s.start, end=s.end, text=text,
                avg_logprob=getattr(s, "avg_logprob", None),
                no_speech_prob=getattr(s, "no_speech_prob", None),
                temperature=getattr(s, "temperature", None),
                compression_ratio=getattr(s, "compression_ratio", None),
            )
            segments.append(seg)
            if text:
                full_text_parts.append(text)

        text_out = " ".join(full_text_parts).strip()

        # >>>>> NEW: xác định URL BE từ text_out
        intent, be_url, be_params = route_be_from_text(text_out)

        # Các định dạng trả về
        if response_format == "text":
            # text thuần; nếu muốn gợi ý link BE ngay dưới, bạn có thể append
            return PlainTextResponse(text_out)

        if response_format == "verbose_json":
            payload = VerboseResponse(
                text=text_out,
                language=getattr(info, "language", None),
                language_probability=getattr(info, "language_probability", None),
                duration=getattr(info, "duration", None),
                segments=segments,
                task=task,
                model=model_name,
                device=CT2_DEVICE,
                compute_type=CT2_COMPUTE_TYPE,
            ).model_dump()
            if intent:
                payload["intent"] = intent
                payload["be_url"] = be_url
                payload["params"] = be_params
            return JSONResponse(payload)

        # Mặc định theo OpenAI: {"text": "..."} + đính kèm intent/URL nếu có
        resp = SimpleResponse(text=text_out).model_dump()
        if intent:
            resp["intent"] = intent
            resp["be_url"] = be_url
            resp["params"] = be_params
        return JSONResponse(resp)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {e}")
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
