import os
import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline

########################################################
# 1. Cấu hình model
########################################################

MODEL_PATH = os.getenv("NER_MODEL_DIR", "models/ner-vietnamese-electra-base")

# giữ pipeline toàn cục để không reload mỗi request
ner_pipeline = None

def load_pipeline():
    global ner_pipeline
    if ner_pipeline is None:
        device = 0 if torch.cuda.is_available() else -1
        tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
        model = AutoModelForTokenClassification.from_pretrained(MODEL_PATH)
        ner_pipeline = pipeline("ner", model=model, tokenizer=tokenizer, device=device)
        print(f"[INFO] NER model loaded from {MODEL_PATH} on device {device}")
    return ner_pipeline


########################################################
# 2. Gom entity PER thành tên người đầy đủ
########################################################

def _clean_token_text(token_text: str) -> str:
    if not token_text:
        return ""
    # xoá ký hiệu subword (##) và prefix ▁
    return token_text.replace("##", "").replace("▁", " ").strip()

def merge_person_entities(entities: List[dict]) -> List[str]:
    """
    Nhận output từ pipeline('ner'), ví dụ dạng:
    [
      {'word': 'Lê', 'entity': 'B-PER', 'score':0.99, ...},
      {'word': 'Anh', 'entity': 'I-PER', ...},
      {'word': 'Đức', 'entity': 'I-PER', ...},
      ...
    ]
    hoặc đôi khi:
    [
      {'word': 'lê', 'entity': 'PER', ...},
      {'word': 'anh', 'entity': 'PER', ...},
      {'word': 'đức', 'entity': 'PER', ...},
    ]

    Trả về list tên người đã ghép, ví dụ ["Lê Anh Đức"].
    Nếu có nhiều tên khác nhau trong câu, sẽ trả nhiều phần tử.
    """

    persons_final: List[str] = []

    current_tokens: List[str] = []
    last_was_per = False  # để handle kiểu 'PER' liên tiếp không có B-/I-

    def flush_current():
        nonlocal current_tokens, persons_final
        if current_tokens:
            name = " ".join(current_tokens).strip()
            name = " ".join(name.split())  # normalize khoảng trắng
            if name and name not in persons_final:
                persons_final.append(name)
            current_tokens = []

    for ent in entities:
        label = ent.get("entity", "") or ent.get("entity_group", "")
        raw_word = ent.get("word") or ent.get("text") or ""
        tok = _clean_token_text(raw_word)

        # debug từng token
        print(f"[DEBUG] token={tok!r} label={label!r}")

        is_per = "PER" in label.upper()

        if not is_per:
            # kết thúc chuỗi tên người nếu đang gom
            flush_current()
            last_was_per = False
            continue

        # nếu là PER
        label_up = label.upper()
        if label_up.startswith("B-"):
            # B-PER -> bắt đầu tên mới
            flush_current()
            if tok:
                current_tokens.append(tok)
            last_was_per = True

        elif label_up.startswith("I-"):
            # I-PER -> nối tiếp tên hiện tại
            if tok:
                current_tokens.append(tok)
            last_was_per = True

        else:
            # trường hợp model chỉ trả 'PER' thuần
            if last_was_per:
                # vẫn đang trong cùng cụm PER -> nối tiếp
                if tok:
                    current_tokens.append(tok)
            else:
                # bắt đầu cụm mới
                flush_current()
                if tok:
                    current_tokens.append(tok)
            last_was_per = True

    # flush phần cuối
    flush_current()

    return persons_final


########################################################
# 3. Schema request/response
########################################################

class NerRequest(BaseModel):
    text: str

class NerResponse(BaseModel):
    persons: List[str]


########################################################
# 4. Khởi tạo FastAPI
########################################################

app = FastAPI(
    title="Vietnamese NER API",
    description="Nhận text tiếng Việt, trả về danh sách tên người (PER) từ model NER.",
    version="1.0.1",
)


########################################################
# 5. Healthcheck
########################################################

@app.get("/health")
def health():
    return {"status": "ok", "model_path": MODEL_PATH}


########################################################
# 6. Endpoint chính
########################################################

@app.post("/ner", response_model=NerResponse)
def ner_endpoint(body: NerRequest):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text rỗng")

    ner = load_pipeline()

    try:
        raw_entities = ner(text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"NER error: {e}")

    # debug toàn bộ output của model
    print("===== DEBUG RAW ENTITIES =====")
    print(raw_entities)
    print("================================")

    persons = merge_person_entities(raw_entities)

    print("===== DEBUG MERGED PERSONS =====")
    print(persons)
    print("================================")

    return NerResponse(persons=persons)
