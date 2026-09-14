using System;

namespace ShouTech.Domain
{
    /// <summary>
    /// تمثيل بيانات تفضيلات المستخدم (تستخدم في التشفير والحفظ المحلي)
    /// </summary>
    public class Pref
    {
        // اللغة المختارة (ar, en, tr, fr) — الافتراضي الإنجليزية
        public string Lang { get; set; } = "en";

        // هل هذا هو التشغيل الأول للبرنامج؟
        public bool IsFirst { get; set; } = true;

        // كود آخر شركة تم تسجيل الدخول إليها (لتسريع الدخول القادم)
        public string LastCo { get; set; } = "";

        // التاريخ والوقت لآخر عملية تحديث للإعدادات
        public DateTime Updated { get; set; } = DateTime.Now;
    }
}