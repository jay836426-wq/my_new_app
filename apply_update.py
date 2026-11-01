#!/usr/bin/env python3
"""Copy only this update's listed files after making a backup of existing ones."""
import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('project',type=Path,help='Your existing my_new_app folder')
args=parser.parse_args()
project=args.project.expanduser().resolve()
bundle=Path(__file__).resolve().parent
if not (project/'pubspec.yaml').is_file():
    parser.error('Choose the project folder that contains pubspec.yaml.')
if 'name: TrakOn' not in (project/'pubspec.yaml').read_text():
    parser.error('This update expects the TrakOn package. No files were changed.')
manifest=json.loads((bundle/'FILES.json').read_text())
for entry in manifest:
    path=Path(entry['path'])
    if path.is_absolute() or '..' in path.parts or path.parts[0] not in {'lib','test','pubspec.yaml'}:
        parser.error('Invalid update path. No files were changed.')
    source=bundle/path
    if hashlib.sha256(source.read_bytes()).hexdigest()!=entry['sha256']:
        parser.error('An update file changed or is incomplete: '+str(path))
backup=project.parent/('TrakOn_before_1_2_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
backup.mkdir()
records=[]
for entry in manifest:
    path=Path(entry['path']);existing=project/path
    if existing.is_file():
        dest=backup/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(existing,dest)
    records.append({'path':str(path),'existed':existing.is_file()})
(backup/'BACKUP_FILES.json').write_text(json.dumps(records,indent=2))
# No existing files are touched until every backup has succeeded.
for entry in manifest:
    path=Path(entry['path']);dest=project/path
    dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(bundle/path,dest)
print(f'Installed {len(manifest)} files into {project}')
print(f'Backup of replaced files: {backup}')
print('Next, run flutter pub get, flutter analyze, and flutter test in your project.')
