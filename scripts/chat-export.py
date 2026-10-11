#!/usr/bin/env python3
# The Claude Code sessions for a repo, written out as Markdown — one file per session and a
# README.md that lists them. Works in any repo; nothing to install beyond Python 3.
#
#   scripts/chat-export.py                       # the repo you are in, into concept/chat
#   scripts/chat-export.py --out docs/chat       # somewhere else (relative to the repo, or absolute)
#   scripts/chat-export.py --also ~/old/path     # a folder the repo lived in before; may be repeated
#   scripts/chat-export.py --repo ~/Developer/x  # a repo other than the one you are in
#
# What it does:
# - reads the transcripts Claude Code keeps under ~/.claude/projects, for the repo's folder, for
#   the worktrees Claude made of it, and for every folder given with --also;
# - writes what was said, each tool call with its input and output, and the subagents' transcripts
#   at the end of the session they belong to;
# - puts the pictures into <out>/images, each one once, named after its content.
#
# Every run writes all files again. Keep the output out of git: tool output can hold what should
# not be pushed. The script says so when the folder is not ignored.
import json, re, glob, os, sys, argparse, subprocess
from datetime import datetime, timezone

# The folders this repo lived in before, read on every run. Here: from before the rename, when it
# was called matterbee. Empty this list when the script goes to another repo.
ALSO = ['~/Documents/GitHub/matterbee', '~/Developer/matterbee']

ap = argparse.ArgumentParser(description='Export the Claude Code sessions of a repo as Markdown.')
ap.add_argument('--repo', help='the repo (default: the git repo you are in, else the current folder)')
ap.add_argument('--out', default='concept/chat', help='where to write (default: concept/chat)')
ap.add_argument('--also', action='append', default=[], metavar='PATH',
                help='a folder the repo lived in before; may be repeated')
args = ap.parse_args()

def git(*a, cwd=None):
    try: return subprocess.run(['git', *a], cwd=cwd, capture_output=True, text=True)
    except OSError: return None

if args.repo: REPO = os.path.abspath(os.path.expanduser(args.repo))
else:
    g = git('rev-parse', '--show-toplevel')
    REPO = g.stdout.strip() if g and g.returncode == 0 and g.stdout.strip() else os.getcwd()
ROOT = os.path.expanduser('~/.claude/projects')
# Claude Code names a project's folder after its path, every other character turned into a dash;
# the worktrees it makes of a repo get the same name with --claude-worktrees-<name> after it.
def encoded(path): return re.sub(r'[^A-Za-z0-9]', '-', os.path.abspath(os.path.expanduser(path)).rstrip('/'))
DIRS = []
for path in ALSO + args.also + [REPO]:
    e = encoded(path)
    for d in [e] + sorted(os.path.basename(x) for x in glob.glob(os.path.join(ROOT, glob.escape(e) + '--claude-worktrees-*'))):
        if d not in DIRS and os.path.isdir(os.path.join(ROOT, d)): DIRS.append(d)
if not DIRS: sys.exit(f'No Claude Code transcripts for {REPO} under {ROOT}')
OUT = os.path.join(REPO, os.path.expanduser(args.out))
os.makedirs(OUT, exist_ok=True)
g = git('check-ignore', '-q', OUT, cwd=REPO)
if g and g.returncode == 1:
    print(f'Note: {OUT} is not ignored by git — add it to .gitignore before you commit.', file=sys.stderr)

REMINDER = re.compile(r'<system-reminder>.*?</system-reminder>', re.S)
TAGS = re.compile(r'<(local-command-stdout|local-command-caveat|command-message|command-args|ide_[a-z_]+)>.*?</\1>', re.S)
CMD = re.compile(r'<command-name>(.*?)</command-name>', re.S)

def local(ts):
    return datetime.fromisoformat(ts.replace('Z', '+00:00')).astimezone()

def clean(t):
    t = REMINDER.sub('', t)
    args = re.search(r'<command-args>(.*?)</command-args>', t, re.S)
    m = CMD.search(t)
    if m:
        t = m.group(1).strip() + (' ' + args.group(1).strip() if args and args.group(1).strip() else '')
    t = TAGS.sub('', t)
    return t.strip()

