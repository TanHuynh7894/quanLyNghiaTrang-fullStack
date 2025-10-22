FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    ffmpeg libsndfile1 ca-certificates curl git wget \
 && rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN python3 -m pip install --upgrade pip setuptools wheel

RUN pip3 install --no-cache-dir \
    fastapi==0.115.0 \
    uvicorn[standard]==0.30.6 \
    python-multipart==0.0.9 \
    pydantic==2.9.2 \
    ffmpeg-python==0.2.0 \
    soundfile==0.12.1 \
    numpy==1.26.4

RUN pip3 install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
    torch==2.2.2 torchvision==0.17.2 torchaudio==2.2.2

RUN pip3 install --no-cache-dir \
    ctranslate2==4.3.1 \
    faster-whisper==1.0.3 \
    huggingface-hub==0.23.4 \
    transformers==4.43.3 \
    accelerate==0.33.0 \
    tokenizers==0.19.1 \
    sentencepiece==0.2.0 \
    datasets==2.20.0 \
    rapidfuzz==3.6.2 \
    unidecode==1.3.8 \
    rich==13.7.0 \
    tqdm==4.66.4

COPY app.py .

ENV DEFAULT_MODEL=kiendt/PhoWhisper-large-ct2
ENV CT2_DEVICE=cuda
ENV CT2_COMPUTE_TYPE=float16
ENV WHISPER__INFERENCE_DEVICE=cuda
ENV WHISPER__COMPUTE_TYPE=float16
ENV HF_HOME=/root/.cache/huggingface
ENV TAGGER_BACKEND=gec_tagger
ENV TAGGER_MODEL=your-org/viet-gec-tagger
ENV TAGGER_DEVICE=cuda

RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--timeout-keep-alive", "120", "--log-level", "info"]
