import 'dart:io';

class LinuxStartupService {
  LinuxStartupService({this.configHome, this.executable});

  final String? configHome;
  final String? executable;

  Future<bool> isEnabled() async {
    if (!Platform.isLinux) return false;
    try {
      final file = _entryFile();
      final legacy = _legacyEntryFile();
      if (file != null && await file.exists()) {
        if (legacy != null && await legacy.exists()) await setEnabled(true);
        return true;
      }
      if (legacy == null || !await legacy.exists()) return false;
      return await setEnabled(true);
    } on Object {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isLinux) return false;
    final file = _entryFile();
    if (file == null) return false;
    final legacy = _legacyEntryFile();
    try {
      if (!enabled) {
        if (await file.exists()) await file.delete();
        if (legacy != null && await legacy.exists()) await legacy.delete();
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
        'Name=RTSP Hub\n'
        'Comment=Monitoramento de câmeras RTSP\n'
        'Icon=rtsp-hub\n'
        'StartupWMClass=com.rtsp.rtsp_view\n'
        'Exec="$appExecutable"\n'
        'Terminal=false\n'
        'X-GNOME-Autostart-enabled=true\n',
        flush: true,
      );
      if (legacy != null && await legacy.exists()) await legacy.delete();
      return true;
    } on Object {
      return false;
    }
  }

  File? _entryFile() {
    final root = _configRoot();
    return root == null ? null : File('$root/autostart/rtsp-hub.desktop');
  }

  File? _legacyEntryFile() {
    final root = _configRoot();
    return root == null ? null : File('$root/autostart/rtsp-view.desktop');
  }

  String? _configRoot() {
    final environment = Platform.environment;
    final configHome = this.configHome ?? environment['XDG_CONFIG_HOME'];
    final home = environment['HOME'];
    return configHome != null && configHome.isNotEmpty
        ? configHome
        : home != null && home.isNotEmpty
        ? '$home/.config'
        : null;
  }
}
