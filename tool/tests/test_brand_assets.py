import hashlib
import json
import struct
import subprocess
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANDROID = "{http://schemas.android.com/apk/res/android}"


def png_header(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"PNG inválido: {path}")
    return struct.unpack(">IIBB", data[16:26])


class BrandAssetsTest(unittest.TestCase):
    def test_generated_resources_match_vector_source(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "tool/generate_brand_assets.py"), "--check"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata = json.loads((ROOT / "assets/branding/resources.json").read_text())
        self.assertGreater(len(metadata["files"]), 60)
        self.assertEqual(
            metadata["source_sha256"],
            hashlib.sha256((ROOT / metadata["source"]).read_bytes()).hexdigest(),
        )

    def test_source_is_simple_vector_with_four_camera_views(self):
        root = ET.parse(ROOT / "assets/logo.svg").getroot()
        self.assertEqual(root.attrib["viewBox"], "0 0 512 512")
        paths = root.findall("{http://www.w3.org/2000/svg}path")
        self.assertEqual(len(paths), 4)
        self.assertEqual(paths[0].attrib["fill-rule"], "evenodd")
        for item in root.iter():
            self.assertIn(item.tag.split("}")[-1], ("svg", "rect", "path"))

    def test_apple_icons_have_correct_dimensions_and_no_ios_alpha(self):
        for platform in ("ios", "macos"):
            folder = ROOT / platform / "Runner/Assets.xcassets/AppIcon.appiconset"
            for item in json.loads((folder / "Contents.json").read_text())["images"]:
                size = round(
                    float(item["size"].split("x")[0]) * float(item["scale"].rstrip("x"))
                )
                width, height, _, color_type = png_header(folder / item["filename"])
                self.assertEqual((width, height), (size, size), item["filename"])
                if platform == "ios":
                    self.assertEqual(
                        color_type, 2, "Ícones iOS devem ser RGB sem canal alfa"
                    )

    def test_windows_icon_includes_native_sizes_for_shell_and_installer(self):
        raw = (ROOT / "windows/runner/resources/app_icon.ico").read_bytes()
        reserved, icon_type, count = struct.unpack_from("<HHH", raw)
        self.assertEqual((reserved, icon_type), (0, 1))
        sizes = set()
        for index in range(count):
            width, height, _, _, planes, depth, length, offset = struct.unpack_from(
                "<BBBBHHII", raw, 6 + index * 16
            )
            sizes.add(width or 256)
            self.assertEqual(width, height)
            self.assertEqual((planes, depth), (1, 32))
            self.assertLessEqual(offset + length, len(raw))
            self.assertEqual(raw[offset : offset + 8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(sizes, {16, 20, 24, 32, 40, 48, 64, 128, 256})

    def test_android_adaptive_icon_and_monochrome_preserve_paths(self):
        res = ROOT / "android/app/src/main/res"
        source = ET.parse(ROOT / "assets/logo.svg").getroot()
        vector = ET.parse(res / "drawable/ic_launcher_foreground.xml").getroot()
        group = vector.find("group")
        self.assertEqual(group.attrib[ANDROID + "scaleX"], "0.62")
        self.assertEqual(group.attrib[ANDROID + "scaleY"], "0.62")
        expected = [
            item.attrib["d"]
            for item in source.findall("{http://www.w3.org/2000/svg}path")
        ]
        actual = [item.attrib[ANDROID + "pathData"] for item in group.findall("path")]
        self.assertEqual(actual, expected)
        for version in (26, 33):
            icon = ET.parse(res / f"mipmap-anydpi-v{version}/ic_launcher.xml").getroot()
            self.assertEqual(
                icon.find("background").attrib[ANDROID + "drawable"],
                "@color/brand_blue",
            )
            self.assertIsNotNone(icon.find("foreground"))
            if version >= 33:
                self.assertIsNotNone(icon.find("monochrome"))

    def test_linux_icons_match_source_and_cover_desktop_sizes(self):
        folder = ROOT / "linux/icons/hicolor"
        for size in (16, 24, 32, 48, 64, 128, 256, 512):
            width, height, _, _ = png_header(
                folder / f"{size}x{size}/apps/rtsp-hub.png"
            )
            self.assertEqual((width, height), (size, size))
        self.assertEqual(
            (folder / "scalable/apps/rtsp-hub.svg").read_bytes(),
            (ROOT / "assets/logo.svg").read_bytes(),
        )

    def test_android_launch_uses_brand_in_light_and_dark_modes(self):
        res = ROOT / "android/app/src/main/res"
        for folder in ("values-v31", "values-night-v31"):
            theme = ET.parse(res / folder / "styles.xml").getroot().find("style")
            items = {item.attrib["name"]: item.text for item in theme.findall("item")}
            self.assertEqual(
                items["android:windowSplashScreenAnimatedIcon"],
                "@drawable/ic_launcher_foreground",
            )
            self.assertEqual(
                items["android:windowSplashScreenIconBackgroundColor"],
                "@color/brand_blue",
            )
            self.assertNotIn("android:windowSplashScreenAnimationDuration", items)
        for density, size in (
            ("mdpi", 96),
            ("hdpi", 144),
            ("xhdpi", 192),
            ("xxhdpi", 288),
            ("xxxhdpi", 384),
        ):
            self.assertEqual(
                png_header(res / f"drawable-{density}/brand_splash.png")[:2],
                (size, size),
            )
        for folder in ("drawable", "drawable-v21"):
            background = ET.parse(res / folder / "launch_background.xml").getroot()
            self.assertEqual(
                background.find("item").attrib[ANDROID + "drawable"],
                "@color/brand_launch_background",
            )
            self.assertEqual(
                background.find("item/bitmap").attrib[ANDROID + "src"],
                "@drawable/brand_splash",
            )

    def test_ios_launch_is_centered_and_has_light_and_dark_backgrounds(self):
        runner = ROOT / "ios/Runner"
        storyboard = ET.parse(runner / "Base.lproj/LaunchScreen.storyboard").getroot()
        image = storyboard.find(".//imageView")
        self.assertEqual(image.attrib["image"], "LaunchImage")
        self.assertEqual(image.attrib["contentMode"], "scaleAspectFit")
        constraints = image.findall("constraints/constraint")
        self.assertEqual(
            {
                item.attrib["firstAttribute"]: item.attrib["constant"]
                for item in constraints
            },
            {"width": "96", "height": "96"},
        )
        colors = json.loads(
            (
                runner / "Assets.xcassets/LaunchBackground.colorset/Contents.json"
            ).read_text()
        )["colors"]
        self.assertEqual(len(colors), 2)
        self.assertEqual(colors[1]["appearances"][0]["value"], "dark")

    def test_windows_installer_uses_native_multi_resolution_icon(self):
        installer = (ROOT / "tool/windows-installer.iss").read_text()
        self.assertIn(
            "SetupIconFile=..\\windows\\runner\\resources\\app_icon.ico", installer
        )
        self.assertIn("UninstallDisplayIcon={app}\\rtsp_hub.exe", installer)


if __name__ == "__main__":
    unittest.main()
