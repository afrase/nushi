/// FNV-1a, 32 bits, over [units]: a string's code units or its UTF-8,
/// whichever its caller always used. Its values are kept (a review
/// comment's text it was written on, a finding's id) and meant to stay
/// the same across launches and releases (a person's color), so it is
/// frozen: a change would lose them.
int fnv1a(Iterable<int> units) {
  var h = 0x811c9dc5;
  for (final u in units) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h;
}
