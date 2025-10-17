import os
import re
import tempfile
from dataclasses import dataclass
from typing import Optional, Literal, Dict, Any, Tuple, Iterable, Set, List
from urllib.parse import quote

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Query
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from faster_whisper import WhisperModel

# =========================
# Config & Globals
# =========================
# Dùng PhoWhisper (CT2) để chạy với faster-whisper
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "kiendt/PhoWhisper-large-ct2")
CT2_DEVICE = os.getenv("CT2_DEVICE", os.getenv("WHISPER__INFERENCE_DEVICE", "cuda"))
CT2_COMPUTE_TYPE = os.getenv("CT2_COMPUTE_TYPE", os.getenv("WHISPER__COMPUTE_TYPE", "float16"))
HF_HOME = os.getenv("HF_HOME", "/root/.cache/huggingface")

# Nếu chạy trong container và BE là máy host Windows/Mac, nên dùng host.docker.internal
BE_BASE_URL = os.getenv("BE_BASE_URL", "http://host.docker.internal:5000")

# Cho phép "x", "×", "*", "nhân", "by"
ADDR_SEP = r"(?:x|×|\*|nhân|by)"

# Upload safeguards
MAX_UPLOAD_MB = int(os.getenv("MAX_UPLOAD_MB", "50"))
ALLOWED_EXTS = {".wav", ".mp3", ".m4a", ".mp4", ".webm", ".ogg"}

app = FastAPI(title="PhoWhisper GPU Server (OpenAI-compatible)")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# Cache model trong process
_model_cache: Dict[str, WhisperModel] = {}


def get_model(model_name: str) -> WhisperModel:
    if model_name not in _model_cache:
        _model_cache[model_name] = WhisperModel(
            model_name,
            device=CT2_DEVICE,            # "cuda" | "cpu"
            compute_type=CT2_COMPUTE_TYPE # "float16" | "int8" | "int8_float16" ...
        )
    return _model_cache[model_name]

# =========================
# Utils: Chuẩn hoá
# =========================
def _norm_num(s: str) -> str:
    return s.replace(",", ".").strip()

def _norm_text(t: str) -> str:
    if not t:
        return ""
    t = t.lower().strip()
    t = t.replace("×", "x")
    t = re.sub(r"\s+", " ", t)
    return t

# mapping chữ số tiếng Việt → số
VI_DIGITS = {
    "không": "0", "khong": "0",
    "một": "1", "mot": "1", "mốt": "1",
    "hai": "2", "ba": "3",
    "bốn": "4", "bon": "4", "tư": "4",
    "năm": "5", "nam": "5", "lăm": "5",
    "sáu": "6", "sau": "6",
    "bảy": "7", "bay": "7",
    "tám": "8", "tam": "8",
    "chín": "9", "chin": "9"
}
VI_SEP_DOT = {"chấm": ".", "cham": ".", "phẩy": ".", "phay": "."}
VI_SEP_X = {"x": "x", "*": "x", "nhân": "x", "by": "x"}  # (ký tự × đã đổi -> x trong _norm_text)

# regex nhận dạng số (cho điều kiện "token kế tiếp là số")
_NUM_RE = re.compile(r"^\d+(?:[.]\d+)?$")

def _strip_punct(token: str) -> str:
    """Bỏ dấu câu đầu/cuối token (.,!?… và ký tự không phải chữ/số)."""
    return re.sub(r"^[^\w]+|[^\w]+$", "", token, flags=re.UNICODE)

def _vi_text_numbers_to_numeric(t: str) -> str:
    """
    Chuyển 'sáu chấm một' → '6.1', 'bảy phẩy hai' → '7.2';
    chuẩn hoá 'nhân/by/*' -> 'x'; CHỐNG dính dấu câu (.,!?…) ở đầu/cuối token.
    """
    t = _norm_text(t)
    # thay “chấm/phẩy” -> “.”
    for k in VI_SEP_DOT.keys():
        t = re.sub(rf"\b{k}\b", ".", t)

    tokens = t.split()
    out = []
    i = 0
    while i < len(tokens):
        w = tokens[i]
        w_clean = _strip_punct(w)

        if w_clean in VI_DIGITS:
            num = VI_DIGITS[w_clean]
            j = i + 1
            frac = ""
            while j + 1 < len(tokens):
                dot_tok = tokens[j]
                nxt_tok = tokens[j + 1]
                nxt_clean = _strip_punct(nxt_tok)
                if dot_tok == "." and nxt_clean in VI_DIGITS:
                    frac += VI_DIGITS[nxt_clean]
                    j += 2
                else:
                    break
            if frac:
                out.append(f"{num}.{frac}")
                i = j
                continue
            out.append(num)
            i += 1
        else:
            out.append("x" if w in VI_SEP_X else w)
            i += 1

    return " ".join(out)

