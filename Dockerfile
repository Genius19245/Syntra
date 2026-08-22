FROM python:3.11-slim
WORKDIR /app

RUN adduser --disabled-password --gecos "" myuser
USER myuser
ENV PATH="/home/myuser/.local/bin:$PATH"

ENV GOOGLE_GENAI_USE_VERTEXAI=true
ENV GOOGLE_GENAI_USE_ENTERPRISE=1
ENV GOOGLE_CLOUD_PROJECT=agenticsai2026
ENV GOOGLE_CLOUD_LOCATION=global

COPY --chown=myuser:myuser requirements.txt /app/requirements.txt
RUN pip install --user -r /app/requirements.txt

COPY --chown=myuser:myuser syntra_orchestrator /app/syntra_orchestrator
COPY --chown=myuser:myuser curriculum_agent /app/curriculum_agent
COPY --chown=myuser:myuser research_agent /app/research_agent
COPY --chown=myuser:myuser learning_objectives_agent /app/learning_objectives_agent

# curriculum_agent/learning_objectives_agent is a local symlink. Recreate it
# inside the image so the relative import keeps working.
RUN rm -rf /app/curriculum_agent/learning_objectives_agent && \
    ln -s ../learning_objectives_agent /app/curriculum_agent/learning_objectives_agent

EXPOSE 8080
CMD ["adk", "api_server", "--port=8080", "--host=0.0.0.0", "--session_service_uri=memory://", "--artifact_service_uri=memory://", "--allow_origins=regex:http://localhost:[0-9]+", "--allow_origins=regex:http://127\\.0\\.0\\.1:[0-9]+", "/app"]
