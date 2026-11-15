from pathlib import Path
import hashlib,json,shutil,sys,datetime
package=Path(__file__).resolve().parent
repo=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
if not (repo/'pubspec.yaml').is_file() or not (repo/'lib/main.dart').is_file():
 raise SystemExit('Run this from your my_new_app directory.')
items=json.loads((package/'FILES.json').read_text())
for item in items:
 target=repo/item['path'];source=package/'source'/item['path']
 actual=hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None
 if actual not in item['accepted_before']+[item['after']]:
  raise SystemExit('Stopped without changing files: '+item['path']+' contains different edits. Keep those edits and request a merge.')
 if hashlib.sha256(source.read_bytes()).hexdigest()!=item['after']:
  raise SystemExit('Damaged package: '+item['path'])
backup=repo.parent/(repo.name+'-stopwatch-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
# Back up every existing destination before writing the first update.
for item in items:
 target=repo/item['path']
 if target.exists():
  saved=backup/item['path'];saved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,saved)
for item in items:
 target=repo/item['path'];target.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(package/'source'/item['path'],target)
print('Updated 14 files, including task stopwatches and version 1.2.1+17. No files deleted.')
print('Backup: '+str(backup))