# =========================
# Confusable alias registry (linh hoạt)
# =========================
@dataclass
class ConfusableRule:
    variants: Set[str]                         # các biến thể bị nhận sai
    to: Optional[str] = None                   # thay bằng từ này; None/"" = xoá token
    when_next_is_number: bool = False          # chỉ thay khi từ kế tiếp là số (vd 6, 6.1)
    when_next_in: Optional[Set[str]] = None    # chỉ thay khi từ kế tiếp thuộc set này
    require_next: bool = False                 # bắt buộc phải có token kế tiếp
    priority: int = 100                        # ưu tiên (số nhỏ chạy trước)

_CONFUSABLE_RULES: List[ConfusableRule] = []

def register_confusables(
    variants: Iterable[str],
    to: Optional[str],
    *,
    when_next_is_number: bool = False,
    when_next_in: Iterable[str] | None = None,
    require_next: bool = False,
    priority: int = 100,
) -> None:
    """
    Đăng ký rule alias 'variants' -> 'to' với điều kiện ngữ cảnh.
    - to=None hoặc "" sẽ xoá token khớp.
    - when_next_is_number: chỉ áp dụng khi token kế tiếp là số.
    - when_next_in: chỉ áp dụng khi token kế tiếp nằm trong tập từ khoá.
    - require_next: bắt buộc phải có token kế tiếp.
    - priority: số nhỏ chạy trước (mặc định 100).
    """
    vs = { _norm_text(v) for v in variants if v and _norm_text(v) }
    nxt = { _norm_text(x) for x in (when_next_in or []) }
    rule = ConfusableRule(
        variants=vs,
        to=_norm_text(to) if (to is not None and to != "") else None,
        when_next_is_number=when_next_is_number,
        when_next_in=(nxt if nxt else None),
        require_next=require_next,
        priority=priority,
    )
    _CONFUSABLE_RULES.append(rule)
    _CONFUSABLE_RULES.sort(key=lambda r: r.priority)

def _apply_confusable_rules(tokens: List[str]) -> List[str]:
    """Áp dụng các rule đã đăng ký lên danh sách token theo thứ tự ưu tiên."""
    out: List[str] = []
    i = 0
    while i < len(tokens):
        w = tokens[i]
        nxt = tokens[i+1] if i+1 < len(tokens) else ""
        nxt_clean = _strip_punct(nxt)
        applied = False

        for r in _CONFUSABLE_RULES:
            if w not in r.variants:
                continue

            if r.require_next and not nxt:
                continue

            cond_ok = True
            if r.when_next_is_number:
                cond_ok = bool(_NUM_RE.match(nxt_clean or ""))
            if cond_ok and r.when_next_in is not None:
                # OR: đạt 1 trong 2 điều kiện là đủ (nếu muốn AND, đổi lại tuỳ nhu cầu)
                cond_ok = cond_ok or (nxt_clean in r.when_next_in)

            if not cond_ok:
                continue

            # Áp dụng thay thế/xoá
            if r.to is None:
                i += 1
                applied = True
                break
            else:
                out.append(r.to)
                i += 1
                applied = True
                break

        if applied:
            continue

        out.append(w)
        i += 1

    return out

# ====== Đăng ký các alias mặc định (tương đương logic cũ + mở rộng) ======
# 1) Khu: 'hút/hu/.../thư/thu' → 'khu' khi trước số
register_confusables(
    {"hu","hú","hut","hút","khuu","khư","khưu","khui","ku","khú","khư","thư","thu","thư"},
    "khu",
    when_next_is_number=True,
    priority=10
)

# 2) Hàng: 'hang/hàn/hằng/...' → 'hàng' khi trước số
register_confusables(
    {"hang","han","hàn","hằng","hàng"},
    "hàng",
    when_next_is_number=True,
    priority=10
)

# 3) Ô: 'o/ồ' → 'ô' khi trước số
register_confusables(
    {"o","ồ"},
    "ô",
    when_next_is_number=True,
    priority=10
)

# 4) 'số/so' ngay trước 'ô' → xoá 'số'
register_confusables(
    {"số","so"},
    None,
    when_next_in={"ô"},
    require_next=True,
    priority=5
)

