# =====================================================================
# Imagen de la API (ASP.NET Core 10).
# Compila con el SDK dentro del contenedor: no hace falta instalar .NET
# en el equipo. La imagen final solo lleva el runtime y corre sin root.
# =====================================================================

# --- Compilación ------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Primero solo los .csproj: la restauración de paquetes queda en caché
# mientras no cambien las dependencias.
COPY Ricartti.sln ./
COPY src/Ricartti.Domain/Ricartti.Domain.csproj                 src/Ricartti.Domain/
COPY src/Ricartti.Application/Ricartti.Application.csproj       src/Ricartti.Application/
COPY src/Ricartti.Infrastructure/Ricartti.Infrastructure.csproj src/Ricartti.Infrastructure/
COPY src/Ricartti.Api/Ricartti.Api.csproj                       src/Ricartti.Api/
RUN dotnet restore src/Ricartti.Api/Ricartti.Api.csproj

COPY src/ src/
RUN dotnet publish src/Ricartti.Api/Ricartti.Api.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

# --- Ejecución --------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Carpetas de imágenes públicas y de archivos privados (CV), propiedad del
# usuario sin privilegios que trae la imagen ($APP_UID).
RUN mkdir -p /app/uploads /app/private && chown -R "$APP_UID" /app/uploads /app/private

COPY --from=build /app/publish .

USER $APP_UID
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Ricartti.Api.dll"]
