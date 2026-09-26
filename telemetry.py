import os

from fastapi import FastAPI
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def setup_telemetry(app: FastAPI) -> None:
    """
    Configure OpenTelemetry traces and metrics, then instrument the FastAPI app.

    SDK providers are always installed so spans and metrics are recorded in-process.
    OTLP/HTTP exporters are only attached when OTEL_EXPORTER_OTLP_ENDPOINT is set
    (e.g. http://localhost:4318); the exporters read the endpoint from the env themselves.
    """
    resource = Resource.create(
        {
            "service.name": os.environ.get("OTEL_SERVICE_NAME", "tinyapi"),
            "service.version": app.version,
            "service.instance.id": os.environ.get("PORT", "8000"),
        }
    )
    export = bool(os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT"))

    tracer_provider = TracerProvider(resource=resource)
    if export:
        tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    readers = [PeriodicExportingMetricReader(OTLPMetricExporter())] if export else []
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=readers))

    FastAPIInstrumentor.instrument_app(app)
