#!/usr/bin/env python3
"""Verify a committed full SwiftUI source recipe in separate private storage."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(inputs, runtime, workspace):
    if inputs.get('schema_version') != 1 or inputs.get('architecture') != 'arm64':
        raise ValueError('full SwiftUI integration requires schema 1 and Darwin arm64')
    if not runtime.is_dir() or workspace == runtime or runtime in workspace.parents:
        raise ValueError('workspace must be separate from an existing read-only guest runtime')
    contract = inputs.get('integration', {})
    targets = {t['name']: t for t in inputs.get('targets', [])}
    if len(targets) != len(inputs.get('targets', [])):
        raise ValueError('duplicate target names')
    for role in ('link_targets', 'install_targets'):
        names = contract.get(role, [])
        if not names or any(name not in targets for name in names):
            raise ValueError('full SwiftUI manifest must declare existing ' + role)
    if not inputs.get('sources') or any(s.get('allow_recorded_changes') for s in inputs['sources']):
        raise ValueError('committed clean source pins required')
    for target in targets.values():
        if not target.get('inputs') or not target.get('outputs'):
            raise ValueError('every target must declare real inputs and outputs')
        for output in target['outputs']:
            path = Path(output.replace('{workspace}', str(workspace)).replace('{runtime_root}', str(runtime))).resolve()
            if workspace not in path.parents:
                raise ValueError('target output escapes private workspace: ' + str(path))
    for name in contract['link_targets']:
        argv = targets[name]['argv']
        if any('dynamic_lookup' in arg or 'undefined suppress' in arg for arg in argv):
            raise ValueError('strict undefined-symbol resolution required')
    installed = []
    for name in contract['install_targets']:
        for output in targets[name]['outputs']:
            path = Path(output.replace('{workspace}', str(workspace))).resolve()
            if workspace / 'image' not in path.parents:
                raise ValueError('install output must be under workspace/image')
            installed.append(path)
    if not any('SwiftUI.framework' in str(p) and p.name == 'SwiftUI' for p in installed):
        raise ValueError('manifest must install the actual SwiftUI framework image')
    return installed


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--builder-repo', type=Path, required=True)
    p.add_argument('--builder-commit', required=True)
    p.add_argument('--inputs', type=Path, required=True)
    p.add_argument('--runtime-root', type=Path, required=True)
    p.add_argument('--workspace', type=Path, required=True)
    p.add_argument('--jobs', type=int, choices=(1, 2), default=2)
    p.add_argument('--configure-only', action='store_true')
    a = p.parse_args()
    repo, runtime, workspace = (x.resolve() for x in (a.builder_repo, a.runtime_root, a.workspace))
    if len(a.builder_commit) != 40 or any(c not in '0123456789abcdef' for c in a.builder_commit):
        raise ValueError('exact builder commit required')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo, text=True).strip()
    if head != a.builder_commit or dirty:
        raise ValueError('builder must be clean at its exact committed pin')
    config = json.loads(a.inputs.read_text())
    installed = validate(config, runtime, workspace)
    if not a.configure_only and config['integration'].get('runtime_ready') is not True:
        raise ValueError('owner manifest does not attest a ready full link/install closure')
    if workspace.exists():
        raise ValueError('fresh verification requires a nonexistent workspace')
    command = [sys.executable, str(repo / 'build.py'), '--inputs', str(a.inputs.resolve()),
               '--runtime-root', str(runtime), '--workspace', str(workspace), '--jobs', str(a.jobs)]
    manifest = dict(schema_version=1, builder_commit=head, builder_repo=str(repo),
                    builder_sha256=digest(repo / 'build.py'), inputs_sha256=digest(a.inputs),
                    runtime_root=str(runtime), command=command, actual_app_verified=False)
    workspace.mkdir(parents=True)
    try:
        if a.configure_only:
            subprocess.run(command + ['--configure-only'], check=True)
            manifest['status'] = 'configured-not-built'
        else:
            subprocess.run(command, check=True)
            first = json.loads((workspace / 'result.json').read_text())
            manifest['fresh_result'] = first
            if first.get('status') != 'passed' or first.get('build_exit') != 0:
                raise ValueError('fresh SwiftUI closure failed')
            subprocess.run(command, check=True)
            repeat = json.loads((workspace / 'result.json').read_text())
            manifest['incremental_result'] = repeat
            if repeat.get('status') != 'passed' or not repeat.get('incremental_no_work'):
                raise ValueError('repeat SwiftUI build has pending work or failed')
            manifest['installed_files'] = [dict(path=str(path.relative_to(workspace / 'image')),
                                               sha256=digest(path), bytes=path.stat().st_size)
                                           for path in installed]
            manifest['status'] = 'fresh-and-incremental-passed'
    except Exception as e:
        manifest.update(status='failed', error=str(e))
        raise
    finally:
        (workspace / 'prefix-tooling-swiftui.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(workspace / 'prefix-tooling-swiftui.json')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as e:
        sys.exit('error: ' + str(e))
