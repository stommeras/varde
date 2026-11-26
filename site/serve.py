"""Serves build/site on http://localhost:8000 with the headers that site/vercel.json sends.

The web build uses threads, so the browser only starts it on a page that sends
Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy. A plain `python3 -m http.server`
leaves them out, and the game stops on a SharedArrayBuffer error.
"""

import http.server
import pathlib
from functools import partial

SITE = pathlib.Path(__file__).resolve().parent.parent / "build" / "site"


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


http.server.test(partial(Handler, directory=str(SITE)), port=8000)
