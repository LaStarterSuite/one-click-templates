import os

from fastapi import FastAPI

# First boot writes both to /etc/one-click/app.env, which only this app reads.
SECRET_KEY = os.environ["SECRET_KEY"]
GREETING = os.environ.get("GREETING") or "Hello from FastAPI"

app = FastAPI()


@app.get("/")
def home():
	return {"message": GREETING, "next": "Replace /srv/app/src with your project."}


@app.get("/health")
def health():
	return {"status": "ok"}
