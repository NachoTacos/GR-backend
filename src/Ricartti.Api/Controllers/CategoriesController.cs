using Microsoft.AspNetCore.Mvc;
using Ricartti.Application.Portfolio;

namespace Ricartti.Api.Controllers;

[ApiController]
[Route("api/categories")]
public sealed class CategoriesController(GalleryService gallery) : ControllerBase
{
    /// <summary>Categorías activas con el número de proyectos visibles (handoff §9).</summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct) =>
        Ok(await gallery.ListCategoriesAsync(ct));
}
