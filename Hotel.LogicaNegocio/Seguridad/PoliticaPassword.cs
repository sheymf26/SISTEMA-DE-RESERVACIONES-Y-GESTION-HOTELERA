using Hotel.LogicaNegocio.Errores;

namespace Hotel.LogicaNegocio.Seguridad;

//La BD solo recibe el hash, así que la política de contraseñas se valida aquí
public static class PoliticaPassword
{
    public const int Minimo = 8;
    public const int Maximo = 128;

    public static void Validar(string password)
    {
        if (password.Length < Minimo || password.Length > Maximo
            || !password.Any(char.IsLetter) || !password.Any(char.IsDigit))
            throw new ExcepcionNegocio(TipoError.Validacion,
                $"La contraseña debe tener entre {Minimo} y {Maximo} caracteres e incluir al menos una letra y un número.");
    }
}
