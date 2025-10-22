import os
import re
import tempfile
import logging
from dataclasses import dataclass
from typing import Optional, Literal, Dict, Any, Tuple, Iterable, Set, List
from urllib.parse import quote

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Query
from fastapi.responses import JSONResponse, PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from faster_whisper import WhisperModel

# =========================
# Logging
# =========================
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=LOG_LEVEL,
    format="time=%(asctime)s level=%(levelname)s msg=%(message)s",
)
logger = logging.getLogger("phowhisper")

def trace_step(trace: List[Dict[str, Any]], step: str, **data):
    """Append a structured step into trace and also log at DEBUG."""
    item = {"step": step, **data}
    trace.append(item)
    logger.debug("trace %s | %s", step, data)

# =========================
# Config & Globals
# =========================
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "kiendt/PhoWhisper-large-ct2")
CT2_DEVICE = os.getenv("CT2_DEVICE", os.getenv("WHISPER__INFERENCE_DEVICE", "cuda"))
CT2_COMPUTE_TYPE = os.getenv("CT2_COMPUTE_TYPE", os.getenv("WHISPER__COMPUTE_TYPE", "float16"))
HF_HOME = os.getenv("HF_HOME", "/root/.cache/huggingface")

# Nếu chạy trong container và BE là máy host Windows/Mac, dùng host.docker.internal
BE_BASE_URL = os.getenv("BE_BASE_URL", "http://host.docker.internal:5000")

# Upload safeguards
MAX_UPLOAD_MB = int(os.getenv("MAX_UPLOAD_MB", "50"))
ALLOWED_EXTS = {".wav", ".mp3", ".m4a", ".mp4", ".webm", ".ogg"}

# ===== Tagger integration (optional) =====
TAGGER_BACKEND = os.getenv("TAGGER_BACKEND", "none").lower()   # "seq2seq" | "gec_tagger" | "none"
TAGGER_MODEL = os.getenv("TAGGER_MODEL", "").strip()
TAGGER_DEVICE = os.getenv("TAGGER_DEVICE", "cuda")

_tagger = None  # lazy loaded

def _load_tagger():
    """
    Lazy-load tagger tuỳ backend:
      - seq2seq : AutoModelForSeq2SeqLM (BARTpho/viT5/mT5/ByT5)
      - gec_tagger: AutoModelForTokenClassification (GECToR-style, cần decode)
    """
    global _tagger
    if _tagger is not None or TAGGER_BACKEND == "none" or not TAGGER_MODEL:
        return _tagger

    try:
        if TAGGER_BACKEND == "seq2seq":
            from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
            tok = AutoTokenizer.from_pretrained(TAGGER_MODEL)
            mdl = AutoModelForSeq2SeqLM.from_pretrained(TAGGER_MODEL)
            mdl.to(TAGGER_DEVICE)
            _tagger = ("seq2seq", tok, mdl)
            logger.info("tagger loaded backend=seq2seq model=%s device=%s", TAGGER_MODEL, TAGGER_DEVICE)
            return _tagger

        if TAGGER_BACKEND == "gec_tagger":
            # Placeholder: bạn cần cắm decode thật nếu dùng GEC tagging
            from transformers import AutoTokenizer, AutoModelForTokenClassification
            tok = AutoTokenizer.from_pretrained(TAGGER_MODEL)
            mdl = AutoModelForTokenClassification.from_pretrained(TAGGER_MODEL)
            mdl.to(TAGGER_DEVICE)
            _tagger = ("gec_tagger", tok, mdl)
            logger.info("tagger loaded backend=gec_tagger model=%s device=%s", TAGGER_MODEL, TAGGER_DEVICE)
            return _tagger

        logger.warning("TAGGER_BACKEND=%s chưa hỗ trợ, bỏ qua.", TAGGER_BACKEND)
        return None
    except Exception:
        logger.exception("load_tagger_failed backend=%s model=%s", TAGGER_BACKEND, TAGGER_MODEL)
        return None

