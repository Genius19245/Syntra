"""Process-level OpenTelemetry for SYNTRA ADK agents.

ADK already emits invoke_agent / execute_tool / generate_content spans once a
tracer provider is set. This module only chooses the exporter and keeps
prompts out of telemetry. It is a Python module, not an ADK app.
"""

from __future__ import annotations

import logging
import os
from typing import Any

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.trace import ProxyTracerProvider

logger = logging.getLogger("syntra.observability")

_PRIVACY_CAPTURE = "ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS"
_PRIVACY_GENAI = "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"

_initialized = False


def apply_privacy_env() -> None:
    """Keep prompts, student chat, and PII out of span attributes."""

    os.environ[_PRIVACY_CAPTURE] = "false"
    os.environ[_PRIVACY_GENAI] = "NO_CONTENT"
    os.environ.setdefault("OTEL_SERVICE_NAME", "syntra-orchestrator")


def resolve_exporter() -> str:
    """Return console, otlp, gcp, or off.

    Cloud Run sets K_SERVICE. Tests should set SYNTRA_OTEL_EXPORTER=off.
    """

    raw = (os.getenv("SYNTRA_OTEL_EXPORTER") or "").strip().lower()
    if raw in {"console", "otlp", "gcp", "off"}:
        return raw
    if os.getenv("K_SERVICE"):
        return "gcp"
    return "console"


def _provider_already_set() -> bool:
    provider = trace.get_tracer_provider()
    return provider is not None and not isinstance(provider, ProxyTracerProvider)


def _resource() -> Resource:
    project = os.getenv("GOOGLE_CLOUD_PROJECT") or ""
    environment = os.getenv("SYNTRA_ENV") or (
        "production" if os.getenv("K_SERVICE") else "development"
    )
    attributes: dict[str, str] = {
        "service.name": os.getenv("OTEL_SERVICE_NAME", "syntra-orchestrator"),
        "service.namespace": "syntra",
        "service.version": os.getenv("SYNTRA_VERSION", "0.1.0"),
        "deployment.environment": environment,
    }
    if project:
        attributes["gcp.project_id"] = project
    return Resource.create(attributes)


def _instrument_genai() -> None:
    try:
        from opentelemetry.instrumentation.google_genai import (
            GoogleGenAiSdkInstrumentor,
        )

        GoogleGenAiSdkInstrumentor().instrument()
    except Exception:
        logger.debug("google-genai instrumentation not installed", exc_info=True)


def _setup_console() -> None:
    from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

    provider = TracerProvider(resource=_resource())
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)


def _setup_otlp() -> None:
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    provider = TracerProvider(resource=_resource())
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)


def _setup_gcp() -> None:
    import google.auth
    from google.adk.telemetry.google_cloud import get_gcp_exporters, get_gcp_resource
    from google.adk.telemetry.setup import maybe_set_otel_providers

    credentials, project_id = google.auth.default()
    hooks = get_gcp_exporters(
        enable_cloud_tracing=True,
        google_auth=(credentials, project_id),
    )
    resource = get_gcp_resource(project_id).merge(_resource())
    maybe_set_otel_providers([hooks], otel_resource=resource)
    _instrument_genai()


def setup_telemetry() -> None:
    """Initialize tracing once. Never replaces an existing TracerProvider."""

    global _initialized
    apply_privacy_env()
    if _initialized:
        return
    _initialized = True
    if _provider_already_set():
        return

    exporter = resolve_exporter()
    if exporter == "off":
        return
    try:
        if exporter == "console":
            _setup_console()
        elif exporter == "otlp":
            _setup_otlp()
        else:
            _setup_gcp()
    except Exception:
        logger.exception("OpenTelemetry setup failed for exporter=%s", exporter)


def get_tracer(name: str = "syntra") -> Any:
    return trace.get_tracer(name)


def reset_for_tests() -> None:
    """Allow unit tests to re-run setup. Not used in production."""

    global _initialized
    _initialized = False
