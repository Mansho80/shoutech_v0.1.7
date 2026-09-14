namespace ShouTech.App.Common
{
    internal static class PwdHash
    {
        public static (string Hash, string Salt) Create(string password)
        {
            var result = ShouTech.App.Services.PwdHash.Create(password);
            return (result.Hash, result.Salt);
        }

        public static bool Verify(string password, string hash, string salt)
            => ShouTech.App.Services.PwdHash.Verify(password, hash, salt);
    }
}