def tagging_normalize(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> str:
    """
    Chạy “post-ASR normalizer”. Nếu TAGGER_BACKEND=none → trả nguyên văn.
    - seq2seq: generate 1-shot, deterministic
    - gec_tagger: gọi model tag + decode (bạn cần cắm decode thật của mình)
    """
    if TAGGER_BACKEND == "none" or not TAGGER_MODEL:
        if trace is not None:
            trace_step(trace, "tagger_skip", reason="disabled_or_no_model")
        return text

    tagger = _load_tagger()
    if tagger is None:
        if trace is not None:
            trace_step(trace, "tagger_skip", reason="not_loaded")
        return text

    backend, tok, mdl = tagger
    try:
        if backend == "seq2seq":
            x = tok(text, return_tensors="pt", truncation=True).to(mdl.device)
            y = mdl.generate(**x, max_new_tokens=256, do_sample=False, num_beams=4)
            out = tok.decode(y[0], skip_special_tokens=True)
            if trace is not None:
                trace_step(trace, "tagger_seq2seq", before=text, after=out)
            return out

        if backend == "gec_tagger":
            # ====== PLACEHOLDER ======
            # TODO: cắm decode GECToR thực thụ:
            # 1) tokenize → subwords
            # 2) model → nhãn EDIT (KEEP/DEL/REPL_xxx/APPEND_xxx)
            # 3) áp nhãn để dựng lại câu
            if trace is not None:
                trace_step(trace, "tagger_gec_placeholder", after=text)
            return text

    except Exception as e:
        logger.exception("tagger_failed")
        if trace is not None:
            trace_step(trace, "tagger_failed", error=str(e))
        return text

# =========================
# FastAPI
# =========================
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
        logger.info(
            "load_model model=%s device=%s compute_type=%s",
            model_name, CT2_DEVICE, CT2_COMPUTE_TYPE
        )
        _model_cache[model_name] = WhisperModel(
            model_name,
            device=CT2_DEVICE,
            compute_type=CT2_COMPUTE_TYPE
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
VI_SEP_X = {"x": "x", "*": "x", "nhân": "x", "by": "x"}

_NUM_RE = re.compile(r"^\d+(?:[.]\d+)?$")  # token kế tiếp là số?

def _strip_punct(token: str) -> str:
    return re.sub(r"^[^\w]+|[^\w]+$", "", token, flags=re.UNICODE)

def _vi_text_numbers_to_numeric(t: str, trace: Optional[List[Dict[str, Any]]] = None) -> str:
    """'sáu chấm một' → '6.1' ; chuẩn hoá 'nhân/by/*' -> 'x' ; chống dính dấu câu."""
    raw = t
    t = _norm_text(t)
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

    out_text = " ".join(out)
    if trace is not None:
        trace_step(trace, "normalize_numbers", before=raw, after=out_text)
    return out_text

# =========================
# Confusable alias registry (linh hoạt)
# =========================
@dataclass
class ConfusableRule:
    variants: Set[str]
    to: Optional[str] = None
    when_next_is_number: bool = False
    when_next_in: Optional[Set[str]] = None
    require_next: bool = False
    priority: int = 100

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
                cond_ok = cond_ok or (nxt_clean in r.when_next_in)
            if not cond_ok:
                continue

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

# Alias mặc định
register_confusables(
    {"hu","hú","hut","hút","khuu","khư","khưu","khui","ku","khú","khư","thư","thu","thư"},
    "khu",
    when_next_is_number=True,
    priority=10
)
register_confusables(
    {"hang","han","hàn","hằng","hàng"},
    "hàng",
    when_next_is_number=True,
    priority=10
)
register_confusables(
    {"o","ồ"},
    "ô",
    when_next_is_number=True,
    priority=10
)
register_confusables(
    {"số","so"},
    None,
    when_next_in={"ô"},
    require_next=True,
    priority=5
)
_FIND_CONTEXT = {"khu","hàng","hang","dãy","day","ô","o","dia","địa","dia_chi","địa_chỉ","địa-chỉ"}
register_confusables({"tiền","tien","tiền"}, "tìm", when_next_is_number=True, priority=20)
register_confusables({"tiền","tien","tiền"}, "tìm", when_next_in=_FIND_CONTEXT, priority=21)

def _normalize_phonetic_variants(t: str, trace: Optional[List[Dict[str, Any]]] = None) -> str:
    raw = t
    t = _norm_text(t)
    t = re.sub(r"(?<=\s)tim(?=\s)", "tìm", f" {t} ").strip()
    toks = t.split()
    toks = _apply_confusable_rules(toks)
    out_text = " ".join(toks)
    if trace is not None:
        trace_step(trace, "normalize_aliases", before=raw, after=out_text)
    return out_text

# =========================
# Helpers (debug)
# =========================
def get_confusables_summary(group_by: str = "rule") -> dict:
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
    canonical = {"khu": {"khu"}, "hàng": {"hàng"}, "ô": {"ô"}, "tìm": {"tìm"}}
    alias_map: Dict[str, Set[str]] = {"khu": set(), "hàng": set(), "ô": set(), "tìm": set()}
    for r in _CONFUSABLE_RULES:
        if r.to in alias_map:
            alias_map[r.to].update(r.variants)
    addr_seps = ["x", "×", "*", "nhân", "by"]
    find_context = sorted(list(_FIND_CONTEXT)) if "_FIND_CONTEXT" in globals() else []
    person_name_triggers = ["tên người mất", "ten nguoi mat", "người mất", "nguoi mat", "tên", "ten"]
    return {
        "khu": sorted(list(canonical["khu"] | alias_map["khu"])),
        "hàng": sorted(list(canonical["hàng"] | alias_map["hàng"])),
        "ô": sorted(list(canonical["ô"] | alias_map["ô"])),
        "tìm": sorted(list(canonical["tìm"] | alias_map["tìm"])),
        "find_context_keywords": find_context,
        "address_separators": addr_seps,
        "ten_nguoi_mat_triggers": person_name_triggers,
    }

# =========================
# NLP: trích xuất & định tuyến
# =========================
def extract_khu_hang_o_keywords(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Dict[str, str]:
    t = _norm_text(text)
    num_dec = r"(\d+(?:[.]\d+)?)"
    num_int = r"(\d+)"
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
    if trace is not None:
        trace_step(trace, "extract_khu_hang_o", text=t, found=found)
    return found

def extract_addr_hyphen(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Tuple[Optional[str], Optional[str]]:
    t = _norm_text(text)
    num = r"(\d+(?:[.]\d+)?)"
    pat3 = re.compile(rf"\b{num}\s*-\s*{num}\s*-\s*(\d+)\b")
    pat2 = re.compile(rf"\b{num}\s*-\s*{num}\b")

    m3 = pat3.search(t)
    if m3:
        a, b, c = _norm_num(m3.group(1)), _norm_num(m3.group(2)), _norm_num(m3.group(3))
        addr = f"{a}-{b}-{c}"
        if trace is not None:
            trace_step(trace, "extract_addr_hyphen", kind="3", addr=addr)
        return ("3", addr)

    m2 = pat2.search(t)
    if m2:
        a, b = _norm_num(m2.group(1)), _norm_num(m2.group(2))
        addr = f"{a}-{b}"
        if trace is not None:
            trace_step(trace, "extract_addr_hyphen", kind="2", addr=addr)
        return ("2", addr)

    if trace is not None:
        trace_step(trace, "extract_addr_hyphen", kind=None)
    return (None, None)

def extract_addr_by_x(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Tuple[Optional[str], Optional[str]]:
    t = _norm_text(text)
    num_dec = r"(\d+(?:[.]\d+)?)"
    sep = r"(?:x)"
    pat3 = re.compile(rf"\b{num_dec}\s*{sep}\s*{num_dec}\s*{sep}\s*(\d+)\b")
    pat2 = re.compile(rf"\b{num_dec}\s*{sep}\s*{num_dec}\b")

    m3 = pat3.search(t)
    if m3:
        a, b, c = _norm_num(m3.group(1)), _norm_num(m3.group(2)), _norm_num(m3.group(3))
        addr = f"{a}-{b}-{c}"
        if trace is not None:
            trace_step(trace, "extract_addr_by_x", kind="3", addr=addr)
        return ("3", addr)

    m2 = pat2.search(t)
    if m2:
        a, b = _norm_num(m2.group(1)), _norm_num(m2.group(2))
        addr = f"{a}-{b}"
        if trace is not None:
            trace_step(trace, "extract_addr_by_x", kind="2", addr=addr)
        return ("2", addr)

    if trace is not None:
        trace_step(trace, "extract_addr_by_x", kind=None)
    return (None, None)

# ---------- Tên người mất ----------
def _clean_person_name(s: str) -> str:
    s = s.strip()
    s = re.sub(r"[\s]+", " ", s)
    s = re.sub(r"[.,!?;:]+$", "", s)
    return s.strip(" '\"")

SURNAMES = {
    "nguyễn","nguyen","trần","tran","lê","le","phạm","pham","hoàng","hoang","huỳnh","huynh",
    "phan","vũ","vu","võ","vo","đặng","dang","bùi","bui","đỗ","do","hồ","ho","ngô","ngo",
    "dương","duong","đoàn","doan","lý","ly","lưu","luu","đinh","dinh","trịnh","trinh",
    "cao","tạ","ta","đào","dao","tô","to","vương","vuong"
}

def extract_ten_nguoi_mat(text: str, trace: Optional[List[Dict[str, Any]]] = None) -> Optional[str]:
    """
    Nhận diện các câu như:
      - 'tìm tên người mất lê anh đức'
      - 'tên người mất: lê anh đức'
      - tên đặt trong '...' hoặc "..."
    Có lookahead dừng trước slot/keyword/dấu câu/cuối câu.
    """
    t = _norm_text(text)

    STOP_AHEAD = r"(?=$|[,.;!?]|(?:\s+(?:khu|hang|hàng|ô|o|dia|địa|dia_chi|địa_chỉ|số|so|x|-|\d+)))"

    # 1) Cụm từ khoá rõ ràng (có lookahead)
    patterns = [
        rf"\b(?:tìm\s+)?(?:tên\s+người\s+mất|ten\s+nguoi\s+mat)\s*[:=\-]?\s*['\"]?([a-zà-ỹđ'\-\s]{{2,80}}?){STOP_AHEAD}",
        rf"\b(?:tìm\s+)?(?:người\s+mất|nguoi\s+mat)\s*[:=\-]?\s*['\"]?([a-zà-ỹđ'\-\s]{{2,80}}?){STOP_AHEAD}",
        rf"\b(?:tìm\s+)?(?:tên|ten)\s*[:=\-]?\s*['\"]?([a-zà-ỹđ'\-\s]{{2,80}}?){STOP_AHEAD}",
    ]
    for p in patterns:
        m = re.search(p, t, flags=re.UNICODE)
        if m:
            name = _clean_person_name(m.group(1))
            if name and not re.search(r"\d", name):
                if trace is not None:
                    trace_step(trace, "extract_person_keyword", pattern=p, name=name)
                return name

    # 2) Trong dấu nháy (ưu tiên nếu có >=2 từ)
    quotes = re.findall(r"[\"']([^\"']]{2,80})[\"']", t)
    # Fix regex typo: handle empty set char properly if someone edits line – safe fallback:
    if not quotes:
        quotes = re.findall(r"[\"']([^\"']{2,80})[\"']", t)
    for q in quotes:
        cand = _clean_person_name(q)
        if cand and " " in cand and not re.search(r"\d", cand):
            if trace is not None:
                trace_step(trace, "extract_person_quotes", name=cand)
            return cand

    # 3) Heuristic tên Việt (2–4 token, cho phép dấu '-)
    toks = [w for w in re.findall(r"[a-zà-ỹđ']+(?:-[a-zà-ỹđ']+)?", t)]
    n = len(toks)
    best = None
    for i in range(n - 1, -1, -1):
        if toks[i] in SURNAMES:
            for length in range(4, 1, -1):  # 4,3,2
                j = i + length
                if j <= n:
                    seg = toks[i:j]
                    cand = _clean_person_name(" ".join(seg))
                    if cand and not re.search(r"\d", cand):
                        best = cand
                        break
        if best:
            break
    if not best and n >= 2:
        tail = toks[max(0, n-4):]
        for k in range(min(4, len(tail)), 1, -1):
            cand = _clean_person_name(" ".join(tail[-k:]))
            if cand and not re.search(r"\d", cand):
                best = cand
                break
    if trace is not None:
        trace_step(trace, "extract_person_heuristic", name=best)
    return best

# =========================
# Routing
# =========================
def route_be_from_text(text: str) -> Tuple[Optional[str], Optional[str], Dict[str, Any]]:
    """Route không trace (giữ API cũ)."""
    intent, be_url, params, _trace = route_be_from_text_with_trace(text)
    return intent, be_url, params

def route_be_from_text_with_trace(text: str) -> Tuple[Optional[str], Optional[str], Dict[str, Any], List[Dict[str, Any]]]:
    """
    Thứ tự ưu tiên:
      0) Tên người mất:                    GET /o?ten_nguoi_mat=...
      1) Địa chỉ 3 phần (hyphen hoặc 'x'): GET /o?dia_chi=a-b-c
      2) Có 'ô' + 'khu' + 'hàng':          GET /o?ten_khu=...&ten_hang=...&ten_o=...
      3) Địa chỉ 2 phần:                   GET /hang?dia_chi=a-b
      4) Khu + hàng:                       GET /hang?ten_khu=...&ten_hang=...
      5) Chỉ 'khu':                        GET /khu?khu=...
    """
    trace: List[Dict[str, Any]] = []
    raw = text

    # 0) Tagger normalizer (chạy TRƯỚC bước normalize số/alias để sửa ngôn ngữ địa phương)
    tag_trace: List[Dict[str, Any]] = []
    text_tagged = tagging_normalize(raw, tag_trace)
    if tag_trace:
        trace.append({"step": "tagger_trace", "items": tag_trace})

    # 1) Chuẩn hoá → số + alias âm gần
    t1 = _vi_text_numbers_to_numeric(text_tagged, trace)
    t2 = _normalize_phonetic_variants(t1, trace)
    text = t2

    # 2) ưu tiên tên người mất
    ten_nguoi_mat = extract_ten_nguoi_mat(text, trace)
    if ten_nguoi_mat:
        be_url = f"{BE_BASE_URL}/o?ten_nguoi_mat={quote(ten_nguoi_mat)}"
        trace_step(trace, "route", intent="o_ten_nguoi_mat", be_url=be_url, params={"ten_nguoi_mat": ten_nguoi_mat})
        return ("o_ten_nguoi_mat", be_url, {"ten_nguoi_mat": ten_nguoi_mat}, trace)

    # 3) 3 phần theo hyphen/x
    kind, addr = extract_addr_hyphen(text, trace)
    if kind == "3":
        be_url = f"{BE_BASE_URL}/o?dia_chi={quote(addr)}"
        trace_step(trace, "route", intent="o_dia_chi", be_url=be_url, params={"dia_chi": addr})
        return ("o_dia_chi", be_url, {"dia_chi": addr}, trace)

    kind, addr = extract_addr_by_x(text, trace)
    if kind == "3":
        be_url = f"{BE_BASE_URL}/o?dia_chi={quote(addr)}"
        trace_step(trace, "route", intent="o_dia_chi", be_url=be_url, params={"dia_chi": addr})
        return ("o_dia_chi", be_url, {"dia_chi": addr}, trace)

    # 4) keyword khu/hàng/ô
    found = extract_khu_hang_o_keywords(text, trace)

    # đủ ô + khu + hàng
    if all(k in found for k in ("khu", "hang", "o")):
        url = (f"{BE_BASE_URL}/o?"
               f"ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}&ten_o={quote(found['o'])}")
        params = {"ten_khu": found["khu"], "ten_hang": found["hang"], "ten_o": found["o"]}
        trace_step(trace, "route", intent="o_ten", be_url=url, params=params)
        return ("o_ten", url, params, trace)

    # 5) 2 phần
    kind, addr = extract_addr_hyphen(text, trace)
    if kind == "2":
        url = f"{BE_BASE_URL}/hang?dia_chi={quote(addr)}"
        trace_step(trace, "route", intent="hang_dia_chi", be_url=url, params={"dia_chi": addr})
        return ("hang_dia_chi", url, {"dia_chi": addr}, trace)

    kind, addr = extract_addr_by_x(text, trace)
    if kind == "2":
        url = f"{BE_BASE_URL}/hang?dia_chi={quote(addr)}"
        trace_step(trace, "route", intent="hang_dia_chi", be_url=url, params={"dia_chi": addr})
        return ("hang_dia_chi", url, {"dia_chi": addr}, trace)

    # 6) khu + hàng
    if "khu" in found and "hang" in found:
        url = f"{BE_BASE_URL}/hang?ten_khu={quote(found['khu'])}&ten_hang={quote(found['hang'])}"
        params = {"ten_khu": found["khu"], "ten_hang": found["hang"]}
        trace_step(trace, "route", intent="hang_ten", be_url=url, params=params)
        return ("hang_ten", url, params, trace)

    # 7) chỉ khu
    if "khu" in found:
        url = f"{BE_BASE_URL}/khu?khu={quote(found['khu'])}"
        trace_step(trace, "route", intent="khu", be_url=url, params={"khu": found["khu"]})
        return ("khu", url, {"khu": found["khu"]}, trace)

    trace_step(trace, "route", intent=None, be_url=None, params={})
    return (None, None, {}, trace)

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
    logger.info("startup preload model")
    get_model(DEFAULT_MODEL)
    # preload tagger (nếu muốn lazy thì bỏ dòng dưới)
    if TAGGER_BACKEND != "none" and TAGGER_MODEL:
        _load_tagger()

@app.get("/healthz")
def health():
    return {
        "ok": True,
        "device": CT2_DEVICE,
        "compute_type": CT2_COMPUTE_TYPE,
        "model": DEFAULT_MODEL,
        "tagger": {"backend": TAGGER_BACKEND, "model": TAGGER_MODEL or None}
    }

@app.get("/v1/models")
def list_models():
    ids = {DEFAULT_MODEL, *list(_model_cache.keys())}
    return {"data": [{"id": m} for m in ids]}

@app.get("/debug/route")
def debug_route(text: str):
    """Test nhanh pipeline trích xuất/định tuyến chỉ từ TEXT (không cần audio)."""
    intent, be_url, params, trace = route_be_from_text_with_trace(text)
    return {"input": text, "intent": intent, "be_url": be_url, "params": params, "trace": trace}

@app.get("/debug/aliases")
def debug_aliases(group_by: Literal["rule", "target"] = "rule"):
    return get_confusables_summary(group_by=group_by)

@app.get("/debug/keywords")
def debug_keywords():
    return build_current_keywords()

@app.get("/debug/extract-person")
def debug_extract_person(text: str):
    """Debug riêng việc bắt tên người mất (chạy qua tagger + normalize)."""
    trace: List[Dict[str, Any]] = []
    # chạy tagger trước
    tag_trace: List[Dict[str, Any]] = []
    t_tag = tagging_normalize(text, tag_trace)
    if tag_trace:
        trace.append({"step": "tagger_trace", "items": tag_trace})
    t1 = _vi_text_numbers_to_numeric(t_tag, trace)
    t2 = _normalize_phonetic_variants(t1, trace)
    name = extract_ten_nguoi_mat(t2, trace)
    return {"input": text, "after_tagger": t_tag, "norm": t2, "name": name, "trace": trace}

@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    task: Literal["transcribe", "translate"] = Form("transcribe"),
    initial_prompt: Optional[str] = Form(None),
    response_format: Literal["json", "text"] = Form("json"),
    temperature: Optional[float] = Form(None),
    beam_size: Optional[int] = Form(None),
    best_of: Optional[int] = Form(None),
    vad_filter: Optional[bool] = Form(None),
    word_timestamps: Optional[bool] = Form(False),
    debug: Optional[bool] = Query(False),
):
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

        transcribe_opts: Dict[str, Any] = dict(
            task=task or "transcribe",
            language=language or "vi",
            vad_filter=True if vad_filter is None else bool(vad_filter),
            vad_parameters={"min_silence_duration_ms": 300},
            beam_size=int(beam_size or 10),
            best_of=int(best_of or 5),
            patience=0.2,
            temperature=[0.0, 0.2, 0.4] if temperature is None else float(temperature),
            condition_on_previous_text=False,
            word_timestamps=bool(word_timestamps),
            without_timestamps=True,
            initial_prompt=initial_prompt,
        )
        logger.info(
            "transcribe start file=%s model=%s opts=%s",
            file.filename, model_name,
            {k: transcribe_opts.get(k) for k in [
                "language","task","beam_size","best_of","vad_filter",
                "patience","temperature","condition_on_previous_text"
            ]}
        )

        segments_iter, info = wmodel.transcribe(tmp_path, **transcribe_opts)

        full_text_parts = []
        for s in segments_iter:
            t = (s.text or "").strip()
            if t:
                full_text_parts.append(t)
        text_out = " ".join(full_text_parts).strip()
        logger.info(
            "transcribe done lang=%s dur=%s text_len=%s",
            getattr(info, "language", None), getattr(info, "duration", None), len(text_out)
        )

        # NEW: chạy normalizer/tagger sau ASR trước khi route
        tag_trace: List[Dict[str, Any]] = []
        text_norm = tagging_normalize(text_out, tag_trace)

        # Routing + trace
        intent, be_url, be_params, trace = route_be_from_text_with_trace(text_norm)

        if tag_trace:
            # chèn trace tagger lên đầu để dễ đọc
            trace = [{"step": "tagger_trace", "items": tag_trace}] + trace

        if response_format == "text":
            return PlainTextResponse(text_norm)

        resp = SimpleResponse(text=text_norm).model_dump()
        if intent:
            resp["intent"] = intent
            resp["be_url"] = be_url
            resp["params"] = be_params
        if debug:
            resp["_debug"] = {
                "trace": trace,
                "raw_text": text_out,
                "model": model_name,
                "opts": {k: transcribe_opts.get(k) for k in [
                    "language","task","beam_size","best_of","vad_filter",
                    "patience","temperature","condition_on_previous_text"
                ]},
                "info": {"language": getattr(info, "language", None), "duration": getattr(info, "duration", None)},
                "tagger": {"backend": TAGGER_BACKEND, "model": TAGGER_MODEL or None}
            }
        return JSONResponse(resp)

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("transcription_failed")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {e}")
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
