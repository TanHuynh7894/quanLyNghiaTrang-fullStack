import torch
from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline


def build_ner(model_path):
    device = 0 if torch.cuda.is_available() else -1
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    model = AutoModelForTokenClassification.from_pretrained(model_path)
    ner = pipeline("ner", model=model, tokenizer=tokenizer, device=device)
    return ner


def extract_persons(entities):
    names = []
    for e in entities:
        label = e.get("entity", "")
        text = e.get("word") or e.get("text") or ""
        # xử lý subword (## hoặc ▁)
        text = text.replace("##", "").replace("▁", " ").strip()
        if "PER" in label and text not in names:
            names.append(text)
    return " ".join(names).strip() if names else "(không phát hiện tên người)"


def main():
    model_path = "models/ner-vietnamese-electra-base"
    ner = build_ner(model_path)

    print("=== Chat nhận diện tên người (PER) ===")
    print("Gõ câu tiếng Việt. Gõ 'exit' để thoát.\n")

    while True:
        text = input("[YOU] ").strip()
        if text.lower() in {"exit", "quit"}:
            break
        result = ner(text)
        name = extract_persons(result)
        print(f"[AI] {name}\n")


if __name__ == "__main__":
    main()
