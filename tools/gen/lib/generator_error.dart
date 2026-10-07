/// A source that the generator cannot convert without guessing.
class GeneratorError implements Exception {
  GeneratorError(this.message);

  final String message;

  @override
  String toString() => message;
}