def tool_line(name, inp):
    d = inp.get('description') or inp.get('file_path') or inp.get('pattern') or inp.get('query') \
        or inp.get('url') or inp.get('skill') or inp.get('action') or inp.get('title') or ''
    d = str(d).replace('\n', ' ')
    if len(d) > 140: d = d[:137] + '…'
    return f'`{name}`' + (f' — {d}' if d else '')

def fenced(t, lang=''):
    runs = re.findall(r'`+', t)
    fence = '`' * max(3, max(map(len, runs), default=0) + 1)
    return f'{fence}{lang}\n{t}\n{fence}\n'

def tool_input(name, inp):
    out = []; short = []
    for k, v in inp.items():
        if k == 'description': continue
        if isinstance(v, str):
            if '\n' in v or len(v) > 120 or k == 'command':
                out.append(f'{k}:\n\n' + fenced(v, 'bash' if name == 'Bash' and k == 'command' else ''))
            else: short.append(f'- {k}: `{v}`' if '`' not in v else f'- {k}: {v}')
        elif isinstance(v, (int, float, bool)) or v is None: short.append(f'- {k}: `{json.dumps(v)}`')
        else: out.append(f'{k}:\n\n' + fenced(json.dumps(v, indent=2, ensure_ascii=False), 'json'))
    return (['\n'.join(short) + '\n'] if short else []) + out

import base64, hashlib
os.makedirs(os.path.join(OUT, 'images'), exist_ok=True)
def image(b):
    src = b.get('source') or {}
    if src.get('type') != 'base64' or not src.get('data'): return '*[image not stored in the transcript]*'
    raw = base64.b64decode(src['data'])
    ext = {'image/png': 'png', 'image/jpeg': 'jpg', 'image/gif': 'gif', 'image/webp': 'webp'}.get(src.get('media_type'), 'bin')
    name = hashlib.sha1(raw).hexdigest()[:16] + '.' + ext
    p = os.path.join(OUT, 'images', name)
    if not os.path.exists(p): open(p, 'wb').write(raw)
    return f'![image](images/{name})'

def slug(s):
    s = re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
    return s[:60].strip('-') or 'session'


def render(p, sub=False):
    r = dict(title=None, first=None, last=None, body=[], nuser=0, cwd=None, first_prompt=None)
    body = r['body']; tools = {}; need = [True]
    who, me = ('Prompt', 'Agent') if sub else ('User', 'Claude')
    h = '###' if sub else '##'
    def flush():
        for l, i in tools.values(): body.append(f'> {l}\n'); body.extend(i)
        tools.clear()
    for line in open(p, encoding='utf-8'):
        try: o = json.loads(line)
        except Exception: continue
        t = o.get('type')
        if t == 'custom-title': r['title'] = o.get('customTitle') or r['title']
        elif t == 'ai-title' and not r['title']: r['title'] = o.get('aiTitle')
        elif t == 'summary' and not r['title']: r['title'] = o.get('summary')
        if t not in ('user', 'assistant') or o.get('isMeta') or (o.get('isSidechain') and not sub): continue
        ts = o.get('timestamp'); r['cwd'] = r['cwd'] or o.get('cwd')
        if ts:
            r['first'] = r['first'] or ts; r['last'] = ts
        c = o.get('message', {}).get('content')
        if t == 'user':
            if o.get('isCompactSummary'):
                flush(); body.append('*— earlier conversation compacted here —*\n'); continue
            parts = []; images = []
            if isinstance(c, str): parts.append(c)
            else:
                for b in c or []:
                    if b.get('type') == 'text': parts.append(b['text'])
                    elif b.get('type') == 'image': images.append(image(b))
                    elif b.get('type') == 'tool_result':
                        l, tin = tools.pop(b.get('tool_use_id'), ('`tool`', []))
                        rc = b.get('content'); out = []; imgs = []
                        if isinstance(rc, str): out.append(rc)
                        else:
                            for x in rc or []:
                                if x.get('type') == 'text': out.append(x['text'])
                                elif x.get('type') == 'image': imgs.append(image(x))
                                elif x.get('type') == 'tool_reference': out.append('[tool loaded: %s]' % x.get('tool_name'))
                        out = REMINDER.sub('', '\n'.join(out)).strip('\n')
                        body.append(f'> {l}' + (' — **error**' if b.get('is_error') else '') + '\n')
                        body.extend(tin)
                        if out: body.append('output:\n\n' + fenced(out))
                        if imgs: body.append('\n\n'.join(imgs) + '\n')
            text = clean('\n\n'.join(parts))
            if not text and not images: continue
            flush(); r['nuser'] += 1
            r['first_prompt'] = r['first_prompt'] or text
            when = local(ts).strftime('%Y-%m-%d %H:%M') if ts else ''
            body.append(f'{h} {who} · {when}\n')
            if text: body.append(text + '\n')
            if images: body.append('\n\n'.join(images) + '\n')
            need[0] = True
        else:
            for b in c or []:
                if b.get('type') == 'text' and b['text'].strip():
                    flush()
                    if need[0]: body.append(f'{h}# {me}\n')
                    need[0] = False
                    body.append(b['text'].strip() + '\n')
                elif b.get('type') == 'tool_use':
                    tools[b.get('id')] = (tool_line(b['name'], b.get('input') or {}), tool_input(b['name'], b.get('input') or {}))
    flush()
    return r