# 5) 'tiền' → 'tìm' khi sau đó là số hoặc keyword tìm kiếm
_FIND_CONTEXT = {"khu","hàng","hang","dãy","day","ô","o","dia","địa","dia_chi","địa_chỉ","địa-chỉ"}
register_confusables({"tiền","tien","tiền"}, "tìm", when_next_is_number=True, priority=20)
register_confusables({"tiền","tien","tiền"}, "tìm", when_next_in=_FIND_CONTEXT, priority=21)

def _normalize_phonetic_variants(t: str) -> str:
    """Normalize dựa trên registry alias linh hoạt (đã strip dấu câu ở số)."""
    t = _norm_text(t)
    # quick-fix: mất dấu 'tìm' -> 'tim'
    t = re.sub(r"(?<=\s)tim(?=\s)", "tìm", f" {t} ").strip()
    toks = t.split()
    toks = _apply_confusable_rules(toks)
    return " ".join(toks)

# =========================
# Helpers: liệt kê alias & keyword (debug)
# =========================
def get_confusables_summary(group_by: str = "rule") -> dict:
    """
    Trả về snapshot các rule alias đã đăng ký.
    group_by = "rule"  : trả list rule đúng thứ tự ưu tiên
             = "target": gộp theo 'to' (đích thay thế)
    """
    if group_by == "target":
        buckets: Dict[str, list] = {}
        for r in _CONFUSABLE_RULES:
            key = r.to or "<DELETE>"
            item = {
                "variants": sorted(list(r.variants)),
                "to": r.to,
                "when_next_is_number": r.when_next_is_number,
                "when_next_in": sorted(list(r.when_next_in)) if r.when_next_in else None,
                "require_next": r.require_next,
                "priority": r.priority,
            }
            buckets.setdefault(key, []).append(item)
        return {"group_by": "target", "aliases": buckets}

    rules = [{
        "variants": sorted(list(r.variants)),
        "to": r.to,
        "when_next_is_number": r.when_next_is_number,
        "when_next_in": sorted(list(r.when_next_in)) if r.when_next_in else None,
        "require_next": r.require_next,
        "priority": r.priority,
    } for r in _CONFUSABLE_RULES]
    return {"group_by": "rule", "aliases": rules}

def build_current_keywords() -> dict:
    """
    Suy ra bộ keyword hiện tại cho 'khu' / 'hàng' / 'ô' / 'tìm' từ:
    - canonical: chính tả gốc
    - alias: mọi biến thể đang được map về cùng đích
    Đồng thời trả thêm:
    - find_context_keywords: tập từ khoá ngữ cảnh tìm kiếm
    - address_separators: các từ/ký tự phân cách địa chỉ (x, nhân, by, …)
    """
    canonical = {"khu": {"khu"}, "hàng": {"hàng"}, "ô": {"ô"}, "tìm": {"tìm"}}
    alias_map: Dict[str, Set[str]] = {"khu": set(), "hàng": set(), "ô": set(), "tìm": set()}
    for r in _CONFUSABLE_RULES:
        if r.to in alias_map:
            alias_map[r.to].update(r.variants)
    addr_seps = ["x", "×", "*", "nhân", "by"]
    find_context = sorted(list(_FIND_CONTEXT)) if "_FIND_CONTEXT" in globals() else []
    return {
        "khu": sorted(list(canonical["khu"] | alias_map["khu"])),
        "hàng": sorted(list(canonical["hàng"] | alias_map["hàng"])),
        "ô": sorted(list(canonical["ô"] | alias_map["ô"])),
        "tìm": sorted(list(canonical["tìm"] | alias_map["tìm"])),
        "find_context_keywords": find_context,
        "address_separators": addr_seps,
    }

# =========================
# NLP: trích xuất & định tuyến
# =========================
def extract_khu_hang_o_keywords(text: str) -> Dict[str, str]:
    """
    Bắt theo từ khóa: khu, hàng/dãy, ô.
    - khu: thập phân được (vd 6.1)
    - hàng/ô: số nguyên
    """
    t = _norm_text(text)
    num_dec = r"(\d+(?:[.]\d+)?)"
    num_int = r"(\d+)"

    # Cho phép biến thể phát âm gần cho 'khu' & 'hàng' & 'ô' (phòng khi chưa normalize)
    khu_kw  = r"(?:khu|khư|khưu|khui|khuu|hu|hú|hút|ku)"
    hang_kw = r"(?:hàng|hang|han|hàn|hằng)"
    o_kw    = r"(?:ô|o)"

    patterns = {
        "khu":  re.compile(rf"\b{khu_kw}(?:\s*(?:so|số|vuc|vực))?\s*{num_dec}\b"),
        "hang": re.compile(rf"\b{hang_kw}\s*{num_int}\b"),
        "o":    re.compile(rf"\b{o_kw}\s*{num_int}\b"),
    }
    found: Dict[str, str] = {}
    for key, pat in patterns.items():
        m = pat.search(t)
        if m:
            found[key] = _norm_num(m.group(1))
    return found

