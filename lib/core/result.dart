sealed class Result<T> {
  const Result();
  R when<R>({required R Function(T) ok, required R Function(AppError) err}) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    return err((self as Err<T>).error);
  }
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final AppError error;
  const Err(this.error);
}

class AppError {
  final String code;
  final String message;
  final Object? cause;
  const AppError(this.code, this.message, [this.cause]);

  @override
  String toString() => 'AppError($code): $message';
}

