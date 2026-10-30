namespace Ricartti.Application.Common;

public enum ErrorKind
{
    NotFound,
    Validation,
    Conflict,
    Unauthorized,
    PayloadTooLarge,
}

/// <summary>
/// Error esperado de un caso de uso. Para validación, FieldErrors sigue el
/// contrato del handoff: { campo: código } (required, email, invalid…).
/// </summary>
public sealed record Error(ErrorKind Kind, IReadOnlyDictionary<string, string>? FieldErrors = null)
{
    public static Error NotFound() => new(ErrorKind.NotFound);
    public static Error Validation(string field, string code) =>
        new(ErrorKind.Validation, new Dictionary<string, string> { [field] = code });
    public static Error Validation(IReadOnlyDictionary<string, string> fieldErrors) =>
        new(ErrorKind.Validation, fieldErrors);
    public static Error Unauthorized() => new(ErrorKind.Unauthorized);
    public static Error Conflict() => new(ErrorKind.Conflict);
    public static Error PayloadTooLarge(string field, string code) =>
        new(ErrorKind.PayloadTooLarge, new Dictionary<string, string> { [field] = code });
}

/// <summary>Resultado de un caso de uso: un valor o un error esperado (sin excepciones).</summary>
public sealed class Result<T>
{
    private Result(T? value, Error? error)
    {
        Value = value;
        Error = error;
    }

    public T? Value { get; }
    public Error? Error { get; }
    public bool IsSuccess => Error is null;

    public static Result<T> Success(T value) => new(value, null);
    public static Result<T> Failure(Error error) => new(default, error);

    public static implicit operator Result<T>(T value) => Success(value);
    public static implicit operator Result<T>(Error error) => Failure(error);
}
