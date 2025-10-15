FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-pip ffmpeg ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt
COPY app.py .
ENV CT2_DEVICE=cuda
ENV CT2_COMPUTE_TYPE=float16
ENV WHISPER__INFERENCE_DEVICE=cuda
ENV WHISPER__COMPUTE_TYPE=float16
ENV DEFAULT_MODEL=Systran/faster-whisper-large-v3
ENV HF_HOME=/root/.cache/huggingface
EXPOSE 8000
CMD ["uvicorn", "app.py:app", "--host", "0.0.0.0", "--port", "8000"]
