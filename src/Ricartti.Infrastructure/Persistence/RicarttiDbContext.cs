using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Ricartti.Domain.Leads;
using Ricartti.Domain.Portfolio;

namespace Ricartti.Infrastructure.Persistence;

/// <summary>
/// Mapea el esquema SQL existente (database/sql/01_schema.sql). No se usan
/// migraciones: la BD es la fuente de verdad y este contexto solo la refleja.
/// </summary>
public sealed class RicarttiDbContext(DbContextOptions<RicarttiDbContext> options) : DbContext(options)
{
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<SupportArea> SupportAreas => Set<SupportArea>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<ProjectImage> ProjectImages => Set<ProjectImage>();
    public DbSet<ProjectResult> ProjectResults => Set<ProjectResult>();
    public DbSet<ClientLead> ClientLeads => Set<ClientLead>();
    public DbSet<TalentApplication> TalentApplications => Set<TalentApplication>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<ClientLead>().ToTable("client_leads");
        model.Entity<TalentApplication>().ToTable("talent_applications");

        model.Entity<Category>(e =>
        {
            e.ToTable("categories");
        });

        model.Entity<SupportArea>(e =>
        {
            e.ToTable("support_areas");
            e.HasKey(a => a.Code);
        });

        model.Entity<Project>(e =>
        {
            e.ToTable("projects");
            e.Property(p => p.Stage).HasConversion(StageConverter);
            e.HasOne(p => p.Category).WithMany(c => c.Projects).HasForeignKey(p => p.CategoryId);
            e.HasMany(p => p.SupportAreas).WithMany(a => a.Projects).UsingEntity<Dictionary<string, object>>(
                "project_support_areas",
                right => right.HasOne<SupportArea>().WithMany().HasForeignKey("area_code"),
                left => left.HasOne<Project>().WithMany().HasForeignKey("project_id"),
                join => join.HasKey("project_id", "area_code"));
        });

        model.Entity<ProjectImage>(e =>
        {
            e.ToTable("project_images");
            e.HasOne(i => i.Project).WithMany(p => p.Images).HasForeignKey(i => i.ProjectId);
        });

        model.Entity<ProjectResult>(e =>
        {
            e.ToTable("project_results");
            e.HasOne(r => r.Project).WithMany(p => p.Results).HasForeignKey(r => r.ProjectId);
        });

        ApplySnakeCaseColumns(model);

        // Concurrencia optimista con la columna de sistema xmin de PostgreSQL.
        model.Entity<Project>().Property(p => p.Version).IsRowVersion().HasColumnName("xmin");

        // Los valores por defecto y updated_at los gestiona la BD (DEFAULT now() y trigger).
        foreach (var entity in model.Model.GetEntityTypes())
        {
            foreach (var name in new[] { "CreatedAt", "UpdatedAt" })
            {
                if (entity.FindProperty(name) is { } property)
                {
                    property.ValueGenerated = Microsoft.EntityFrameworkCore.Metadata.ValueGenerated.OnAdd;
                    property.SetDefaultValueSql("now()");
                }
            }
        }
    }

    private static readonly ValueConverter<ProjectStage, string> StageConverter = new(
        stage => stage.ToString().ToLowerInvariant(),
        value => Enum.Parse<ProjectStage>(value, ignoreCase: true));

    /// <summary>CoverImagePath → cover_image_path, para todas las columnas mapeadas.</summary>
    private static void ApplySnakeCaseColumns(ModelBuilder model)
    {
        foreach (var entity in model.Model.GetEntityTypes())
        {
            foreach (var property in entity.GetProperties())
            {
                property.SetColumnName(ToSnakeCase(property.Name));
            }
        }
    }

    private static string ToSnakeCase(string name)
    {
        if (name.Contains('_'))
        {
            return name; // Claves de la tabla de unión, ya en snake_case.
        }

        var sb = new StringBuilder(name.Length + 8);
        for (var i = 0; i < name.Length; i++)
        {
            var c = name[i];
            if (char.IsUpper(c) && i > 0)
            {
                sb.Append('_');
            }
            sb.Append(char.ToLowerInvariant(c));
        }
        return sb.ToString();
    }
}
