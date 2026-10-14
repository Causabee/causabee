// Renders a film page to PNG frames: node render.mjs <abs path to the page> <frames dir> [fps] [seconds] [WxH, 1920x1080 if left out]
// Needs puppeteer-core (npm i puppeteer-core) and Google Chrome. Then:
//   python3 soundtrack.py raw.wav && ffmpeg -i raw.wav -af loudnorm=I=-14:TP=-1:LRA=7 -ar 48000 audio.wav
//   ffmpeg -framerate 30 -i frames/f%04d.png -i audio.wav -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 192k -shortest -movflags +faststart teaser.mp4
import puppeteer from 'puppeteer-core';
const [,, page_, out, fps = 30, secs = 10, size = '1920x1080'] = process.argv;
const [W, H] = size.split('x').map(Number);
const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: ['--allow-file-access-from-files'] });
const p = await b.newPage();
await p.setViewport({ width: W, height: H });
await p.goto('file://' + page_ + '?render', { waitUntil: 'networkidle0' });
await p.evaluate(() => document.fonts.ready);
for (let f = 0; f < fps * secs; f++) {
  await p.evaluate(ms => window.seek(ms), f * 1000 / fps);
  await p.screenshot({ path: `${out}/f${String(f).padStart(4, '0')}.png` });
}
await b.close();
