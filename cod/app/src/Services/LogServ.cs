using System;
using System.IO;
using System.Text;
using System.Globalization;

namespace ShouTech.App.Services
{
    /// <summary>
    /// خدمة تسجيل بسيطة وآمنة
    /// تكتب محاولات الدخول في log/auth.log
    /// وتكتب الأخطاء في log/errors.log
    /// </summary>
    public class LogServ : ILogServ
    {
        private readonly string _authLogPath;
        private readonly string _errorsLogPath;
        private readonly object _lock = new();

        public LogServ()
        {
            // مجلد السجلات (يُنشأ تلقائياً إذا لم يكن موجوداً)
            var logDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "log");
            Directory.CreateDirectory(logDir);

            _authLogPath = Path.Combine(logDir, "auth.log");
            _errorsLogPath = Path.Combine(logDir, "errors.log");

            // كتابة رأس (Header) في الملفات عند أول تشغيل
            WriteHeader();
        }

        private void WriteHeader()
        {
            var header = $@"
═══════════════════════════════════════════════════════════════════════════════
ShouTech ERP - Audit & Error Log
Started at: {DateTime.Now:yyyy-MM-dd HH:mm:ss}
Machine: {Environment.MachineName}
═══════════════════════════════════════════════════════════════════════════════

";

            try
            {
                lock (_lock)
                {
                    if (!File.Exists(_authLogPath))
                        File.WriteAllText(_authLogPath, header, Encoding.UTF8);

                    if (!File.Exists(_errorsLogPath))
                        File.WriteAllText(_errorsLogPath, header, Encoding.UTF8);
                }
            }
            catch
            {
                // إذا فشل كتابة الرأس، نتجاهل الخطأ
            }
        }

        /// <summary>
        /// تسجيل رسالة معلومات (ملخص)
        /// </summary>
        public void LogInfo(string category, string message)
        {
            WriteLog(_errorsLogPath, $"INFO  | [{category}] {message}");
        }

        /// <summary>
        /// تسجيل رسالة تحذير (ملخص)
        /// </summary>
        public void LogWarning(string category, string message)
        {
            WriteLog(_errorsLogPath, $"WARN  | [{category}] {message}");
        }

        /// <summary>
        /// تسجيل خطأ مع تفاصيل الاستثناء إن وجد
        /// </summary>
        public void LogError(string category, string message, Exception? ex = null)
        {
            var fullMessage = $"[{category}] {message}";

            if (ex != null)
            {
                fullMessage += $@"

╔═══════════════════════════════════════════════════════════════
║ تفاصيل الاستثناء:
║   النوع: {ex.GetType().FullName}
║   الرسالة: {ex.Message}
║   المصدر: {ex.Source ?? "غير معروف"}
╚═══════════════════════════════════════════════════════════════
║ Stack Trace:
{ex.StackTrace}
╚═══════════════════════════════════════════════════════════════
";
            }

            WriteLog(_errorsLogPath, $"ERROR | {fullMessage}");
        }

        /// <summary>
        /// تسجيل محاولة دخول (نجاح أو فشل) - دالة مساعدة (ليست في الواجهة)
        /// يمكن استخدامها مباشرة من LogWin
        /// </summary>
        public void LogAuthAttempt(string username, bool success, string? reason = null)
        {
            var status = success ? "✅ نجاح" : "❌ فشل";
            var details = success 
                ? $"الدخول ناجح للمستخدم: {username}"
                : $"محاولة دخول فاشلة للمستخدم: {username} - السبب: {reason ?? "غير معروف"}";

            WriteLog(_authLogPath, $"AUTH | {status} | {details}");
        }

        /// <summary>
        /// كتابة سطر في الملف مع تنسيق الوقت
        /// </summary>
        private void WriteLog(string filePath, string content)
        {
            try
            {
                lock (_lock)
                {
                    var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture);
                    var logLine = $"[{timestamp}] {content}";

                    File.AppendAllText(filePath, logLine + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch
            {
                // ن ignore أي خطأ في الكتابة حتى لا يتوقف البرنامج
            }
        }
    }
}