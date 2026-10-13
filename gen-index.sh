#!/usr/bin/env bash
# Regenerate Packages, Packages.gz, Release and the GPG signatures from the .deb files in debs/.
# Usage: REPO_GPG_KEY=<fingerprint> ./gen-index.sh
set -euo pipefail
cd "$(dirname "$0")"
KEY="${REPO_GPG_KEY:?set REPO_GPG_KEY to the signing key fingerprint}"
: > Packages
for deb in debs/*.deb; do
  [ -f "$deb" ] || continue
  dpkg-deb -f "$deb" >> Packages
  printf 'Filename: %s\nSize: %s\nMD5sum: %s\nSHA256: %s\n\n' "$deb" "$(stat -c%s "$deb")" \
    "$(md5sum "$deb" | cut -d' ' -f1)" "$(sha256sum "$deb" | cut -d' ' -f1)" >> Packages
done
gzip -9nfk Packages
python3 - <<'PY'
import hashlib, datetime
files = ['Packages', 'Packages.gz']
lines = ['Origin: rocketkid300', 'Label: Better Music Repo', 'Suite: stable', 'Codename: ios',
         'Architectures: iphoneos-arm64', 'Components: main',
         'Description: Better Music - iOS 26 look for Apple Music on iOS 15 (Dopamine, rootless)',
         'Date: ' + datetime.datetime.now(datetime.timezone.utc).strftime('%a, %d %b %Y %H:%M:%S UTC')]
for algo, name in (('md5', 'MD5Sum'), ('sha256', 'SHA256')):
    lines.append(name + ':')
    for f in files:
        d = open(f, 'rb').read()
        lines.append(' %s %16d %s' % (hashlib.new(algo, d).hexdigest(), len(d), f))
open('Release', 'w').write('\n'.join(lines) + '\n')
PY
rm -f InRelease Release.gpg
gpg --batch --yes --pinentry-mode loopback --default-key "$KEY" --clearsign --output InRelease Release
gpg --batch --yes --pinentry-mode loopback --default-key "$KEY" --detach-sign --armor --output Release.gpg Release
gpg --batch --verify Release.gpg Release
echo "indexed: $(grep -c '^Package:' Packages) package(s)"
