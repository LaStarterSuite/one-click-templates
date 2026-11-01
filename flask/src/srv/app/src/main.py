import os

from flask import Flask
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
# First boot writes both to /etc/one-click/app.env, which only this app reads.
app.secret_key = os.environ["SECRET_KEY"]
GREETING = os.environ.get("GREETING") or "Hello from Flask"
# nginx on this VM forwards the scheme and address the regional proxy saw.
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)


@app.get("/")
def home():
	return {"message": GREETING, "next": "Replace /srv/app/src with your project."}


@app.get("/health")
def health():
	return {"status": "ok"}
