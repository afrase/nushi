/// [name] as plain text for a line of its own: control and bidirectional
/// characters dropped (a name is anyone's text, and shouldn't reorder or
/// hide what's around it), line breaks and tabs as spaces.
String plainName(String name) => String.fromCharCodes([
  for (final r in name.trim().runes)
    if (r == 0x0A || r == 0x09 || r == 0x2028 || r == 0x2029)
      0x20
    else if (!(r < 0x20 ||
        (r >= 0x7F && r <= 0x9F) ||
        (r >= 0x200B && r <= 0x200F) ||
        (r >= 0x202A && r <= 0x202E) ||
        (r >= 0x2060 && r <= 0x2069) ||
        r == 0x061C ||
        r == 0xFEFF))
      r,
]);
