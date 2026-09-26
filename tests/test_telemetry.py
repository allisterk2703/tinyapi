import pytest
from fastapi.testclient import TestClient
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from main import app


client = TestClient(app)
exporter = InMemorySpanExporter()
provider = trace.get_tracer_provider()
assert isinstance(provider, TracerProvider)
provider.add_span_processor(SimpleSpanProcessor(exporter))


@pytest.fixture(autouse=True)
def clear_spans():
    exporter.clear()


def test_request_produces_server_span():
    """Test a request is traced with its route."""
    client.get("/health")
    server_spans = [s for s in exporter.get_finished_spans() if s.kind == trace.SpanKind.SERVER]
    assert len(server_spans) == 1
    assert server_spans[0].attributes is not None
    assert server_spans[0].attributes["http.route"] == "/health"


def test_random_span_has_value_attribute():
    """Test /random records the returned value on its span."""
    value = client.get("/random").json()["value"]
    server_span = next(s for s in exporter.get_finished_spans() if s.kind == trace.SpanKind.SERVER)
    assert server_span.attributes is not None
    assert server_span.attributes["random.value"] == value