def extract_addr_hyphen(text: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Bắt địa chỉ dạng gạch nối:
      - 3 phần: a-b-c  -> ('3', 'a-b-c')
      - 2 phần: a-b    -> ('2', 'a-b')
    Ưu tiên 3 phần trước.
    """
    t = _norm_text(text)
    num = r"(\d+(?:[.]\d+)?)"
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

def extract_addr_by_x(text: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Bắt địa chỉ dạng 'a x b x c' (3 phần) hoặc 'a x b' (2 phần).
    Trả về ('3','a-b-c') / ('2','a-b') / (None,None)
    """
    t = _norm_text(text)
    num_dec = r"(\d+(?:[.]\d+)?)"
    sep = r"(?:x)"
    pat3 = re.compile(rf"\b{num_dec}\s*{sep}\s*{num_dec}\s*{sep}\s*(\d+)\b")
    pat2 = re.compile(rf"\b{num_dec}\s*{sep}\s*{num_dec}\b")

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
      2) Có 'ô' + 'khu' + 'hàng':           GET /o?ten_khu=...&ten_hang=...&ten_o=...
      3) Địa chỉ 2 phần (hyphen hoặc 'x'):  GET /hang?dia_chi=a-b
      4) Khu + hàng:                        GET /hang?ten_khu=...&ten_hang=...
      5) Chỉ 'khu':                         GET /khu?khu=...
      else: None
    """
    # Chuẩn hoá → số + alias âm gần
    text = _vi_text_numbers_to_numeric(text)
    text = _normalize_phonetic_variants(text)

    # 1) 3 phần theo hyphen/x
    kind, addr = extract_addr_hyphen(text)
    if kind == "3":
        be_url = f"{BE_BASE_URL}/o?dia_chi={quote(addr)}"
        return ("o_dia_chi", be_url, {"dia_chi": addr})

    kind, addr = extract_addr_by_x(text)
    if kind == "3":
        be_url = f"{BE_BASE_URL}/o?dia_chi={quote(addr)}"
        return ("o_dia_chi", be_url, {"dia_chi": addr})

    # keyword bắt khu/hàng/ô
    found = extract_khu_hang_o_keywords(text)

    # 2) đủ ô + khu + hàng
    if all(k in found for k in ("khu", "hang", "o")):
        url = (f"{BE_BASE_URL}/o?"
               f"ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}&ten_o={quote(found['o'])}")
        return ("o_ten", url, {"ten_khu": found["khu"], "ten_hang": found["hang"], "ten_o": found["o"]})

    # 3) 2 phần theo hyphen/x
    kind, addr = extract_addr_hyphen(text)
    if kind == "2":
        url = f"{BE_BASE_URL}/hang?dia_chi={quote(addr)}"
        return ("hang_dia_chi", url, {"dia_chi": addr})

    kind, addr = extract_addr_by_x(text)
    if kind == "2":
        url = f"{BE_BASE_URL}/hang?dia_chi={quote(addr)}"
        return ("hang_dia_chi", url, {"dia_chi": addr})

    # 4) khu + hàng
    if "khu" in found and "hang" in found:
        url = f"{BE_BASE_URL}/hang?ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}"
        return ("hang_ten", url, {"ten_khu": found["khu"], "ten_hang": found["hang"]})

    # 5) chỉ khu
    if "khu" in found:
        url = f"{BE_BASE_URL}/khu?khu={quote(found['khu'])}"
        return ("khu", url, {"khu": found["khu"]})

    return (None, None, {})

# =========================
# Schemas
# =========================
class SimpleResponse(BaseModel):
    text: str

# =========================
# Endpoints
# =========================
@app.on_event("startup")
def _warm():
    # preload model để tránh cold start request đầu
    get_model(DEFAULT_MODEL)

@app.get("/healthz")
def health():
    return {"ok": True, "device": CT2_DEVICE, "compute_type": CT2_COMPUTE_TYPE, "model": DEFAULT_MODEL}

@app.get("/v1/models")
def list_models():
    ids = {DEFAULT_MODEL, *list(_model_cache.keys())}
    return {"data": [{"id": m} for m in ids]}

@app.get("/debug/route")
def debug_route(text: str):
    """
    Test nhanh pipeline trích xuất/định tuyến chỉ từ TEXT (không cần audio).
    """
    normed = _vi_text_numbers_to_numeric(text)
    normed2 = _normalize_phonetic_variants(normed)
    intent, be_url, params = route_be_from_text(text)
    return {"input": text, "norm_text": normed, "norm_text2": normed2,
            "intent": intent, "be_url": be_url, "params": params}

@app.get("/debug/aliases")
def debug_aliases(group_by: Literal["rule", "target"] = "rule"):
    """
    Trả về toàn bộ alias đã đăng ký.
    - /debug/aliases?group_by=rule   : theo từng rule (giữ priority)
    - /debug/aliases?group_by=target : gộp theo 'to' (khu/hàng/ô/tìm/<DELETE>)
    """
    return get_confusables_summary(group_by=group_by)

@app.get("/debug/keywords")
def debug_keywords():
    """
    Trả về bộ từ khoá hệ thống đang dùng:
    - khu / hàng / ô / tìm : gồm canonical + alias
    - find_context_keywords: các từ ngữ cảnh sau 'tìm' (nếu có)
    - address_separators   : các từ/ký tự phân cách địa chỉ
    """
    return build_current_keywords()

@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: Optional[str] = Form(None),
    language: Optional[str] = Form(None),                  # ví dụ: "vi"
    task: Literal["transcribe", "translate"] = Form("transcribe"),
    initial_prompt: Optional[str] = Form(None),
    response_format: Literal["json", "text"] = Form("json"),   # chỉ json | text
    temperature: Optional[float] = Form(None),
    beam_size: Optional[int] = Form(None),
    best_of: Optional[int] = Form(None),
    vad_filter: Optional[bool] = Form(None),
    word_timestamps: Optional[bool] = Form(False),
    debug: Optional[bool] = Query(False),
):
    """
    OpenAI-compatible (rút gọn, không trả segments):
      - file: audio/video (wav, mp3, m4a, mp4, webm, ...)
      - model: HF repo id (vd: kiendt/PhoWhisper-large-ct2)
      - language: 'vi', 'en', ...
      - task: 'transcribe' | 'translate'
      - response_format: 'json' | 'text'
    """
    model_name = model or DEFAULT_MODEL

    # Validate ext & size
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(raw) > MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large (> {MAX_UPLOAD_MB} MB)")
    suffix = os.path.splitext(file.filename or "")[-1].lower() or ".wav"
    if suffix not in ALLOWED_EXTS:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {suffix}")

    # Save temp file
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(raw)
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {e}")

    try:
        wmodel = get_model(model_name)

        # cấu hình khuyến nghị cho TV
        transcribe_opts: Dict[str, Any] = dict(
            task=task or "transcribe",
            language=language or "vi",
            # VAD & search
            vad_filter=True if vad_filter is None else bool(vad_filter),
            vad_parameters={"min_silence_duration_ms": 300},
            beam_size=int(beam_size or 10),
            best_of=int(best_of or 5),
            patience=0.2,
            # temperature schedule giúp bớt lặp
            temperature=[0.0, 0.2, 0.4] if temperature is None else float(temperature),
            # giảm “lậm” câu trước để chính xác slot khu-hàng-ô
            condition_on_previous_text=False,
            word_timestamps=bool(word_timestamps),
            without_timestamps=True,  # không tạo timestamp token
            initial_prompt=initial_prompt,
        )

        segments_iter, info = wmodel.transcribe(tmp_path, **transcribe_opts)

        # Gom text cuối cùng
        full_text_parts = []
        for s in segments_iter:
            t = (s.text or "").strip()
            if t:
                full_text_parts.append(t)
        text_out = " ".join(full_text_parts).strip()

        # Xác định URL BE từ text_out (nếu có)
        intent, be_url, be_params = route_be_from_text(text_out)

        if response_format == "text":
            return PlainTextResponse(text_out)

        resp = SimpleResponse(text=text_out).model_dump()
        if intent:
            resp["intent"] = intent
            resp["be_url"] = be_url
            resp["params"] = be_params
        if debug:
            resp["_debug"] = {
                "norm1": _vi_text_numbers_to_numeric(text_out),
                "norm2": _normalize_phonetic_variants(_vi_text_numbers_to_numeric(text_out)),
                "model": model_name,
                "opts": {k: transcribe_opts.get(k) for k in ["language","task","beam_size","best_of","vad_filter","patience","temperature","condition_on_previous_text"]},
                "info": {"language": getattr(info, "language", None), "duration": getattr(info, "duration", None)}
            }
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
