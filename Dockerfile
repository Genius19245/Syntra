FROM python:3.11-slim
WORKDIR /app

RUN adduser --disabled-password --gecos "" myuser
USER myuser
ENV PATH="/home/myuser/.local/bin:$PATH"
ENV PYTHONPATH="/app/backend"

ENV GOOGLE_GENAI_USE_VERTEXAI=true
ENV GOOGLE_GENAI_USE_ENTERPRISE=1
ENV GOOGLE_CLOUD_PROJECT=agenticsai2026
ENV GOOGLE_CLOUD_LOCATION=global
ENV SYNTRA_GENERATE_IMAGES=true
ENV SYNTRA_IMAGE_MODEL=gemini-3.1-flash-image
ENV SYNTRA_IMAGE_MAX_PER_LESSON=2
ENV OTEL_SERVICE_NAME=syntra-orchestrator
ENV SYNTRA_ENV=production
ENV SYNTRA_OTEL_EXPORTER=gcp
ENV ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS=false
ENV OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=NO_CONTENT
ENV SYNTRA_MODEL_ARMOR_LOCATION=us-central1

COPY --chown=myuser:myuser requirements.txt /app/requirements.txt
RUN pip install --user -r /app/requirements.txt

COPY --chown=myuser:myuser backend /app/backend

# curriculum_agent/learning_objectives_agent is a local symlink. Recreate it
# inside the image so the relative import keeps working.
RUN rm -rf /app/backend/curriculum_agent/learning_objectives_agent && \
    ln -s ../learning_objectives_agent /app/backend/curriculum_agent/learning_objectives_agent

EXPOSE 8080
CMD ["adk", "api_server", "--port=8080", "--host=0.0.0.0", "--otel_to_cloud", "--session_service_uri=memory://", "--artifact_service_uri=memory://", "--allow_origins=https://syntra-studio.web.app", "--allow_origins=https://syntra-studio.firebaseapp.com", "--allow_origins=regex:http://localhost:[0-9]+", "--allow_origins=regex:http://127\\.0\\.0\\.1:[0-9]+", "/app/backend"]
