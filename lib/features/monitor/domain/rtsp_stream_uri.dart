class RtspStreamUri {
  static Uri build({
    required String host,
    required int port,
    required String path,
    required String username,
    String? password,
  }) {
    final separator = path.indexOf('?');
    final streamPath = separator < 0 ? path : path.substring(0, separator);
    final query = separator < 0 ? null : path.substring(separator + 1);
    final normalizedPath = streamPath.startsWith('/')
        ? streamPath
        : '/$streamPath';
    final normalizedUsername = username.trim();
    final userInfo = normalizedUsername.isEmpty
        ? null
        : password == null || password.isEmpty
        ? Uri.encodeComponent(normalizedUsername)
        : '${Uri.encodeComponent(normalizedUsername)}:${Uri.encodeComponent(password)}';
    return Uri(
      scheme: 'rtsp',
      userInfo: userInfo,
      host: host.trim(),
      port: port,
      path: normalizedPath,
      query: query?.isEmpty ?? true ? null : query,
    );
  }
}
