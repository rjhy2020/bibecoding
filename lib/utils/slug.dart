String slugify(String input) {
  var s = input.toLowerCase().trim();
  // Replace non-alphanumeric with dashes
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  // Collapse multiple dashes
  s = s.replaceAll(RegExp(r'-{2,}'), '-');
  // Trim leading/trailing dashes
  s = s.replaceAll(RegExp(r'^-+'), '');
  s = s.replaceAll(RegExp(r'-+$'), '');
  if (s.isEmpty) return 'pattern';
  return s;
}

