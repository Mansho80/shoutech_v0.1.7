using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ShouTech.App.Services
{
    public sealed class DataServ : IDataServ
    {
        public Task<int> GetTotalCustomersAsync() => Task.FromResult(1284);

        public Task<int> GetTotalProductsAsync() => Task.FromResult(3567);

        public Task<int> GetTotalPendingApprovalsAsync() => Task.FromResult(12);

        public Task<List<RecentDocument>> GetRecentDocumentsAsync(int count)
        {
            var docs = new List<RecentDocument>
            {
                new() { DocumentNumber = "INV-2026-00142", DocumentType = "فاتورة مبيعات", CustomerName = "شركة النور", TotalAmount = 15420.50m, Status = "معتمد", Date = DateTime.Now.AddHours(-2) },
                new() { DocumentNumber = "PO-2026-00089", DocumentType = "طلب شراء", CustomerName = "مورد الخليج", TotalAmount = 8750.00m, Status = "معلق", Date = DateTime.Now.AddHours(-5) },
                new() { DocumentNumber = "JV-2026-00301", DocumentType = "سند قيد", CustomerName = "-", TotalAmount = 3200.00m, Status = "مرحّل", Date = DateTime.Now.AddDays(-1) },
                new() { DocumentNumber = "SO-2026-00256", DocumentType = "طلبية بيع", CustomerName = "متجر الأمل", TotalAmount = 4890.75m, Status = "قيد التنفيذ", Date = DateTime.Now.AddDays(-1) },
                new() { DocumentNumber = "RC-2026-00017", DocumentType = "سند قبض", CustomerName = "عميل نقدي", TotalAmount = 1200.00m, Status = "مكتمل", Date = DateTime.Now.AddDays(-2) }
            };

            return Task.FromResult(docs.GetRange(0, Math.Min(count, docs.Count)));
        }
    }
}
