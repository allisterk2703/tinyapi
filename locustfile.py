from locust import HttpUser, between, task


class TinyApiUser(HttpUser):
    host = "http://127.0.0.1:8001"
    wait_time = between(1, 2)

    @task(3)
    def get_random(self):
        self.client.get("/random", name="Random Number")

    @task(1)
    def get_ping(self):
        self.client.get("/ping", name="Health Check")
