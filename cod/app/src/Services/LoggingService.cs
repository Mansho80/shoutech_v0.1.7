using System;
using System.IO;

namespace ShouTech.App.Services
{
    public sealed class LoggingService : ILoggingService
    {
        private readonly string _logFolder;
        private readonly object _lock = new();

        public LoggingService()
        {
            _logFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShouTech", "ERP", "logs");

            if (!Directory.Exists(_logFolder))
                Directory.CreateDirectory(_logFolder);
        }

        public void LogInfo(string category, string message) => Write("INFO", category, message);

        public void LogWarning(string category, string message) => Write("WARN", category, message);

        public void LogError(string category, string message, Exception? ex = null)
        {
            var detail = ex == null ? message : $"{message} | {ex.Message}";
            Write("ERROR", category, detail);
        }

        private void Write(string level, string category, string message)
        {
            try
            {
                var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [{level}] [{category}] {message}";
                var path = Path.Combine(_logFolder, $"app_{DateTime.Now:yyyyMMdd}.log");

                lock (_lock)
                {
                    File.AppendAllText(path, line + Environment.NewLine);
                }
            }
            catch
            {
                // Logging must never crash the application
            }
        }
    }
}
