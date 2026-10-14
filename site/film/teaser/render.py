"""Renders a film page to PNG frames, as render.mjs does, without Node: Chrome over its DevTools protocol.

  python render.py <page> <frames dir> [fps] [seconds] [WxH, 1920x1080 if left out]
  python render.py <page> <stills dir> --at 64.0 92.5 …     one picture at each time, t<time>.png

Needs Google Chrome and websocket-client, in a venv:
  python3 -m venv /tmp/film && /tmp/film/bin/pip install websocket-client
Then, as with render.mjs:
  python3 soundtrack.py raw.wav && ffmpeg -i raw.wav -af loudnorm=I=-14:TP=-1:LRA=7 -ar 48000 audio.wav
  ffmpeg -framerate 30 -i frames/f%04d.png -i audio.wav -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 192k -shortest -movflags +faststart film.mp4
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket

CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
PORT = 9333

args = sys.argv[1:]
stills = '--at' in args
if stills:
    at = args.index('--at')
    args, times = args[:at], [float(t) for t in args[at + 1:]]
page, out = args[0], args[1]
fps, secs = (int(args[2]) if len(args) > 2 else 30), (float(args[3]) if len(args) > 3 else 10)
W, H = map(int, (args[4] if len(args) > 4 else '1920x1080').split('x'))
os.makedirs(out, exist_ok=True)

chrome = subprocess.Popen([CHROME, '--headless=new', f'--remote-debugging-port={PORT}', f'--remote-allow-origins=http://127.0.0.1:{PORT}',
                           f'--user-data-dir={tempfile.mkdtemp()}', '--allow-file-access-from-files', '--hide-scrollbars', '--no-first-run', 'about:blank'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(100):
        try:
            tabs = json.load(urllib.request.urlopen(f'http://127.0.0.1:{PORT}/json'))
            break
        except OSError:
            time.sleep(.1)
    ws = websocket.create_connection(next(t for t in tabs if t['type'] == 'page')['webSocketDebuggerUrl'], max_size=None)
    calls = 0

    def call(method, **params):
        global calls
        calls += 1
        ws.send(json.dumps({'id': calls, 'method': method, 'params': params}))
        while True:
            m = json.loads(ws.recv())
            if m.get('id') == calls:
                if 'error' in m:
                    raise RuntimeError(m['error'])
                return m.get('result', {})

    def js(expr):
        return call('Runtime.evaluate', expression=expr, awaitPromise=True, returnByValue=True).get('result', {}).get('value')

    call('Emulation.setDeviceMetricsOverride', width=W, height=H, deviceScaleFactor=1, mobile=False)
    call('Page.navigate', url='file://' + os.path.abspath(page) + '?render')
    while js('document.readyState') != 'complete':
        time.sleep(.1)
    # The fonts and every picture ready before the first frame, as networkidle0 and fonts.ready are for render.mjs.
    js('document.fonts.ready.then(() => Promise.all([...document.images].map(i => i.decode().catch(() => 0))))')

    def shot(seconds, path):
        js(f'window.seek({seconds * 1000})')
        png = call('Page.captureScreenshot', format='png', clip={'x': 0, 'y': 0, 'width': W, 'height': H, 'scale': 1})['data']
        with open(path, 'wb') as f:
            f.write(base64.b64decode(png))

    # The first picture after loading shows the svg bees as they were before the seek; one thrown away, the rest are right.
    shot(0, os.path.join(tempfile.mkdtemp(), 'warm.png'))
    if stills:
        for t in times:
            shot(t, f'{out}/t{t:g}.png')
    else:
        for f in range(round(fps * secs)):
            shot(f / fps, f'{out}/f{f:04d}.png')
            if f % 300 == 0:
                print(f'{f / fps:.0f} s', flush=True)
finally:
    chrome.terminate()
