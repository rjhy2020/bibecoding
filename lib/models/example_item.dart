class ExampleItem {
  final String sentence;
  final String meaning;
  const ExampleItem({required this.sentence, required this.meaning});

  factory ExampleItem.fromMap(Map<String, dynamic> m) {
    return ExampleItem(
      sentence: (m['sentence'] ?? m.toString()).toString(),
      meaning: (m['meaning'] ?? '').toString(),
    );
  }
}

