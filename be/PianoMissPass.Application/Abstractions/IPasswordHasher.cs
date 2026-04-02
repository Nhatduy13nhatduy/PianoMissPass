namespace PianoMissPass.Application.Abstractions;

public interface IPasswordHasher
{
    string Hash(string input);
    bool Verify(string input, string storedHash);
}

