import json
import os
from pathlib import Path
import select
import signal
import subprocess
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / '.config/pleamar/shells/material/helpers/gallery.py'


class GalleryTests(unittest.TestCase):
    def test_latest_window_cancels_obsolete_work_and_reuses_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / 'bin'
            binary.mkdir()
            events = root / 'events'
            converter = binary / 'magick'
            converter.write_text('#!/usr/bin/python\nimport os,sys,time\nfrom pathlib import Path\nsource=next(value for value in sys.argv if value.endswith("[0]"))\nwith open(os.environ["AUDIT_CONVERSIONS"],"a") as output: output.write(Path(source).name+":"+str(os.getpid())+"\\n")\nif "slow" in source: time.sleep(20)\nPath(sys.argv[-1]).write_bytes(b"preview")\n')
            converter.chmod(0o755)
            sources = {}
            for name in ['slow', 'skipped', 'latest']:
                path = root / (name + '.png')
                path.write_bytes(b'image')
                sources[name] = {'path': str(path), 'revision': '1'}
            environment = dict(os.environ, HOME=str(root), PATH=str(binary) + ':' + os.environ['PATH'], AUDIT_CONVERSIONS=str(events))
            worker = subprocess.Popen(['python', str(HELPER), 'watch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment, bufsize=0)
            def read():
                self.assertTrue(select.select([worker.stdout], [], [], 4)[0], 'preview worker did not respond')
                return json.loads(worker.stdout.readline())
            def send(values):
                worker.stdin.write(json.dumps(values).encode() + b'\n')
                worker.stdin.flush()
            try:
                self.assertTrue(read()['ready'])
                send([sources['slow']])
                deadline = time.monotonic() + 3
                while not events.exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue(events.exists())
                slow_pid = int(events.read_text().split(':')[-1])
                worker.stdin.write(json.dumps([sources['skipped']]).encode() + b'\n' + json.dumps([sources['latest']]).encode() + b'\n')
                worker.stdin.flush()
                result = read()
                self.assertEqual(result['path'], sources['latest']['path'])
                self.assertTrue(Path(result['picture']).is_file())
                with self.assertRaises(ProcessLookupError):
                    os.kill(slow_pid, 0)
                self.assertNotIn('skipped', events.read_text())
                count = len(events.read_text().splitlines())
                send([sources['latest']])
                self.assertEqual(read()['picture'], result['picture'])
                self.assertEqual(len(events.read_text().splitlines()), count)
                send([sources['slow']])
                time.sleep(.1)
                worker.send_signal(signal.SIGTERM)
                self.assertEqual(worker.wait(timeout=3), 0)
                for event in events.read_text().splitlines():
                    with self.assertRaises(ProcessLookupError):
                        os.kill(int(event.split(':')[-1]), 0)
                self.assertEqual(list((root / '.cache/pleamar/material/wallpapers').glob('*.' + str(worker.pid) + '.png')), [])
            finally:
                if worker.poll() is None:
                    worker.terminate()
                    worker.wait(timeout=3)
                for stream in (worker.stdin, worker.stdout, worker.stderr):
                    stream.close()

    def test_converter_dies_when_parent_is_killed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            converter = root / 'magick'
            converter.write_text('#!/usr/bin/python\nimport time\ntime.sleep(20)\n')
            converter.chmod(0o755)
            environment = dict(os.environ, PATH=str(root) + ':' + os.environ['PATH'])
            code = 'import importlib.util,time;from pathlib import Path;s=importlib.util.spec_from_file_location("gallery",' + repr(str(HELPER)) + ');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);p=m.conversion(Path("source.png"),Path("output.png"));print(p.pid,flush=True);time.sleep(20)'
            parent = subprocess.Popen(['python', '-c', code], stdout=subprocess.PIPE, env=environment)
            child = None
            try:
                self.assertTrue(select.select([parent.stdout], [], [], 3)[0])
                child = int(parent.stdout.readline())
                parent.kill()
                parent.wait(timeout=3)
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    status = Path('/proc') / str(child) / 'stat'
                    if not status.exists() or status.read_text().split()[2] == 'Z':
                        break
                    time.sleep(.01)
                else:
                    self.fail('converter survived its worker')
            finally:
                if parent.poll() is None:
                    parent.kill()
                    parent.wait()
                parent.stdout.close()
                if child:
                    try:
                        os.kill(child, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == '__main__':
    unittest.main()
