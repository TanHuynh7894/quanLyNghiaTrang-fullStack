FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

# System deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-pip ffmpeg libsndfile1 ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Python deps
COPY requirements.txt .
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir -r requirements.txt

# App code
COPY app.py .

# Runtime env (PhoWhisper CT2)
ENV CT2_DEVICE=cuda
ENV CT2_COMPUTE_TYPE=float16
ENV WHISPER__INFERENCE_DEVICE=cuda
ENV WHISPER__COMPUTE_TYPE=float16
ENV DEFAULT_MODEL=kiendt/PhoWhisper-large-ct2
ENV HF_HOME=/root/.cache/huggingface
# (tuỳ chọn) base URL BE khi route từ text:
# ENV BE_BASE_URL=http://host.docker.internal:5000

EXPOSE 8000

# Uvicorn (đúng module path: app:app)
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000","--timeout-keep-alive","120","--log-level","info"]
