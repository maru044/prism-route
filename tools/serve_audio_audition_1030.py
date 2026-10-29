"""Read-only, loopback-only server for the downloaded audio listening page."""
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'docs/audio_research_1030/audition'
server = ThreadingHTTPServer(('127.0.0.1', 2917), partial(SimpleHTTPRequestHandler, directory=str(root)))
print('AUDIO_AUDITION_URL http://127.0.0.1:2917/index.html', flush=True)
server.serve_forever()
