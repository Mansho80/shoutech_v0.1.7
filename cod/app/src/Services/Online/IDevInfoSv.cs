using System.Threading.Tasks;

namespace ShouTech.App.Services.Online
{
    public sealed class DeviceInfoSnapshot
    {
        public string DeviceId { get; set; } = string.Empty;
        public string HardwareId { get; set; } = string.Empty;
        public string MachineName { get; set; } = string.Empty;
        public string OsVersion { get; set; } = string.Empty;
        public string UserName { get; set; } = string.Empty;
        public string AppVersion { get; set; } = string.Empty;
        public string InstanceId { get; set; } = string.Empty;
        public int ProcessorCount { get; set; }
        public long WorkingSetMb { get; set; }
        public string Culture { get; set; } = string.Empty;
    }

    public interface IDevInfoSv
    {
        DeviceInfoSnapshot Current { get; }
        DeviceInfoSnapshot Collect();
        Task RegisterWithServerAsync();
    }

    public interface IDevInfoSvoSv : IDevInfoSv
    {
    }
}
