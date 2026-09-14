using System;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    /// <summary>
    /// تطبيق مبدئي لخدمة التدقيق (سيتم تطويره لاحقاً)
    /// </summary>
    public class AuditService : IAuditService
    {
        private readonly ILogServ _logger;

        public AuditService(ILogServ logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// تسجيل بداية تشغيل النظام
        /// </summary>
        public Task LogSystemStartAsync()
        {
            _logger.LogInfo("Audit", "🚀 بدء تشغيل النظام");
            return Task.CompletedTask;
        }

        /// <summary>
        /// تسجيل إيقاف تشغيل النظام (اختياري)
        /// </summary>
        public Task LogSystemStopAsync()
        {
            _logger.LogInfo("Audit", "🛑 إيقاف تشغيل النظام");
            return Task.CompletedTask;
        }
    }
}