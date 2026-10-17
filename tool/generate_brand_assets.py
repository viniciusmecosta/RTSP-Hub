import argparse
from copy import deepcopy
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/logo.svg'
MANIFEST = ROOT / 'assets/branding/resources.json'
SVG = 'http://www.w3.org/2000/svg'
ANDROID = 'http://schemas.android.com/apk/res/android'
BLUE = '#1764ED'
GENERATED = {}


def write(relative, data):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = data.encode('utf-8') if isinstance(data, str) else data
    target.write_bytes(raw)
    GENERATED[relative] = hashlib.sha256(raw).hexdigest()


def svg_bytes(root):
    ET.register_namespace('', SVG)
    return ET.tostring(root, encoding='utf-8')


def icon_source(square=False, padding=0, mark_scale=1):
    source = ET.parse(SOURCE).getroot()
    source.set('width', '512')
    source.set('height', '512')
    background = source.find(f'{{{SVG}}}rect')
    if square:
        background.set('rx', '0')
    if mark_scale != 1:
        group = ET.Element(f'{{{SVG}}}g', {'transform': f'translate({256 * (1-mark_scale)} {256 * (1-mark_scale)}) scale({mark_scale})'})
        for item in list(source.findall(f'{{{SVG}}}path')):
            source.remove(item)
            group.append(item)
        source.append(group)
    if padding:
        group = ET.Element(f'{{{SVG}}}g', {'transform': f'translate({padding} {padding}) scale({(512-2*padding)/512})'})
        for item in list(source):
            source.remove(item)
            group.append(item)
        source.append(group)
    return svg_bytes(source)


@lru_cache(maxsize=128)
def render(svg, size, opaque=False):
    try:
        import cairo
        import gi
        gi.require_version('Rsvg', '2.0')
        from gi.repository import Rsvg
    except ImportError:
        raise SystemExit('Para regenerar a marca no Linux, instale python3-cairo, python3-gi e gir1.2-rsvg-2.0. A validação --check não requer esses pacotes.')
    from io import BytesIO
    surface = cairo.ImageSurface(cairo.FORMAT_RGB24 if opaque else cairo.FORMAT_ARGB32, size, size)
    context = cairo.Context(surface)
    viewport = Rsvg.Rectangle()
    viewport.x, viewport.y, viewport.width, viewport.height = 0, 0, size, size
    handle = Rsvg.Handle.new_from_data(svg)
    handle.render_document(context, viewport)
    stream = BytesIO()
    surface.write_to_png(stream)
    return stream.getvalue()


def generate_shared():
    write('assets/logo.png', render(icon_source(), 1024))
    source = ET.parse(SOURCE).getroot()
    source.remove(source.find(f'{{{SVG}}}rect'))
    source.set('aria-label', 'RTSP Hub — Mosaico')
    for color, name in ((BLUE, 'mark'), ('#FFFFFF', 'mark-white')):
        mark = deepcopy(source)
        for item in mark.findall(f'{{{SVG}}}path'):
            item.set('fill', color)
        write(f'assets/branding/{name}.svg', svg_bytes(mark))


def android_vector():
    paths = ET.parse(SOURCE).getroot().findall(f'{{{SVG}}}path')
    vector = ET.Element('vector', {'xmlns:android': ANDROID, 'android:width': '108dp', 'android:height': '108dp', 'android:viewportWidth': '512', 'android:viewportHeight': '512'})
    group = ET.SubElement(vector, 'group', {'android:pivotX': '256', 'android:pivotY': '256', 'android:scaleX': '0.62', 'android:scaleY': '0.62'})
    for item in paths:
        ET.SubElement(group, 'path', {'android:fillColor': '#FFFFFF', 'android:fillType': item.get('fill-rule', 'nonZero').replace('evenodd', 'evenOdd'), 'android:pathData': item.attrib['d']})
    return ET.tostring(vector, encoding='unicode') + '\n'


def generate_android():
    root = 'android/app/src/main/res'
    for density, scale in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        write(f'{root}/mipmap-{density}/ic_launcher.png', render(icon_source(), round(48 * scale)))
        write(f'{root}/drawable-{density}/brand_splash.png', render(icon_source(), round(96 * scale)))
    write(f'{root}/drawable/ic_launcher_foreground.xml', android_vector())
    for version in (26, 33):
        monochrome = '\n    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>' if version >= 33 else ''
        write(f'{root}/mipmap-anydpi-v{version}/ic_launcher.xml', f'<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="{ANDROID}">\n    <background android:drawable="@color/brand_blue"/>\n    <foreground android:drawable="@drawable/ic_launcher_foreground"/>{monochrome}\n</adaptive-icon>\n')
    for night, color in (('', '#F7F9FD'), ('-night', '#0B1220')):
        write(f'{root}/values{night}/brand_colors.xml', f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="brand_blue">{BLUE}</color>\n    <color name="brand_launch_background">{color}</color>\n</resources>\n')


def generate_apple():
    for platform, square, padding, opaque in (('ios', True, 0, True), ('macos', False, 32, False)):
        folder = f'{platform}/Runner/Assets.xcassets/AppIcon.appiconset'
        catalog = json.loads((ROOT / folder / 'Contents.json').read_text())
        for item in catalog['images']:
            size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
            write(f'{folder}/{item["filename"]}', render(icon_source(square, padding), size, opaque))
    for scale, suffix in ((1, ''), (2, '@2x'), (3, '@3x')):
        write(f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png', render(icon_source(), 96 * scale))


def generate_desktop():
    sizes = (16, 20, 24, 32, 40, 48, 64, 128, 256)
    images = [render(icon_source(), size) for size in sizes]
    entries = []
    offset = 6 + len(sizes) * 16
    for size, image in zip(sizes, images):
        entries.append(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(image), offset))
        offset += len(image)
    ico = struct.pack('<HHH', 0, 1, len(sizes)) + b''.join(entries) + b''.join(images)
    write('windows/runner/resources/app_icon.ico', ico)
    for size in (16, 24, 32, 48, 64, 128, 256, 512):
        write(f'linux/icons/hicolor/{size}x{size}/apps/rtsp-hub.png', render(icon_source(), size))
    write('linux/icons/pixmaps/rtsp-hub.png', render(icon_source(), 256))
    write('linux/icons/hicolor/scalable/apps/rtsp-hub.svg', SOURCE.read_bytes())


def generate_web():
    write('web/favicon.png', render(icon_source(), 32))
    for size in (192, 512):
        write(f'web/icons/Icon-{size}.png', render(icon_source(), size))
        write(f'web/icons/Icon-maskable-{size}.png', render(icon_source(square=True, mark_scale=0.8), size, opaque=True))


def check():
    try:
        metadata = json.loads(MANIFEST.read_text())
        if metadata['source_sha256'] != hashlib.sha256(SOURCE.read_bytes()).hexdigest():
            raise ValueError('O SVG mudou. Execute a geração dos recursos da marca.')
        for filename, digest in metadata['files'].items():
            if hashlib.sha256((ROOT / filename).read_bytes()).hexdigest() != digest:
                raise ValueError(f'Recurso divergente: {filename}')
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print(f'{len(metadata["files"])} recursos da marca sincronizados com assets/logo.svg.')
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    options = parser.parse_args()
    if options.check:
        return check()
    generate_shared()
    generate_android()
    generate_apple()
    generate_desktop()
    generate_web()
    metadata = {'source': 'assets/logo.svg', 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'files': dict(sorted(GENERATED.items()))}
    MANIFEST.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n')
    return check()


if __name__ == '__main__':
    raise SystemExit(main())
