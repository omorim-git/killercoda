#!/usr/bin/env python3
"""Serve scenario graphs and downloadable diagnostic bundles."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


class ArtifactHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        path = unquote(urlsplit(self.path).path)
        if path.lower().endswith((".txt", ".log")):
            filename = Path(path).name.replace('"', '')
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()


parser = argparse.ArgumentParser()
parser.add_argument("--directory", required=True)
parser.add_argument("--port", type=int, default=8090)
args = parser.parse_args()
handler = partial(ArtifactHandler, directory=args.directory)
server = ThreadingHTTPServer(("0.0.0.0", args.port), handler)
server.serve_forever()
