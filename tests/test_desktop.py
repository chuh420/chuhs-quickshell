import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / '.config/quickshell/material/helpers/desktop.py'


class DesktopWorkerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.apps = self.root / 'data/applications'
        self.apps.mkdir(parents=True)
        self.entry = self.apps / 'audit.desktop'
        self.entry.write_text('[Desktop Entry]\nType=Application\nName=Калькулятор\nGenericName=Arithmetic\nComment=Numbers and sums\nExec=/usr/bin/true\n')
        environment = dict(os.environ, HOME=str(self.root), XDG_DATA_HOME=str(self.root / 'data'), XDG_DATA_DIRS=str(self.root / 'empty'), XDG_CONFIG_HOME=str(self.root / 'config'), XDG_CACHE_HOME=str(self.root / 'cache'))
        self.worker = subprocess.Popen(['python', str(HELPER), 'watch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment, bufsize=0)
        self.addCleanup(self.stop)
        self.read()

    def stop(self):
        if self.worker.poll() is None:
            self.worker.stdin.close()
            try:
                self.worker.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.worker.kill()
                self.worker.wait()
        for stream in (self.worker.stdin, self.worker.stdout, self.worker.stderr):
            stream.close()

    def read(self):
        ready, _, _ = select.select([self.worker.stdout], [], [], 5)
        self.assertTrue(ready, 'worker did not respond')
        line = self.worker.stdout.readline()
        self.assertTrue(line, 'worker exited')
        return json.loads(line)

    def request(self, **values):
        self.worker.stdin.write(json.dumps(values).encode() + b'\n')
        self.worker.stdin.flush()
        while True:
            result = self.read()
            if result.get('generation') == values.get('generation') or 'error' in result:
                return result

    def test_unicode_and_metadata_search(self):
        for n, query in enumerate(['КАЛЬКУЛЯТОР', 'калькулятор', 'ARITHMETIC', 'sums'], 1):
            result = self.request(query=query, generation=n)
            self.assertEqual([app['id'] for app in result['apps']], ['audit.desktop'])
        self.assertEqual(self.request(query='missing', generation=9)['apps'], [])

    def test_hidden_persistence_and_invalid_requests(self):
        result = self.request(query='', generation=1, hidden=['audit.desktop'])
        self.assertEqual(result['hidden'], ['audit.desktop'])
        state = self.root / '.local/state/quickshell/material/hidden-applications.json'
        self.assertEqual(json.loads(state.read_text()), ['audit.desktop'])
        self.assertIn('error', self.request(query='', generation=2, hidden='invalid'))
        self.assertIn('error', self.request(query=123, generation=3))
        self.assertEqual(self.request(query='', generation=4)['hidden'], ['audit.desktop'])
        state.write_text(json.dumps({'invalid': True}))
        self.assertEqual(self.request(query='', generation=5)['hidden'], [])
        state.write_text(json.dumps([12, 'legacy', 'audit.desktop']))
        self.assertEqual(self.request(query='', generation=6)['hidden'], ['legacy.desktop', 'audit.desktop'])

    def test_catalog_refresh(self):
        self.request(query='updated', generation=1)
        self.entry.write_text('[Desktop Entry]\nType=Application\nName=updated\nExec=/usr/bin/true\n')
        for _ in range(10):
            result = self.read()
            if any(app['name'] == 'updated' for app in result['apps']):
                return
        self.fail('desktop entry update did not reach the catalog')

    def test_batched_requests_and_clean_eof(self):
        requests = [dict(query='калькулятор', generation=n) for n in range(1, 6)]
        self.worker.stdin.write(b''.join(json.dumps(value, ensure_ascii=False).encode() + b'\n' for value in requests))
        self.worker.stdin.flush()
        received = set()
        while received != set(range(1, 6)):
            value = self.read()
            received.add(value['generation'])
            self.assertEqual(value['apps'][0]['id'], 'audit.desktop')
        self.worker.stdin.close()
        self.assertEqual(self.worker.wait(timeout=3), 0)


if __name__ == '__main__':
    unittest.main()
