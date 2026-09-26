import os
import random

from fastapi import FastAPI
from opentelemetry import metrics, trace

from telemetry import setup_telemetry


app = FastAPI(
    title="tinyapi",
    description="Minimal FastAPI service exposing three endpoints: health check, random number generation, and port info.",
    version="0.1.0",
    contact={
        "name": "Allister K.",
    },
)

setup_telemetry(app)

meter = metrics.get_meter(__name__)
random_values = meter.create_histogram(
    "tinyapi.random.value",
    description="Values returned by the /random endpoint",
)


@app.get("/health", summary="Health check endpoint", tags=["Health"])
def health():
    """
    Health check endpoint that returns the API status.

    Returns:
        dict: A dictionary containing the status of the API.

    Example:
        ```json
        {
            "status": "ok"
        }
        ```
    """
    return {"status": "ok"}


@app.get("/random", summary="Random number generator", tags=["Random"])
def random_number():
    """
    Generate a random integer between 0 and 100 (inclusive).

    Returns:
        dict: A dictionary containing a random integer value.

    Example:
        ```json
        {
            "value": 42
        }
        ```
    """
    value = random.randint(0, 100)
    trace.get_current_span().set_attribute("random.value", value)
    random_values.record(value)
    return {"value": value}


@app.get("/port", summary="Port info", tags=["Info"])
def port():
    """
    Returns the port this instance is listening on.

    Useful when running multiple containers behind a load balancer
    to verify which instance handled the request.

    Returns:
        dict: A dictionary containing the port number.

    Example:
        ```json
        {
            "port": 8001
        }
        ```
    """
    return {"port": int(os.environ.get("PORT", 8000))}
