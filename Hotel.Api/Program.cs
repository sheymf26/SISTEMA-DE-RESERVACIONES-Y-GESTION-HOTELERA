using Hotel.AccesoDatos;
using Hotel.Api.Errores;
using Hotel.Api.Seguridad;
using Hotel.LogicaNegocio;

var builder = WebApplication.CreateBuilder(args);

//Cadena de conexión con la db bro, esta en desarrollo y preferiblemente vive en user secrets (no en git :v) cada uno debe configurar las suya
var cadenaConexion = builder.Configuration.GetConnectionString("HotelDB");
if (string.IsNullOrWhiteSpace(cadenaConexion))
    throw new InvalidOperationException(
        "Falta ConnectionStrings:HotelDB. Configúrela con: " +
        "dotnet user-secrets set \"ConnectionStrings:HotelDB\" \"Server=...;Database=HotelDB;Trusted_Connection=True;TrustServerCertificate=True\" --project Hotel.Api");

//Capas: acceso a datos, lógica de negocio y seguridad (JWT, permisos, usuario actual)
builder.Services.AddAccesoDatos(cadenaConexion);
builder.Services.AddLogicaNegocio();
builder.Services.AddSeguridad(builder.Configuration);

//Errores: todo sale como ProblemDetails; los THROW de la BD y las ExcepcionNegocio se traducen a 4xx
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ManejadorErroresNegocio>();
builder.Services.AddExceptionHandler<ManejadorErroresSql>();

//CORS: el front se sirve aparte (VS Code: Live Server / Vite) y AllowCredentials para la cookie del refresh token
const string PoliticaFront = "Front";
var origenes = builder.Configuration.GetSection("Cors:Origenes").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddPolicy(PoliticaFront, p => p
    .WithOrigins(origenes)
    .AllowAnyHeader()
    .AllowAnyMethod()
    .AllowCredentials()));

builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().AllowAnonymous();
}

app.UseHttpsRedirection();
app.UseCors(PoliticaFront);
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
