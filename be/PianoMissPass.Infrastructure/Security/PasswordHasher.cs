using System.Security.Cryptography;
using PianoMissPass.Application.Abstractions;

namespace PianoMissPass.Infrastructure.Security;

public class PasswordHasher : IPasswordHasher
{
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 100_000;

    public string Hash(string input)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var key = Rfc2898DeriveBytes.Pbkdf2(input, salt, Iterations, HashAlgorithmName.SHA256, KeySize);
        return $"v1.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(key)}";
    }

    public bool Verify(string input, string storedHash)
    {
        var parts = storedHash.Split('.');
        if (parts.Length != 3 || parts[0] != "v1")
        {
            return false;
        }

        var salt = Convert.FromBase64String(parts[1]);
        var expected = Convert.FromBase64String(parts[2]);
        var actual = Rfc2898DeriveBytes.Pbkdf2(input, salt, Iterations, HashAlgorithmName.SHA256, KeySize);

        return CryptographicOperations.FixedTimeEquals(expected, actual);
    }
}

