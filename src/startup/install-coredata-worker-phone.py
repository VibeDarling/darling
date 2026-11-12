from pathlib import Path
import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('--artifact', required=True)
parser.add_argument('--sha256', required=True)
parser.add_argument('--darling', required=True)
parser.add_argument('--cocotron', required=True)
parser.add_argument('--supplement-artifact')
parser.add_argument('--supplement-sha256')
args = parser.parse_args()
base = Path.home()/'pk/feather-sqlite-impl-20261103'
if not (base/'sqlite-worker-control-20261103').is_file():
    raise SystemExit('OWN_MARKER_REQUIRED')
if not re.fullmatch(r'CoreData-[a-f0-9]{7,40}', args.artifact) or not re.fullmatch(r'[a-f0-9]{64}', args.sha256) or any(not re.fullmatch(r'[a-f0-9]{7,40}', value) for value in (args.darling,args.cocotron)):
    raise SystemExit('SOURCE_IDENTITY_REQUIRED')
if bool(args.supplement_artifact) != bool(args.supplement_sha256):
    raise SystemExit('COHERENT_SUPPLEMENT_ARGUMENTS_REQUIRED')
if args.supplement_artifact and (not re.fullmatch(r'CoreDataSupplement-[a-f0-9]{7,40}', args.supplement_artifact) or not re.fullmatch(r'[a-f0-9]{64}', args.supplement_sha256)):
    raise SystemExit('SUPPLEMENT_IDENTITY_REQUIRED')
operator_lock = (base/'.coredata-operator.lock').open('a')
fcntl.flock(operator_lock, fcntl.LOCK_EX)
if (base/'active-fixture.json').exists():
    raise SystemExit('ACTIVE_FIXTURE_REQUIRES_EXACT_HANDLE_AUDIT')
manifest_path = base/'diagnostic-payload/manifest.json'
manifest = json.loads(manifest_path.read_text())
artifact = base/args.artifact

def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

if digest(artifact) != args.sha256:
    raise SystemExit('ARTIFACT_HASH_MISMATCH')
roots = (base/'runtime/libexec/darling', base/'prefix')
for root in roots:
    for component in manifest['components'].values():
        relative = Path(component['relative'])
        if relative.is_absolute() or '..' in relative.parts or digest(root/relative) != component['sha256']:
            raise SystemExit('OLD_COMPONENT_IDENTITY_MISMATCH')
    if digest(root/'usr/lib/swift/libswiftFoundation.dylib') != 'aebf3c00041c5e27b2a8620b4f8fa840fc5af2edb109b356a546c5596d083b98':
        raise SystemExit('OVERLAY_IDENTITY_MISMATCH')
replacements = []
if args.supplement_artifact:
    replacements.append(('CoreDataSupplement', 'usr/lib/swift/libDarlingCoreDataSupplement.dylib', base/args.supplement_artifact, args.supplement_sha256))
replacements.append(('CoreData', manifest['components']['CoreData']['relative'], artifact, args.sha256))
previous_manifest = manifest_path.read_bytes()
staged = []
replaced = []
try:
    for name, relative, source, expected in replacements:
        if digest(source) != expected:
            raise RuntimeError('STAGED_ARTIFACT_IDENTITY_MISMATCH')
        for index, root in enumerate(roots):
            destination = root/relative
            exists = destination.exists() or destination.is_symlink()
            if exists and (destination.is_symlink() or not destination.is_file()):
                raise RuntimeError('REGULAR_COMPONENT_REQUIRED')
            if name not in manifest['components'] and exists:
                raise RuntimeError('UNMANIFESTED_COMPONENT_REQUIRES_AUDIT')
            previous = base/(name+'-before-'+args.cocotron+'-'+str(index))
            if exists:
                if previous.exists():
                    if digest(previous) != digest(destination):
                        raise RuntimeError('BACKUP_IDENTITY_MISMATCH')
                else: shutil.copy2(destination, previous)
            temporary = destination.with_name(destination.name+'.sqlite-worker-new')
            shutil.copy2(source, temporary)
            if digest(temporary) != expected:
                raise RuntimeError('STAGED_COMPONENT_MISMATCH')
            staged.append((destination, temporary, previous if exists else None, expected))
    for destination, temporary, previous, expected in staged:
        os.replace(temporary, destination)
        replaced.append((destination, previous))
    for destination, temporary, previous, expected in staged:
        if digest(destination) != expected:
            raise RuntimeError('SELECTED_COMPONENT_MISMATCH')
    for name, relative, source, expected in replacements:
        manifest['components'][name] = {'relative':relative, 'sha256':expected}
    manifest['source']['CoreDataOverride'] = {
        'darling':args.darling, 'cocotron':args.cocotron,
        'note':'CoreData and source-built Swift supplement worker override; other components retain copied base source'
    }
    temporary_manifest = manifest_path.with_suffix('.worker-new')
    temporary_manifest.write_text(json.dumps(manifest, indent=2)+'\n')
    os.replace(temporary_manifest, manifest_path)
except Exception:
    for destination, previous in reversed(replaced):
        if previous is not None: shutil.copy2(previous, destination)
        elif destination.exists(): destination.unlink()
    manifest_path.write_bytes(previous_manifest)
    for destination, temporary, previous, expected in staged:
        if temporary.exists(): temporary.unlink()
    raise SystemExit('COHERENT_COMPONENT_INSTALL_REJECTED')
print(json.dumps({'selected':[item[0] for item in replacements], 'sha256':{item[0]:item[3] for item in replacements}, 'runtimeAndPrefixVerified':True, 'exclusiveOperator':True}), flush=True)
