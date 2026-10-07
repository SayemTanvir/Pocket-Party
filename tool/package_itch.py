"""Package an already-built Flutter web app for itch.io's nested iframe URL."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
build = root / 'build' / 'web'
out = root / 'dist' / 'itch'
out.mkdir(parents=True, exist_ok=True)
index = (build / 'index.html').read_text(encoding='utf-8')
if '<base href="/">' not in index:
    raise SystemExit('Expected a root-base Flutter build before itch.io packaging.')
index = index.replace('<base href="/">', '<base href="./">')
files = [p for p in build.rglob('*') if p.is_file() and not p.name.endswith('.map')]
assert len(files) + 2 < 1000
assert sum(p.stat().st_size for p in files) < 500 * 1024 * 1024
assert all(p.stat().st_size < 200 * 1024 * 1024 for p in files)
archive = out / 'pocket-party-web-beta.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in files:
        name = p.relative_to(build).as_posix()
        assert len(name) < 240
        if name == 'index.html':
            z.writestr(name, index)
        else:
            z.write(p, name)
    z.write(root / 'third_party' / 'LETTERPRESS-LICENSE.txt', 'licenses/LETTERPRESS-LICENSE.txt')
    z.writestr('licenses/README.txt', 'English word list: https://github.com/lorenbrichter/Words (CC0).\nFlutter dependency notices: assets/NOTICES.Z (gzip-compressed text).\n')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert '<base href="./">' in z.read('index.html').decode()
    assert {'index.html','flutter_bootstrap.js','main.dart.js'}.issubset(z.namelist())
for name in ['PAGE.md', 'cover.png', 'icon.png']:
    shutil.copy2(root / 'publishing' / 'itch' / name, out / name)
apk = root / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-release.apk'
if not apk.exists():
    raise SystemExit('Build the release APK before packaging.')
shutil.copy2(apk, out / 'pocket-party-android-beta.apk')
hashes = {
    p.name: hashlib.sha256(p.read_bytes()).hexdigest()
    for p in out.iterdir() if p.suffix in ['.zip','.apk','.png']
}
(out / 'SHA256.json').write_text(json.dumps(hashes, indent=2)+'\n', encoding='utf-8')
for p in out.iterdir():
    print(f'{p.name}: {p.stat().st_size / 1024 / 1024:.2f} MiB')
