import json
import sys
from tempfile import TemporaryDirectory
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_version import release_metadata, write_linux_version


class ReleaseMetadataTest(unittest.TestCase):
    def test_versions_match_the_tag_and_build_counter(self):
        self.assertEqual(release_metadata('v0.0.4', '27'), {'version': '0.0.4', 'build_number': '27'})
        self.assertEqual(release_metadata('v1.20.300', '28')['version'], '1.20.300')

    def test_native_linux_metadata_matches_build_overrides(self):
        with TemporaryDirectory() as directory:
            target = Path(directory) / 'data' / 'flutter_assets' / 'version.json'
            target.parent.mkdir(parents=True)
            target.write_text(json.dumps({'app_name': 'rtsp_hub', 'version': '0.0.1'}), encoding='utf-8')
            write_linux_version(directory, '0.0.4', '27')
            information = json.loads(target.read_text(encoding='utf-8'))
            self.assertEqual(information['version'], '0.0.4')
            self.assertEqual(information['build_number'], '27')
            self.assertEqual(information['app_name'], 'rtsp_hub')
            previous = target.read_bytes()
            with self.assertRaises(ValueError):
                write_linux_version(directory, 'bad', '27')
            self.assertEqual(target.read_bytes(), previous)

    def test_rejects_tags_that_cannot_be_shared_by_all_native_targets(self):
        for tag in ['v1', '1.2.3', 'v1.2.3-rc.1', 'v01.2.3', 'v1.2.70000', 'v1.2.3\ninjected=1']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_metadata(tag, '10')

    def test_build_numbers_fit_windows_and_are_not_silently_truncated(self):
        for number in ['0', '-1', '1.2', '65536', '1\nextra=1', '']:
            with self.subTest(number=number), self.assertRaises(ValueError):
                release_metadata('v1.2.3', number)
        self.assertEqual(release_metadata('v1.2.3', '65535')['build_number'], '65535')


if __name__ == '__main__':
    unittest.main()
