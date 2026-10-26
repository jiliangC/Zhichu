#!/usr/bin/env python3
"""Build a signed Zhichu appcast using Sparkle's official generator.

Usage: scripts/appcast.py <archive.zip|dmg> <appcast.xml> [--notes notes.html]
The signing key remains in the login Keychain (account app.zhichu.mac.updates).
Upload the archive to Releases BEFORE committing the generated feed.
"""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
from urllib.parse import urlparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / '.build/artifacts/sparkle/Sparkle/bin'
NS = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
ACCOUNT = 'app.zhichu.mac.updates'


def validate_feed(path, version, build, archive, base):
    channel = ET.parse(path).find('channel')
    if channel is None or channel.findtext('title') != '知处':
        raise ValueError('Refusing an update feed belonging to another application')
    items = channel.findall('item')
    matching = [i for i in items if i.findtext('s:version', namespaces=NS) == build]
    if len(matching) != 1:
        raise ValueError('Expected exactly one entry for this build')
    item = matching[0]
    enclosure = item.find('enclosure')
    if item.findtext('s:shortVersionString', namespaces=NS) != version or enclosure is None:
        raise ValueError('Archive version does not match the application')
    if enclosure.get('url') != base.rstrip('/') + '/' + archive.name:
        raise ValueError('Unexpected archive download URL')
    if enclosure.get('length') != str(archive.stat().st_size) or not enclosure.get('{'+NS['s']+'}edSignature'):
        raise ValueError('Missing archive signature or incorrect length')
    for entry in items:
        download = entry.find('enclosure')
        if download is not None and urlparse(download.get('url', '')).scheme != 'https':
            raise ValueError('All update downloads must use HTTPS')
    return enclosure.get('{'+NS['s']+'}edSignature')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('archive', type=Path)
    parser.add_argument('appcast', type=Path)
    parser.add_argument('--app', type=Path, default=ROOT/'build.noindex/知处.app')
    parser.add_argument('--notes', type=Path, help='Trusted HTML fragment to embed in the signed feed')
    parser.add_argument('--account', default=ACCOUNT)
    args = parser.parse_args()
    archive, output = args.archive.resolve(), args.appcast.resolve()
    info = plistlib.loads((args.app/'Contents/Info.plist').read_bytes())
    if info['CFBundleIdentifier'] != 'app.zhichu.mac':
        parser.error('Expected the Zhichu production bundle identifier')
    version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
    if archive.suffix not in ('.zip', '.dmg') or version not in archive.name:
        parser.error('Archive must be a ZIP or DMG named with the application version')
    base = os.environ.get('DOWNLOAD_BASE', f'https://github.com/jiliangC/Zhichu/releases/download/v{version}/')
    if urlparse(base).scheme != 'https' or not urlparse(base).netloc:
        parser.error('DOWNLOAD_BASE must be an absolute HTTPS URL')
    public = subprocess.check_output([str(TOOLS/'generate_keys'), '--account', args.account, '-p'], text=True).strip()
    if public != info.get('SUPublicEDKey'):
        parser.error('Keychain public key differs from the key embedded in the application')
    if not info.get('SURequireSignedFeed') or not info.get('SUVerifyUpdateBeforeExtraction'):
        parser.error('The application must require signed feeds and pre-extraction verification')
    with tempfile.TemporaryDirectory(prefix='zhichu-appcast-') as tmp:
        stage = Path(tmp)
        shutil.copy2(archive, stage/archive.name)
        feed = stage/'appcast.xml'
        if output.exists():
            if ET.parse(output).findtext('channel/title') != '知处':
                parser.error('Refusing an existing feed belonging to another application')
            shutil.copy2(output, feed)
        if args.notes:
            shutil.copy2(args.notes, (stage/archive.name).with_suffix('.html'))
        subprocess.run([str(TOOLS/'generate_appcast'), '--account', args.account,
                        '--download-url-prefix', base.rstrip('/')+'/', '--link', 'https://github.com/jiliangC/Zhichu',
                        '--maximum-deltas', '0', '--maximum-versions', '0', '--embed-release-notes',
                        '-o', str(feed), str(stage)], check=True)
        signature = validate_feed(feed, version, build, archive, base)
        subprocess.run([str(TOOLS/'sign_update'), '--account', args.account, '--verify', str(archive), signature], check=True)
        subprocess.run([str(TOOLS/'sign_update'), '--account', args.account, '--verify', str(feed)], check=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        # Never leave a partially written or unsigned feed at the public path.
        temp_output = output.with_suffix('.xml.tmp')
        shutil.copy2(feed, temp_output)
        temp_output.replace(output)
    print(f'{output}: 知处 {version} ({build}) → {base.rstrip("/")}/{archive.name}')


if __name__ == '__main__':
    main()