index = []
for d in DIRS:
    for p in sorted(glob.glob(os.path.join(ROOT, d, '*.jsonl'))):
        sid = os.path.basename(p)[:-6]
        r = render(p)
        if not r['nuser']: continue
        title = r['title'] or (r['first_prompt'] or sid).split('\n')[0][:70]
        f0, f1 = local(r['first']), local(r['last'])
        name = f'{f0.strftime("%Y-%m-%d-%H%M")}-{slug(title)}.md'
        subs = []
        for sp in glob.glob(os.path.join(ROOT, d, sid, '**', '*.jsonl'), recursive=True):
            sr = render(sp, sub=True)
            if not sr['body']: continue
            meta = {}
            try: meta = json.load(open(sp[:-6] + '.meta.json'))
            except Exception: pass
            subs.append((sr['first'] or '', meta, sr, os.path.basename(sp)[:-6]))
        subs.sort(key=lambda x: x[0])
        head = [f'# {title}\n',
                f'- Session: `{sid}`',
                f'- Folder: `{r["cwd"] or d}`',
                f'- From {f0.strftime("%Y-%m-%d %H:%M")} to {f1.strftime("%Y-%m-%d %H:%M")}',
                f'- {r["nuser"]} user messages' + (f', {len(subs)} subagent runs (at the end)' if subs else ''),
                '\nTool calls are shown with their input and output; images are in images/.\n', '---\n']
        body = [x for x in r['body'] if x]
        if subs:
            body.append('---\n\n# Subagents\n')
            for ts, meta, sr, aid in subs:
                when = local(ts).strftime('%Y-%m-%d %H:%M') if ts else ''
                body.append(f'## {meta.get("description") or aid} · {meta.get("agentType", "agent")} · {when}\n')
                body.append(f'`{aid}`\n')
                body += [x for x in sr['body'] if x]
        text = '\n'.join(head + body)
        open(os.path.join(OUT, name), 'w', encoding='utf-8').write(text)
        index.append((f0, name, title, f1, r['nuser'], len(text), len(subs)))

index.sort()
with open(os.path.join(OUT, 'README.md'), 'w', encoding='utf-8') as f:
    f.write(f'# Chat sessions\n\nThe Claude Code sessions for {os.path.basename(REPO)} on this machine, as text.\n\n'
            '| Start | End | Session | User messages | Subagents |\n|---|---|---|---|---|\n')
    for f0, name, title, f1, n, size, ns in index:
        f.write(f'| {f0.strftime("%Y-%m-%d %H:%M")} | {f1.strftime("%Y-%m-%d %H:%M")} | [{title}]({name}) | {n} | {ns or ""} |\n')
for f0, name, title, f1, n, size, ns in index: print(name, n, ns, size)
