namespace Ricartti.Application.Common;

/// <summary>
/// Detecta el tipo real de una imagen por su firma binaria. No se confía en el
/// nombre ni en el Content-Type del cliente. Solo JPEG, PNG y WebP: SVG queda
/// fuera a propósito, porque puede contener scripts.
/// </summary>
public static class ImageSignature
{
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    /// <summary>Devuelve ".jpg", ".png" o ".webp", o null si no es una imagen permitida. Deja el flujo en la posición 0.</summary>
    public static async Task<string?> DetectExtensionAsync(Stream content, CancellationToken ct)
    {
        var header = new byte[12];
        var read = 0;
        while (read < header.Length)
        {
            var n = await content.ReadAsync(header.AsMemory(read), ct);
            if (n == 0) break;
            read += n;
        }

        if (!content.CanSeek)
        {
            throw new InvalidOperationException("El flujo de la imagen debe poder reposicionarse.");
        }
        content.Position = 0;

        if (read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
        {
            return ".jpg";
        }
        if (read >= 8 && header.AsSpan(0, 8).SequenceEqual(Png))
        {
            return ".png";
        }
        // WebP: "RIFF" + tamaño (4 bytes) + "WEBP"
        if (read >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8))
        {
            return ".webp";
        }
        return null;
    }
}
