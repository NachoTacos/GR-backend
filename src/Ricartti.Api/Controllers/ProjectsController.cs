using Microsoft.AspNetCore.Mvc;
using Ricartti.Api.Infrastructure;
using Ricartti.Application.Portfolio;

namespace Ricartti.Api.Controllers;

[ApiController]
[Route("api/projects")]
public sealed class ProjectsController(GalleryService gallery) : ControllerBase
{
    /// <summary>Proyectos visibles, filtrados en el servidor por ?category=&lt;slug&gt;.</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? category, CancellationToken ct) =>
        (await gallery.ListProjectsAsync(category, ct)).ToActionResult(this);

    /// <summary>Detalle de un proyecto visible; 404 si no existe o está oculto.</summary>
    [HttpGet("{slug}")]
    public async Task<IActionResult> Get(string slug, CancellationToken ct) =>
        (await gallery.GetProjectAsync(slug, ct)).ToActionResult(this);
}
