# ── Stage 1: Install dependencies ──────────────────────────────
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
# --user installs packages to /root/.local so we can copy them cleanly to stage 2
RUN pip install --no-cache-dir --user -r requirements.txt

# ── Stage 2: Runtime image ──────────────────────────────────────
FROM python:3.11-slim AS runtime

# Create non-root user
RUN useradd -m -u 1001 appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source
COPY app/ ./app/

# Switch to non-root user
USER appuser

# Add user local bin to PATH so uvicorn is found
ENV PATH=/home/appuser/.local/bin:$PATH

EXPOSE 3002

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:3002/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3002"]
