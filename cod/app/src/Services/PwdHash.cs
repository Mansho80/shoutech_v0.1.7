// ============================================================================
// FILE: Services/PwdHash.cs
// PROJECT: SHOUTECH ERP
// PURPOSE:
//     Enterprise password hashing and verification.
//
// SECURITY DESIGN:
//     - PBKDF2-HMAC-SHA512
//     - Unique cryptographic salt per password
//     - Constant-time comparison
//     - Versioned hash format
//     - Configurable work factor
//     - No plaintext password storage
//     - No reversible encryption
//
// IMPORTANT:
//     The application must NEVER store plaintext passwords.
// ============================================================================

using System;
using System.Globalization;
using System.Security.Cryptography;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Enterprise password hashing service.
    ///
    /// This class is intentionally stateless and thread-safe.
    /// </summary>
    public static class PwdHash
    {
        // --------------------------------------------------------------------
        // Current algorithm
        // --------------------------------------------------------------------

        private const string CurrentAlgorithm = "PBKDF2-SHA512";
        private const string CurrentVersion = "v1";

        // 64 bytes = 512 bits.
        private const int SaltSizeBytes = 64;
        private const int HashSizeBytes = 64;

        // PBKDF2 work factor.
        //
        // This value is deliberately centralized so it can be increased
        // in a future migration without changing the public API.
        private const int DefaultIterations = 600_000;

        // Maximum accepted work factor when reading a stored versioned hash.
        //
        // This prevents a corrupted/tampered database value from forcing the
        // application to perform an absurd amount of CPU work.
        private const int MaximumAcceptedIterations = 2_000_000;

        // --------------------------------------------------------------------
        // Public API
        // --------------------------------------------------------------------

        /// <summary>
        /// Creates a secure password hash and salt.
        ///
        /// The resulting values are intended to be stored separately in:
        ///
        ///     PasswordHash
        ///     PasswordSalt
        ///
        /// The returned hash is versioned so future algorithms can be
        /// introduced without breaking existing accounts.
        /// </summary>
        public static PasswordHashResult Create(
            string password,
            int iterations = DefaultIterations)
        {
            ValidatePassword(password);

            if (iterations < 100_000)
                throw new ArgumentOutOfRangeException(
                    nameof(iterations),
                    "Password hashing iterations are too low.");

            if (iterations > MaximumAcceptedIterations)
                throw new ArgumentOutOfRangeException(
                    nameof(iterations),
                    "Password hashing iterations exceed the allowed maximum.");

            var salt = RandomNumberGenerator.GetBytes(SaltSizeBytes);

            var derivedKey = Rfc2898DeriveBytes.Pbkdf2(
                password: password,
                salt: salt,
                iterations: iterations,
                hashAlgorithm: HashAlgorithmName.SHA512,
                outputLength: HashSizeBytes);

            var hashBase64 = Convert.ToBase64String(derivedKey);
            var saltBase64 = Convert.ToBase64String(salt);

            // Store algorithm/version/iterations with the hash.
            //
            // Example:
            //
            // v1$PBKDF2-SHA512$600000$<hash>
            //
            var versionedHash =
                string.Join(
                    "$",
                    CurrentVersion,
                    CurrentAlgorithm,
                    iterations.ToString(CultureInfo.InvariantCulture),
                    hashBase64);

            return new PasswordHashResult(
                Hash: versionedHash,
                Salt: saltBase64,
                Algorithm: CurrentAlgorithm,
                Version: CurrentVersion,
                Iterations: iterations);
        }

        /// <summary>
        /// Verifies a password against the stored hash and salt.
        ///
        /// This method never throws for an invalid credential value.
        /// It returns false instead.
        /// </summary>
        public static bool Verify(
            string password,
            string storedHash,
            string storedSalt)
        {
            if (string.IsNullOrEmpty(password))
                return false;

            if (string.IsNullOrWhiteSpace(storedHash))
                return false;

            if (string.IsNullOrWhiteSpace(storedSalt))
                return false;

            try
            {
                // Current enterprise versioned format.
                if (TryParseVersionedHash(
                        storedHash,
                        out var algorithm,
                        out var iterations,
                        out var expectedHash))
                {
                    if (!string.Equals(
                            algorithm,
                            CurrentAlgorithm,
                            StringComparison.Ordinal))
                    {
                        return false;
                    }

                    if (iterations < 100_000 ||
                        iterations > MaximumAcceptedIterations)
                    {
                        return false;
                    }

                    var salt = Convert.FromBase64String(storedSalt);

                    if (salt.Length < 16)
                        return false;

                    var actualHash = Rfc2898DeriveBytes.Pbkdf2(
                        password: password,
                        salt: salt,
                        iterations: iterations,
                        hashAlgorithm: HashAlgorithmName.SHA512,
                        outputLength: expectedHash.Length);

                    return CryptographicOperations.FixedTimeEquals(
                        actualHash,
                        expectedHash);
                }

                // ----------------------------------------------------------------
                // Legacy compatibility
                // ----------------------------------------------------------------
                //
                // IMPORTANT:
                // We intentionally keep this conservative.
                //
                // The old project did not provide PwdHash.cs, therefore we do
                // not assume the exact legacy algorithm.
                //
                // A legacy database must be migrated only after its actual
                // hash format is identified.
                //
                // We do NOT guess an algorithm here.
                // ----------------------------------------------------------------

                return VerifyKnownLegacyFormat(
                    password,
                    storedHash,
                    storedSalt);
            }
            catch (FormatException)
            {
                return false;
            }
            catch (CryptographicException)
            {
                return false;
            }
            catch (ArgumentException)
            {
                return false;
            }
        }

        /// <summary>
        /// Determines whether the stored password should be upgraded.
        ///
        /// Currently:
        ///     true  = legacy / obsolete / lower work factor
        ///     false = current secure format
        /// </summary>
        public static bool NeedsRehash(
            string storedHash,
            int desiredIterations = DefaultIterations)
        {
            if (string.IsNullOrWhiteSpace(storedHash))
                return true;

            if (!TryParseVersionedHash(
                    storedHash,
                    out var algorithm,
                    out var iterations,
                    out _))
            {
                // Unknown/legacy format.
                return true;
            }

            return !string.Equals(
                       algorithm,
                       CurrentAlgorithm,
                       StringComparison.Ordinal)
                   || iterations < desiredIterations;
        }

        /// <summary>
        /// Generates a new password hash after a successful login when the
        /// existing hash needs upgrading.
        /// </summary>
        public static PasswordHashResult Rehash(
            string password,
            int iterations = DefaultIterations)
        {
            return Create(password, iterations);
        }

        // --------------------------------------------------------------------
        // Validation
        // --------------------------------------------------------------------

        private static void ValidatePassword(string password)
        {
            ArgumentNullException.ThrowIfNull(password);

            if (password.Length == 0)
                throw new ArgumentException(
                    "Password cannot be empty.",
                    nameof(password));

            // Do not impose an unnecessarily small maximum.
            //
            // 1024 characters is more than enough for normal ERP accounts
            // while preventing pathological input sizes.
            if (password.Length > 1024)
                throw new ArgumentException(
                    "Password exceeds the maximum supported length.",
                    nameof(password));
        }

        // --------------------------------------------------------------------
        // Versioned hash parsing
        // --------------------------------------------------------------------

        private static bool TryParseVersionedHash(
            string storedHash,
            out string algorithm,
            out int iterations,
            out byte[] expectedHash)
        {
            algorithm = string.Empty;
            iterations = 0;
            expectedHash = Array.Empty<byte>();

            var parts = storedHash.Split('$');

            if (parts.Length != 4)
                return false;

            if (!string.Equals(
                    parts[0],
                    CurrentVersion,
                    StringComparison.Ordinal))
            {
                return false;
            }

            algorithm = parts[1];

            if (!int.TryParse(
                    parts[2],
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out iterations))
            {
                return false;
            }

            if (iterations < 100_000 ||
                iterations > MaximumAcceptedIterations)
            {
                return false;
            }

            try
            {
                expectedHash = Convert.FromBase64String(parts[3]);
            }
            catch (FormatException)
            {
                return false;
            }

            if (expectedHash.Length != HashSizeBytes)
                return false;

            return true;
        }

        // --------------------------------------------------------------------
        // Legacy handling
        // --------------------------------------------------------------------

        private static bool VerifyKnownLegacyFormat(
            string password,
            string storedHash,
            string storedSalt)
        {
            /*
             * SECURITY NOTE
             * -------------
             *
             * The existing AuthServ referenced PwdHash.Verify(), but the actual
             * implementation was not present in the supplied Services files.
             *
             * Therefore we deliberately DO NOT guess whether the old system
             * used:
             *
             *     SHA256
             *     SHA512
             *     PBKDF2
             *     BCrypt
             *     another custom format
             *
             * Guessing here could silently authenticate against an incorrect
             * representation.
             *
             * Once the existing database hash format is confirmed, this method
             * can be implemented as an explicit migration adapter.
             */

            _ = password;
            _ = storedHash;
            _ = storedSalt;

            return false;
        }
    }

    // =========================================================================
    // Result object
    // =========================================================================

    /// <summary>
    /// Complete password hash metadata.
    /// </summary>
    public sealed record PasswordHashResult(
        string Hash,
        string Salt,
        string Algorithm,
        string Version,
        int Iterations);
}