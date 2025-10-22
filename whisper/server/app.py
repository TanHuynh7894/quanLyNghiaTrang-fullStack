import os, re, tempfile, logging
from typing import Optional, Dict, Any, Tuple, List
from urllib.parse import quote

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel

# =========================================================
# Logging
# =========================================================
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="time=%(asctime)s level=%(levelname)s msg=%(message)s")
logger = logging.getLogger("phowhisper")

def trace_step(trace: List[Dict[str, Any]], step: str, **data):
    trace.append({"step": step, **data})
    logger.debug("trace %s | %s", step, data)

# =========================================================
# Config
# =========================================================
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "kiendt/PhoWhisper-large-ct2")
CT2_DEVICE = os.getenv("CT2_DEVICE", "cuda")
CT2_COMPUTE_TYPE = os.getenv("CT2_COMPUTE_TYPE", "float16")
BE_BASE_URL = os.getenv("BE_BASE_URL", "http://host.docker.internal:5000")

MAX_UPLOAD_MB = 50
ALLOWED_EXTS = {".wav", ".mp3", ".m4a", ".mp4", ".webm", ".ogg"}

# =========================================================
# FastAPI setup
# =========================================================
app = FastAPI(title="PhoWhisper GPU Server")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

_model_cache: Dict[str, WhisperModel] = {}

def get_model(model_name: str) -> WhisperModel:
    if model_name not in _model_cache:
        logger.info("Loading model %s ...", model_name)
        _model_cache[model_name] = WhisperModel(model_name, device=CT2_DEVICE, compute_type=CT2_COMPUTE_TYPE)
    return _model_cache[model_name]

# =========================================================
# Normalization
# =========================================================
def _norm_text(t: str) -> str:
    if not t:
        return ""
    t = t.lower().strip()
    t = t.replace("×", "x").replace("–", "-").replace("—", "-")
    t = re.sub(r"\s+", " ", t)
    return t

def _strip_punct(token: str) -> str:
    """Loại dấu câu đầu/cuối để tránh lỗi như 'năm.' -> 'năm'."""
    return re.sub(r"^[^\w]+|[^\w]+$", "", token, flags=re.UNICODE)

VI_DIGITS = {
    "không": "0", "khong": "0",
    "một": "1", "mot": "1", "mốt": "1", "mộ": "1",
    "hai": "2", "nhai": "2",
    "ba": "3", "bang": "3", "ma": "3",
    "bốn": "4", "bon": "4", "tư": "4", "vốn": "4", "tốn": "4",
    "năm": "5", "nam": "5", "lăm": "5", "nhăm": "5",
    "sáu": "6", "sau": "6", "xấu": "6", "xá": "6", "sáy": "6", "sây": "6", "sảy": "6", "sớ": "6", "sá": "6", "thái": "6", "xóm": "6",
    "bảy": "7", "bay": "7", "bai": "7",
    "tám": "8", "tam": "8", "cám": "8", "xám": "8",
    "chín": "9", "chin": "9", "tín": "9", "xin": "9",
}
# biến thể 'chấm' nghe sai như 'chấn', 'chẫn', 'trăm', ...
VI_SEP_DOT = {
    "chấm": ".", "cham": ".", "chấn": ".", "chan": ".", "chẫn": ".", "phẩy": ".",
    "phay": ".", "tram": ".", "trăm": ".", "chống": ".", "trong": ".", "chong": ".",
    "chứng": ".", "chung": ".", "trung": "."
}
VI_SEP_X = {"x": "x", "*": "x", "nhân": "x", "by": "x"}

def _vi_text_numbers_to_numeric(t: str, trace: Optional[List[Dict[str, Any]]] = None) -> str:
    """'sáu chấm ba' -> '6.3', giữ nguyên dấu 'x'."""
    raw = t
    t = _norm_text(t)
    for k in VI_SEP_DOT:
        t = re.sub(rf"\b{k}\b", ".", t)

    toks = t.split()
    out: List[str] = []
    i = 0
    while i < len(toks):
        w = toks[i]
        w_clean = _strip_punct(w)
        if w_clean in VI_DIGITS:
            num = VI_DIGITS[w_clean]
            j = i + 1
            frac = ""
            while j + 1 < len(toks):
                dot_tok = toks[j]
                nxt_tok = toks[j + 1]
                nxt_clean = _strip_punct(nxt_tok)
                if dot_tok == "." and nxt_clean in VI_DIGITS:
                    frac += VI_DIGITS[nxt_clean]
                    j += 2
                else:
                    break
            out.append(f"{num}.{frac}" if frac else num)
            i = j if frac else i + 1
        else:
            out.append("x" if w in VI_SEP_X else w)
            i += 1

    res = " ".join(out)
    if trace:
        trace_step(trace, "normalize_numbers", before=raw, after=res)
    return res

