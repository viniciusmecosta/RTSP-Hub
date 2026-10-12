import 'dart:io';

class LinuxStartupService {
  LinuxStartupService({this.configHome, this.executable});

  final String? configHome;
  final String? executable;

  Future<bool> isEnabled() async {
    if (!Platform.isLinux) return false;
    final file = _entryFile();
    return file != null && await file.exists();
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isLinux) return false;
    final file = _entryFile();
    if (file == null) return false;
    try {
      if (!enabled) {
        if (await file.exists()) await file.delete();
        return true;
      }
      final appExecutable = (executable ?? Platform.resolvedExecutable)
          .replaceAll('%', '%%')
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=RTSP View\n'
        'Comment=Monitoramento de câmeras RTSP\n'
        'Exec="$appExecutable"\n'
        'Terminal=false\n'
        'X-GNOME-Autostart-enabled=true\n',
        flush: true,
      );
      return true;
    } on Object {
      return false;
    }
  }

  File? _entryFile() {
    final environment = Platform.environment;
    final configHome = this.configHome ?? environment['XDG_CONFIG_HOME'];
    final home = environment['HOME'];
    final root = configHome != null && configHome.isNotEmpty
        ? configHome
        : home != null && home.isNotEmpty
        ? '$home/.config'
        : null;
    return root == null ? null : File('$root/autostart/rtsp-view.desktop');
  }
}
