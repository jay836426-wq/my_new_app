from pathlib import Path
import datetime, hashlib, json, shutil, sys
package=Path(__file__).resolve().parent
repo=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
if not (repo/'pubspec.yaml').is_file() or not (repo/'lib/main.dart').is_file():
    raise SystemExit('Run this from the my_new_app project directory.')
files=json.loads((package/'FILES.json').read_text())
for item in files:
    target=repo/item['path']
    actual=hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else None
    if actual not in (item['before'],item['after']):
        raise SystemExit('Stopped without changing files: '+item['path']+' differs from build 14. Keep your edits and ask for a merge.')
    if hashlib.sha256((package/'source'/item['path']).read_bytes()).hexdigest()!=item['after']:
        raise SystemExit('Package file is damaged: '+item['path'])
backup=repo.parent/(repo.name+'-queue-backup-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
for item in files:
    target=repo/item['path']
    if target.exists():
        saved=backup/item['path'];saved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,saved)
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(package/'source'/item['path'],target)
print('Updated 6 files. No files deleted. Backup: '+str(backup))
