namespace Ricartti.Api.Configuration;

/// <summary>Localiza GR-backend y carga su .env (si existe) antes de crear el host.</summary>
public static class EnvFile
{
    /// <summary>
    /// Sube desde el directorio actual hasta encontrar .env o Ricartti.sln.
    /// Así funciona igual con "dotnet run --project src/Ricartti.Api" desde
    /// GR-backend que desde la carpeta del proyecto. En Docker no hay .env:
    /// las variables llegan del entorno y se usa el directorio actual.
    /// </summary>
    public static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, ".env")) ||
                File.Exists(Path.Combine(dir.FullName, "Ricartti.sln")))
            {
                return dir.FullName;
            }
            dir = dir.Parent;
        }
        return Directory.GetCurrentDirectory();
    }

    /// <summary>Carga .env sin sobrescribir variables ya definidas (las de Docker ganan).</summary>
    public static void Load(string repoRoot)
    {
        var path = Path.Combine(repoRoot, ".env");
        if (File.Exists(path))
        {
            DotNetEnv.Env.NoClobber().Load(path);
        }
    }
}
