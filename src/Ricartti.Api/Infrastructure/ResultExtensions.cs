using Microsoft.AspNetCore.Mvc;
using Ricartti.Application.Common;

namespace Ricartti.Api.Infrastructure;

/// <summary>Traduce los errores esperados de la capa de aplicación a HTTP.</summary>
public static class ResultExtensions
{
    public static IActionResult ToActionResult<T>(this Result<T> result, ControllerBase controller) =>
        result.IsSuccess ? controller.Ok(result.Value) : result.Error!.ToActionResult(controller);

    public static IActionResult ToActionResult(this Error error, ControllerBase controller) => error.Kind switch
    {
        // Contrato del handoff: 422 { "errors": { "campo": "código" } }
        ErrorKind.Validation => controller.UnprocessableEntity(new { errors = error.FieldErrors }),
        ErrorKind.PayloadTooLarge => controller.StatusCode(StatusCodes.Status413PayloadTooLarge, new { errors = error.FieldErrors }),
        ErrorKind.NotFound => controller.NotFound(),
        ErrorKind.Conflict => controller.Conflict(),
        ErrorKind.Unauthorized => controller.Unauthorized(),
        _ => controller.StatusCode(StatusCodes.Status500InternalServerError),
    };
}
