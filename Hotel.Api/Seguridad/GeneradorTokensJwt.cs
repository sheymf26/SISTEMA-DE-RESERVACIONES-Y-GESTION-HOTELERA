using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Hotel.Api.Seguridad;

public sealed class GeneradorTokensJwt(IOptions<OpcionesJwt> opciones) : IGeneradorTokens
{
    private readonly OpcionesJwt _jwt = opciones.Value;
    private readonly JsonWebTokenHandler _handler = new();
    private readonly SigningCredentials _credenciales = new(
        new SymmetricSecurityKey(Encoding.UTF8.GetBytes(opciones.Value.Clave)), SecurityAlgorithms.HmacSha256);

    //JWT corto (MinutosVigencia). Los permisos NO van dentro: se consultan en la BD para que un cambio aplique enseguida
    public TokenAcceso GenerarAcceso(UsuarioLogin usuario)
    {
        var expira = DateTime.UtcNow.AddMinutes(_jwt.MinutosVigencia);
        var token = _handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = _jwt.Emisor,
            Audience = _jwt.Audiencia,
            Expires = expira,
            SigningCredentials = _credenciales,
            Claims = new Dictionary<string, object>
            {
                [JwtRegisteredClaimNames.Sub] = usuario.IdUsuario.ToString(),
                [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString(),
                [JwtRegisteredClaimNames.Name] = usuario.NombreUsuario,
                [ClaimsHotel.Sello] = usuario.SecurityStamp.ToString(),
                [ClaimsHotel.Sistema] = usuario.AccesoSistema,
                [ClaimsHotel.App] = usuario.AccesoApp
            }
        });
        return new TokenAcceso(token, expira);
    }

    //256 bits aleatorios en Base64Url; la BD solo guarda el SHA-256
    public TokenRefresh GenerarRefresh()
    {
        var token = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
        return new TokenRefresh(token, HashRefresh(token));
    }

    public byte[] HashRefresh(string refreshToken) => SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken));
}
