import json
import os
from pathlib import Path
import re
import sys


def release_metadata(tag, build_number):
    match = re.fullmatch(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', tag)
    if match is None or any(int(part) > 65535 for part in match.groups()):
        raise ValueError('Use uma tag estável no formato vMAJOR.MINOR.PATCH, com componentes até 65535.')
    if not re.fullmatch(r'[1-9][0-9]*', build_number) or int(build_number) > 65535:
        raise ValueError('O número de compilação deve estar entre 1 e 65535 para todos os instaladores.')
    return {'version': tag[1:], 'build_number': build_number}


def write_linux_version(bundle, version=None, build_number=None):
    manifest = Path('pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$', manifest, re.MULTILINE)
    if match is None:
        raise ValueError('A versão do pubspec não foi encontrada.')
    metadata = release_metadata('v' + (version or match.group(1)), build_number or match.group(2) or '1')
    target = Path(bundle) / 'data' / 'flutter_assets' / 'version.json'
    information = json.loads(target.read_text(encoding='utf-8'))
    information.update(version=metadata['version'], build_number=metadata['build_number'])
    temporary = target.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(information), encoding='utf-8')
    temporary.replace(target)
    return metadata


def main():
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--linux-bundle':
            write_linux_version(sys.argv[2], os.environ.get('RELEASE_VERSION'), os.environ.get('RELEASE_BUILD_NUMBER'))
            return 0
        metadata = release_metadata(os.environ.get('RELEASE_TAG', ''), os.environ.get('RELEASE_BUILD_NUMBER', ''))
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    output = '\n'.join(f'{key}={value}' for key, value in metadata.items()) + '\n'
    destination = os.environ.get('GITHUB_OUTPUT')
    if destination:
        with open(destination, 'a', encoding='utf-8') as stream:
            stream.write(output)
    else:
        print(output, end='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
