Object? withoutCredentials(Object? value, [String key = '']) {
  if (key == 'username' || key == 'defaultUser') return '';
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key, withoutCredentials(value, '$key')),
    );
  }
  if (value is List) {
    return value.map((item) => withoutCredentials(item)).toList();
  }
  if (value is String) {
    return value.replaceAllMapped(
      RegExp(
        r'([?&;](?:user(?:name)?|pass(?:word)?|pwd|token|auth(?:orization)?|key|api[_-]?key)=)[^&;]*',
        caseSensitive: false,
      ),
      (match) => match[1]!,
    );
  }
  return value;
}
