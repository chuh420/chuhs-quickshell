import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / '.config/pleamar/shells/material/helpers/desktop.py'


class TerminalLaunchTests(unittest.TestCase):
    def test_field_codes_arguments_and_working_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apps = root / 'data/applications'
            apps.mkdir(parents=True)
            binary = root / 'bin'
            binary.mkdir()
            output = root / 'result.json'
            kitty = binary / 'kitty'
            kitty.write_text('#!/usr/bin/python\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ["AUDIT_LAUNCH_RESULT"]).write_text(json.dumps({"args":sys.argv[1:],"cwd":os.getcwd()}))\n')
            kitty.chmod(0o755)
            work = root / 'working directory'
            work.mkdir()
            entry = apps / 'audit.desktop'
            entry.write_text('[Desktop Entry]\nType=Application\nName=Calculator %k\nTerminal=true\nIcon=calculator\nPath=' + str(work) + '\nExec=/usr/bin/true %c %k %i %% "two words" "$(touch injected)" %f %d %D %n %N %v %m\n')
            environment = dict(os.environ, HOME=str(root), PATH=str(binary) + ':' + os.environ['PATH'], XDG_DATA_HOME=str(root / 'data'), XDG_DATA_DIRS=str(root / 'empty'), AUDIT_LAUNCH_RESULT=str(output), LC_ALL='C.UTF-8')
            subprocess.run(['python', str(HELPER), 'launch', 'audit.desktop'], env=environment, check=True, capture_output=True, timeout=5)
            deadline = time.monotonic() + 3
            while not output.exists() and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(output.exists())
            result = json.loads(output.read_text())
            self.assertEqual(result['args'], ['-e', '/usr/bin/true', 'Calculator %k', str(entry), '--icon', 'calculator', '%', 'two words', '$(touch injected)'])
            self.assertEqual(result['cwd'], str(work))
            self.assertFalse((work / 'injected').exists())

    def test_invalid_field_codes_do_not_launch(self):
        import importlib.util
        from gi.repository import Gio
        spec = importlib.util.spec_from_file_location('desktop', HELPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            entry = Path(temporary) / 'test.desktop'
            for command in ['/usr/bin/true %z', '/usr/bin/true %', '/usr/bin/true %F %u', '/usr/bin/true prefix%i']:
                with self.subTest(command=command):
                    entry.write_text('[Desktop Entry]\nType=Application\nName=test\nExec=' + command + '\n')
                    app = Gio.DesktopAppInfo.new_from_filename(str(entry))
                    self.assertIsNotNone(app)
                    with self.assertRaises(ValueError):
                        module.terminal_arguments(app)


if __name__ == '__main__':
    unittest.main()
