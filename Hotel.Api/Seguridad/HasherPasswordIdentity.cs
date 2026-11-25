using Hotel.LogicaNegocio.Seguridad;
using Microsoft.AspNetCore.Identity;

namespace Hotel.Api.Seguridad;

//PBKDF2 (HMAC-SHA512, 100 000 iteraciones, sal aleatoria) del PasswordHasher de ASP.NET Identity.
//Produce el formato "AQAAAA..." que acepta CK_Usuario_Hash
public sealed class HasherPasswordIdentity : IHasherPassword
{
    private static readonly PasswordHasher<object> Hasher = new();
    private static readonly object SinUsuario = new(); // el hasher no usa el usuario, pero la firma lo pide

    public string Hashear(string password) => Hasher.HashPassword(SinUsuario, password);

    public bool Verificar(string passwordHash, string password)
    {
        try
        {
            return Hasher.VerifyHashedPassword(SinUsuario, passwordHash, password) != PasswordVerificationResult.Failed;
        }
        catch (FormatException)
        {
            return false; // hash con otro formato (por ejemplo BCrypt cargado a mano)
        }
    }
}
