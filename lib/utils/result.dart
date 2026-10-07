/// The outcome of a fallible call; callers take it apart with a `switch`.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final Exception error;
}
