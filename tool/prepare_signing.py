"""Create the local release identity once; never print private credentials."""
from pathlib import Path
import secrets
import subprocess

root = Path(__file__).resolve().parents[1]
private = root / 'release-signing'
private.mkdir(exist_ok=True)
properties = private / 'key.properties'
keystore = private / 'pocket-party.p12'
if properties.exists() or keystore.exists():
    if not (properties.exists() and keystore.exists()):
        raise SystemExit('Incomplete signing setup. Preserve existing files and inspect locally.')
    print('Existing release identity preserved.')
else:
    password = secrets.token_urlsafe(36)
    password_file = private / 'password.txt'
    password_file.write_text(password, encoding='utf-8')
    subprocess.run([
        r'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin\keytool.exe',
        '-genkeypair', '-keystore', str(keystore), '-storetype', 'PKCS12',
        '-alias', 'pocket-party', '-keyalg', 'RSA', '-keysize', '3072',
        '-validity', '10000', '-dname', 'CN=Pocket Party',
        '-storepass:file', str(password_file), '-keypass:file', str(password_file),
    ], check=True)
    properties.write_text(
        f'storePassword={password}\nkeyPassword={password}\n'
        'keyAlias=pocket-party\nstoreFile=../release-signing/pocket-party.p12\n',
        encoding='utf-8',
    )
    print('Release identity created in ignored release-signing/. Back up this folder securely.')
