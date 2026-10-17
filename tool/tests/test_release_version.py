import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_version import release_metadata


class ReleaseMetadataTest(unittest.TestCase):
    def test_versions_match_the_tag_and_build_counter(self):
        self.assertEqual(release_metadata('v0.0.4', '27'), {'version': '0.0.4', 'build_number': '27'})
        self.assertEqual(release_metadata('v1.20.300', '28')['version'], '1.20.300')

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
