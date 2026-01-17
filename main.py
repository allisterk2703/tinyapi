import random

from fastapi import FastAPI


app = FastAPI(
    title="tinyapi",
    description="Minimal FastAPI service exposing two endpoints for health checks and random number generation.",
    version="0.1.0",
    contact={
        "name": "Allister K.",
    },
)


@app.get("/ping", summary="Health check endpoint", tags=["Health"])
def ping():
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
    return {"value": random.randint(0, 100)}
