// cod/cor/Security.cs
using System;
using System.Threading.Tasks;

namespace ShouTech.Core.Security
{
    public interface ISecurityEngine
    {
        Task ValidatePermissionAsync(Guid userId, string permissionKey);
    }

    // تنفيذ بسيط مؤقت حتى يتم ربط محرك الأمان الحقيقي
    public class DummySecurityEngine : ISecurityEngine
    {
        public Task ValidatePermissionAsync(Guid userId, string permissionKey)
        {
            // حالياً يسمح بكل شيء
            return Task.CompletedTask;
        }
    }
}