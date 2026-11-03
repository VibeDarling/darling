#!/usr/bin/env python3
"""Run authored SDK API assertions with guest output discarded before creation."""
import argparse,hashlib,importlib.util,json,os,socket,subprocess,tempfile,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--base',type=Path,required=True)
p.add_argument('--fixture',type=Path,required=True)
p.add_argument('--fixture-sha256',required=True)
p.add_argument('--expected-positive',type=int,required=True)
p.add_argument('--positive-argument',action='append',default=[])
p.add_argument('--check-invalid',action='store_true')
p.add_argument('--report',type=Path,required=True)
a=p.parse_args();b=a.base.resolve();prefix=b/'prefix'
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
m=json.loads((b/'diagnostic-payload/manifest.json').read_text())
for root in (b/'runtime/libexec/darling',prefix):
    assert (root/'clean-release-control-20261103').is_file()
    for c in m['components'].values():assert digest(root/c['relative'])==c['sha256']
    assert digest(root/'usr/lib/swift/libswiftFoundation.dylib')==m['swift_foundation_overlay_sha256']
assert digest(a.fixture)==a.fixture_sha256
spec=importlib.util.spec_from_file_location('owned_protocol',Path(__file__).with_name('test-boundary-diagnostics.py'))
protocol=importlib.util.module_from_spec(spec);spec.loader.exec_module(protocol)
env={k:v for k,v in os.environ.items() if not k.startswith('DYLD_') and k not in ('DARLING_BOUNDARY_SOCKET','DARLING_STRICT_LINKING')}
env.update(DARLING_INSTALL_PREFIX=str(b/'runtime'),DPREFIX=str(prefix),DARLING_MLDR_PATH=str(b/'native/libmldr.so'),
           DARLING_SERVER_PATH=str(b/'native/libdarlingserver.so'),LD_LIBRARY_PATH=str(b/'native'),
           DARLING_SHM_DIR=str(b/'cache/shm'),DARLING_NO_CORE_DUMPS='1',TMPDIR=str(b/'cache'))
launcher=str(b/'native/libdarling.so');rows=[]
with tempfile.TemporaryDirectory(prefix='fcs-',dir=Path.home()/'.cache') as temporary:
    endpoint=Path(temporary)/'s';mapped='/Volumes/SystemRoot'+str(endpoint);assert len(mapped.encode())<=80
    with socket.socket(socket.AF_UNIX,socket.SOCK_DGRAM) as receiver:
        receiver.bind(str(endpoint));endpoint.chmod(0o600);receiver.settimeout(0.03)
        def drain():
            packets=[]
            while True:
                try:packet=receiver.recv(1025)
                except socket.timeout:return packets
                assert protocol.permitted(packet) and len(packets)<1000
                packets.append(packet.decode('ascii'))
        try:
            for name,extra,expected in [('positive',a.positive_argument,a.expected_positive)]+([('nonkvc',['nonkvc'],133)] if a.check_invalid else []):
                process=subprocess.Popen([launcher,'shell','env','DARLING_BOUNDARY_SOCKET='+mapped,
                    '/Volumes/SystemRoot'+str(a.fixture),*extra],env=env,stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                print(json.dumps({'case':name,'launcherPid':process.pid}),flush=True)
                records=[];notice=time.monotonic()+45
                while process.poll() is None:
                    records+=drain()
                    assert len(records)<=1000
                    if time.monotonic()>=notice:
                        print(json.dumps({'case':name,'running':True,'records':len(records)}),flush=True);notice+=45
                records+=drain()
                assert len(records)<=1000
                row={'case':name,'exit':process.returncode,'expectedExit':expected,'records':records}
                rows.append(row);a.report.write_text(json.dumps({'source':m['source'],'fixtureSha256':a.fixture_sha256,'cases':rows},indent=2)+'\n')
                print(json.dumps(row),flush=True)
        finally:
            shutdown=subprocess.run([launcher,'shutdown'],env=env,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            print(json.dumps({'shutdownExit':shutdown.returncode}),flush=True)
valid=shutdown.returncode==0 and all(r['exit']==r['expectedExit'] for r in rows)
if a.check_invalid:
    valid=valid and rows[-1]['records']==['diag.ready\n','foundation.sort.invalid-keypath\n']
print('PASS_FOUNDATION_SORT_RUNTIME' if valid else 'FAIL_FOUNDATION_SORT_RUNTIME',flush=True)
raise SystemExit(0 if valid else 1)
