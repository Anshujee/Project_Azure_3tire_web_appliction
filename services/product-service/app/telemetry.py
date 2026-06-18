import os

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import metrics, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
    CollectorRegistry,
    multiprocess,
)

registry = CollectorRegistry()

http_requests_total = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "route", "status_code"],
    registry=registry,
)

http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "Duration of HTTP requests in seconds",
    ["method", "route", "status_code"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registry=registry,
)


def setup_telemetry(app) -> None:
    conn_str = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if conn_str:
        configure_azure_monitor(connection_string=conn_str)
        FastAPIInstrumentor.instrument_app(app)


def get_metrics() -> tuple[bytes, str]:
    data = generate_latest(registry)
    return data, CONTENT_TYPE_LATEST