# =========================================================
# Extract helpers
# =========================================================
_KHU_ALIAS_RE = r"\b(khuon|khuôn|khuong|khuông|khun|khum|khung|khui|khưu|khư|khuu|thu|thư|ku|khú|khú|khư|khoảng|tháng|bu|pu|u|thủ)\b"
_HANG_ALIAS_RE = r"\b(hang|han|hàn|hằng|hàng|hiện|hình|phần)\b"
_O_ALIAS_RE    = r"\b(o|ồ|u|vô)\b"
_FILLERS_RE = r"\b(còn|con|vài|vai|thì|thi|chúng|chung|chúng tôi|chung toi|giúp|giup|cho|xin|tôi|toi|tui|xem|vị|vi|trí|tri|của|cua|ở|o|đâu|dau|nằm|nam|hỏi|hoi)\b"

def _canonicalize_slots(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> str:
    raw = text
    t = _norm_text(text)
    t = re.sub(_KHU_ALIAS_RE, "khu", t)
    t = re.sub(_HANG_ALIAS_RE, "hàng", t)
    t = re.sub(_O_ALIAS_RE, "ô", t)
    t = re.sub(_FILLERS_RE, " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    if trace:
        trace_step(trace, "precanonicalize", before=raw, after=t)
    return t

def extract_khu_hang_o_keywords(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Dict[str, str]:
    t = _vi_text_numbers_to_numeric(text, trace)
    t = _canonicalize_slots(t, trace)
    t = t.replace("-", ".")
    num = r"(\d+(?:[.]\d+)?)"
    found: Dict[str, str] = {}
    patterns = {
        "khu":  re.compile(rf"\bkhu\s*{num}\b"),
        "hang": re.compile(rf"\bhàng\s*(\d+)\b"),
        "o":    re.compile(rf"\bô\s*(\d+)\b"),
    }
    for key, pat in patterns.items():
        m = pat.search(t)
        if m:
            found[key] = m.group(1)
    if trace:
        trace_step(trace, "extract_khu_hang_o", text=t, found=found)
    return found

def extract_addr_hyphen(text: str, trace: Optional[List[Dict[str, Any]]] = None):
    t = _norm_text(text)
    num = r"(\d+(?:[.]\d+)?)"
    m3 = re.search(rf"{num}\s*-\s*{num}\s*-\s*(\d+)", t)
    if m3:
        addr = f"{m3.group(1)}-{m3.group(2)}-{m3.group(3)}"
        if trace: trace_step(trace, "extract_addr_hyphen", kind="3", addr=addr)
        return "3", addr
    m2 = re.search(rf"{num}\s*-\s*(\d+)", t)
    if m2:
        addr = f"{m2.group(1)}-{m2.group(2)}"
        if trace: trace_step(trace, "extract_addr_hyphen", kind="2", addr=addr)
        return "2", addr
    if trace: trace_step(trace, "extract_addr_hyphen", kind=None, addr=None)
    return None, None

def extract_addr_by_x(text: str, trace: Optional[List[Dict[str, Any]]] = None):
    t = _norm_text(text)
    num = r"(\d+(?:[.]\d+)?)"
    m3 = re.search(rf"{num}\s*x\s*{num}\s*x\s*(\d+)", t)
    if m3:
        addr = f"{m3.group(1)}-{m3.group(2)}-{m3.group(3)}"
        if trace: trace_step(trace, "extract_addr_by_x", kind="3", addr=addr)
        return "3", addr
    m2 = re.search(rf"{num}\s*x\s*(\d+)", t)
    if m2:
        addr = f"{m2.group(1)}-{m2.group(2)}"
        if trace: trace_step(trace, "extract_addr_by_x", kind="2", addr=addr)
        return "2", addr
    if trace: trace_step(trace, "extract_addr_by_x", kind=None, addr=None)
    return None, None

# =========================================================
# Person name
# =========================================================
def extract_ten_nguoi_mat(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Optional[str]:
    """
    Trích tên người mất trong nhiều dạng câu, bao gồm cả câu hỏi vị trí:
      - "ông/bà <tên> (nằm) ở đâu"
      - "vị trí phần mộ của ông/bà <tên>"
      - "phần mộ của <tên>"
      - "người mất <tên>", "tên người mất <tên>"
    """
    # 1) Chuẩn hoá cơ bản + fix các lỗi 'mộ'
    t = text.replace("\r", " ").replace("\n", " ")
    t = _norm_text(t)
    t = _fix_common_asr_mo(t)

    # 2) Danh xưng cho phép đứng trước tên
    honorific = r"(?:ông|bà|bà|cụ|cụ|anh|chị|cô|chú|bác|cụ|cuu|co|chu|bac)"

    # 3) Pattern: CÂU HỎI VỊ TRÍ có tên
    #    - "[vị trí (phần) mộ của] [danh xưng] <tên> (nằm) ở đâu"
    #    - "[danh xưng] <tên> (nằm) ở đâu"
    #    Lưu ý: <tên> cho phép 2–80 ký tự, không ăn số/ký hiệu slot.
    loc_q_patterns = [
        rf"(?:vị\s*trí\s*(?:phần\s*)?mộ\s+của\s+)?(?:{honorific}\s+)?([a-zà-ỹđ][a-zà-ỹđ'\-\s]{{1,78}}[a-zà-ỹđ])\s*(?:nằm\s+ở\s+đâu|ở\s+đâu)?\b",
    ]
    for p in loc_q_patterns:
        m = re.search(p, t, flags=re.UNICODE)
        if m:
            name = re.sub(r"[ .,\-]+$", "", m.group(1).strip())
            # tránh case dính slot/số
            if not re.search(r"(?:\d|khu|hang|hàng|ô)\b", name):
                if trace: trace_step(trace, "extract_person_location_q", name=name)
                return name

    # 4) Pattern: “tên người mất …”, “người mất …”
    kw_patterns = [
        rf"\b(?:tên\s+người\s+mất|ten\s+nguoi\s+mat)\s+([a-zà-ỹđ'\-\s]{{2,80}})",
        rf"\b(?:người\s+mất|nguoi\s+mat)\s+([a-zà-ỹđ'\-\s]{{2,80}})",
    ]
    for p in kw_patterns:
        m = re.search(p, t, flags=re.UNICODE)
        if m:
            name = re.sub(r"[ .,\-]+$", "", m.group(1).strip())
            if not re.search(r"(?:\d|khu|hang|hàng|ô)\b", name):
                if trace: trace_step(trace, "extract_person_keyword", name=name)
                return name

    # 5) Pattern: “(vị trí) phần mộ/mộ của [danh xưng] <tên>”
    mo_patterns = [
        rf"(?:vị\s*trí\s*(?:phần\s*)?mộ\s+của|vi\s*tri\s*(?:phan\s*)?mo\s+cua)\s+(?:{honorific}\s+)?([a-zà-ỹđ'\-\s]{{2,80}})",
        rf"(?:phần\s+mộ\s+của|phan\s+mo\s+cua|mộ\s+của|mo\s+cua)\s+(?:{honorific}\s+)?([a-zà-ỹđ'\-\s]{{2,80}})",
    ]
    for p in mo_patterns:
        m = re.search(p, t, flags=re.UNICODE)
        if m:
            name = re.sub(r"[ .,\-]+$", "", m.group(1).strip())
            if not re.search(r"(?:\d|khu|hang|hàng|ô)\b", name):
                if trace: trace_step(trace, "extract_person_graveof", name=name)
                return name

    # 6) Không tìm thấy
    if trace: trace_step(trace, "extract_person_none")
    return None




def _fix_common_asr_mo(t: str) -> str:
    """
    Chuẩn hoá các lỗi nhận dạng thường gặp của từ 'mộ' và 'phần mộ'
    thành đúng dạng để extract_ten_nguoi_mat() nhận ra.
    """
    # các lỗi phổ biến: mẫu, mau, mồ, mậu, mâu, mỗ, vận hội, vận hội, vần hội, vẫn hội, vận hôi,...
    replacements = [
        # dạng “phần + từ sai”
        (r"\b(phần|phan)\s+(m[âa]u|mồ|mậu|mâu|mỗ|van hoi|vận hội|vần hội|vẫn hội|vận hôi|vận hồi)\b", "phần mộ"),
        (r"\b(phần|phan|phong|phòng)\s+(mau|mauu|mao|ngộ|ngô)\b", "phần mộ"),

        # dạng riêng lẻ “mẫu/mau/mồ/mậu/vận hội” trước “của”
        (r"\b(m[âa]u|mồ|mậu|mâu|mỗ|vận hội|van hoi|vần hội|vẫn hội|vận hôi|vận hồi)\s+của\b", "mộ của"),

        # các biến thể lẻ “mẫu”, “mau”, “vận hội”, “phòng ngọn”, ...
        (r"\bm[âa]u\b", "mộ"),
        (r"\bmồ\b", "mộ"),
        (r"\bmậu\b", "mộ"),
        (r"\bmâu\b", "mộ"),
        (r"\bmỗ\b", "mộ"),
        (r"\bvận\s+hội\b", "mộ"),
        (r"\bvan\s+hoi\b", "mộ"),
        (r"\bvần\s+hội\b", "mộ"),
        (r"\bvẫn\s+hội\b", "mộ"),
        (r"\bvận\s+hôi\b", "mộ"),
        (r"\bvận\s+hồi\b", "mộ"),
        (r"\bph[oôơ]ng\s+ng[oọ]n\b", "phần mộ"),  # phòng ngọn
        (r"\bph[òóôồỗơ]ng\s+ng[oọ]n\b", "phần mộ"),
        (r"\bv[âă]n\s*h[ôo]i\b", "phần mộ"),
        (r"\bph[âă]n\s+m[âă]u\b", "phần mộ"),
        (r"\bph[âă]n\s+ng[oọ]n\b", "phần mộ"),
        (r"\bph[oơởờòõôỗ]?\s+m[âă]u\b", "phần mộ"),

    ]

    for pat, rep in replacements:
        t = re.sub(pat, rep, t)
    return t


# =========================================================
# Routing
# =========================================================
def route_be_from_text_with_trace(text: str):
    trace: List[Dict[str, Any]] = []
    t = _vi_text_numbers_to_numeric(text, trace)
    t = _canonicalize_slots(t, trace)

    found = extract_khu_hang_o_keywords(t, trace)
    if all(k in found for k in ("khu", "hang", "o")):
        url = f"{BE_BASE_URL}/o?ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}&ten_o={quote(found['o'])}"
        return "o_ten", url, found, trace
    if "khu" in found and "hang" in found:
        url = f"{BE_BASE_URL}/hang?ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}"
        params = {"ten_khu": found["khu"], "ten_hang": found["hang"]}
        return "hang_ten", url, params, trace
    if "khu" in found:
        url = f"{BE_BASE_URL}/khu?khu={quote(found['khu'])}"
        return "khu", url, {"khu": found["khu"]}, trace
    for func in (extract_addr_hyphen, extract_addr_by_x):
        kind, addr = func(t, trace)
        if addr:
            url = f"{BE_BASE_URL}/o?dia_chi={quote(addr)}"
            return "o_dia_chi", url, {"dia_chi": addr}, trace
    name = extract_ten_nguoi_mat(t, trace)
    if name:
        url = f"{BE_BASE_URL}/o?ten_nguoi_mat={quote(name)}"
        return "o_ten_nguoi_mat", url, {"ten_nguoi_mat": name}, trace
    return None, None, {}, trace

# =========================================================
# API Endpoints
# =========================================================
@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile = File(...), model: str = Form(DEFAULT_MODEL)):
    raw = await file.read()
    if not raw:
        raise HTTPException(400, "Empty file")
    suffix = os.path.splitext(file.filename or "")[-1].lower()
    if suffix not in ALLOWED_EXTS:
        raise HTTPException(400, f"Unsupported file: {suffix}")

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(raw)
        tmp_path = tmp.name

    try:
        mdl = get_model(model)
        segs, info = mdl.transcribe(tmp_path, task="transcribe", language="vi")
        text = " ".join([s.text.strip() for s in segs if s.text]).strip()
        intent, be_url, params, trace = route_be_from_text_with_trace(text)
        logger.info('[transcribe] ok -> text="%s", intent=%s, be_url=%s', text, intent, be_url)
        resp: Dict[str, Any] = {"text": text}
        if intent:
            resp.update({"intent": intent, "be_url": be_url, "params": params})
        return JSONResponse(resp)
    finally:
        try:
            os.unlink(tmp_path)
        except:
            pass

@app.get("/healthz")
def health():
    return {"ok": True, "model": DEFAULT_MODEL}
