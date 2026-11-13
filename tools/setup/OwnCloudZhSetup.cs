// ownCloud 7.1.1 简体中文安装程序（非官方）
//
// 本程序只做三件事：
//   1) 获取官方原版 ownCloud-7.1.1.19543.x64.msi（本机查找 / 官方服务器下载 / 手动选择），
//      并用 SHA-256 校验，校验不通过绝不执行；
//   2) 若未安装客户端则用 msiexec 静默安装官方原版；
//   3) 对已安装的 ownCloudGui.dll 做 20 字节等长补丁（使其从 C:\ProgramData\ocL10n 读取语言包），
//      并把 client_zh_CN.qm 写入该目录。
//
// 本文件是 GPLv2 项目 owncloud-desktop-zh-cn 的一部分，见仓库根目录 LICENSE。
// 修改记录：2026-11-13 创建（本项目首次发布）。

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace OwnCloudZhSetup
{
    internal static class Cfg
    {
        public const string ProductVersion = "7.1.1.19543";
        public const string MsiFileName = "ownCloud-7.1.1.19543.x64.msi";
        public const string MsiUrl = "https://attic.owncloud.com/desktop/ownCloud/stable/7.1.1.19543/win/ownCloud-7.1.1.19543.x64.msi";
        public const string MsiSha256 = "91520fe07de44348f5df258863c3b1d57686c451ee40341cd02504768e2b235a";
        public const long MsiSize = 39407616L;

        public const string GuiDllName = "ownCloudGui.dll";
        public const string GuiOfficialSha256 = "d52edfc045ed8ae429664e2f733cf93e667bbf301766422751a9a74121357931";
        public const string GuiPatchedSha256 = "9a3cdfa4c16fe2d7d53cd520dee0de974bdf12e4577b9932b4e734a9c1776492";

        public const int PatchOffset = 0x24B900;      // 2406656
        public const string PatchOld = ":/client/translations/";
        public const string PatchNew = "C:/ProgramData/ocL10n/";

        public const string QmResource = "client_zh_CN.qm";
        public const string QmSha256 = "acc30d22709c18475255f2c32987509e77a3a327e2bba8b67b1b99cc734a148d";

        public static string L10nDir
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "ocL10n"); }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (args != null && args.Length > 0)
            {
                if (args[0] == "--selftest") return SelfTest();
                if (args[0] == "--patch-only") return PatchOnly(args.Length > 1 ? args[1] : null);
                if (args[0] == "--extract-qm")
                {
                    string dir = args.Length > 1 ? args[1] : ".";
                    Directory.CreateDirectory(dir);
                    Installer.ExtractQm(Path.Combine(dir, Cfg.QmResource));
                    return 0;
                }
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupForm());
            return 0;
        }

        private static int SelfTest()
        {
            if (Cfg.PatchOld.Length != 22 || Cfg.PatchNew.Length != 22)
            {
                Console.Error.WriteLine("FAIL: patch strings must both be 22 chars");
                return 1;
            }
            if (Encoding.Unicode.GetBytes(Cfg.PatchOld).Length != 44)
            {
                Console.Error.WriteLine("FAIL: patch byte length");
                return 1;
            }
            byte[] qm = Installer.ReadResource(Cfg.QmResource);
            string h = Installer.Sha256(qm);
            if (h != Cfg.QmSha256)
            {
                Console.Error.WriteLine("FAIL: embedded qm sha256 = " + h);
                return 1;
            }
            Console.WriteLine("OK: embedded qm " + qm.Length + " bytes, sha256=" + h);
            return 0;
        }

        private static int PatchOnly(string installDir)
        {
            try
            {
                string dir = Installer.FindInstallDir(installDir);
                Installer.KillClient(null);
                Installer.PatchDll(Path.Combine(dir, Cfg.GuiDllName), Console.WriteLine);
                Installer.InstallQm(Console.WriteLine);
                Console.WriteLine("OK");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("FAIL: " + ex.Message);
                return 1;
            }
        }
    }

    // 与 UI 无关的安装逻辑，便于命令行复用/CI 测试
    internal static class Installer
    {
        public static string Sha256(byte[] data)
        {
            using (SHA256 sha = SHA256.Create())
            {
                return ToHex(sha.ComputeHash(data));
            }
        }

        public static string Sha256File(string path)
        {
            using (SHA256 sha = SHA256.Create())
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                return ToHex(sha.ComputeHash(fs));
            }
        }

        private static string ToHex(byte[] b)
        {
            StringBuilder sb = new StringBuilder(b.Length * 2);
            for (int i = 0; i < b.Length; i++) sb.Append(b[i].ToString("x2"));
            return sb.ToString();
        }

        public static byte[] ReadResource(string name)
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream s = asm.GetManifestResourceStream(name))
            {
                if (s == null) throw new Exception("程序内部资源缺失：" + name);
                using (MemoryStream ms = new MemoryStream())
                {
                    byte[] buf = new byte[81920];
                    int n;
                    while ((n = s.Read(buf, 0, buf.Length)) > 0) ms.Write(buf, 0, n);
                    return ms.ToArray();
                }
            }
        }

        public static void ExtractQm(string target)
        {
            byte[] qm = ReadResource(Cfg.QmResource);
            if (Sha256(qm) != Cfg.QmSha256) throw new Exception("内置语言包校验失败");
            string dir = Path.GetDirectoryName(target);
            if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
            File.WriteAllBytes(target, qm);
        }

        public static string FindInstallDir(string overrideDir)
        {
            if (!string.IsNullOrEmpty(overrideDir)) return overrideDir;
            string fallback = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "ownCloud");
            try
            {
                using (RegistryKey baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
                using (RegistryKey un = baseKey.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"))
                {
                    if (un != null)
                    {
                        string[] subs = un.GetSubKeyNames();
                        for (int i = 0; i < subs.Length; i++)
                        {
                            using (RegistryKey k = un.OpenSubKey(subs[i]))
                            {
                                if (k == null) continue;
                                object dn = k.GetValue("DisplayName");
                                if (dn == null || dn.ToString().IndexOf("ownCloud", StringComparison.OrdinalIgnoreCase) < 0) continue;
                                object loc = k.GetValue("InstallLocation");
                                if (loc == null) continue;
                                string s = loc.ToString().Trim().TrimEnd('\\');
                                if (s.Length > 0 && File.Exists(Path.Combine(s, "owncloud.exe"))) return s;
                            }
                        }
                    }
                }
            }
            catch { }
            return fallback;
        }

        public static void KillClient(Action<string> log)
        {
            int killed = 0;
            Process[] procs = Process.GetProcessesByName("owncloud");
            for (int i = 0; i < procs.Length; i++)
            {
                try { procs[i].Kill(); killed++; } catch { }
            }
            if (killed > 0)
            {
                if (log != null) log("已结束 " + killed + " 个正在运行的 ownCloud 进程。");
                Thread.Sleep(1500);
            }
        }

        public static void PatchDll(string dllPath, Action<string> log)
        {
            if (!File.Exists(dllPath)) throw new Exception("未找到 " + dllPath + "，请确认客户端已安装。");
            byte[] bytes = File.ReadAllBytes(dllPath);
            string cur = Sha256(bytes);
            if (cur == Cfg.GuiPatchedSha256)
            {
                if (log != null) log("ownCloudGui.dll 已经是中文版，跳过补丁。");
                return;
            }
            if (cur != Cfg.GuiOfficialSha256)
            {
                throw new Exception("ownCloudGui.dll 与 " + Cfg.ProductVersion + " 版本不匹配（SHA-256 "
                    + cur.Substring(0, 16) + "…），为安全起见已停止。请先安装对应的官方版本。");
            }
            byte[] oldBytes = Encoding.Unicode.GetBytes(Cfg.PatchOld);
            byte[] newBytes = Encoding.Unicode.GetBytes(Cfg.PatchNew);
            if (Cfg.PatchOffset + oldBytes.Length > bytes.Length) throw new Exception("文件长度异常。");
            for (int i = 0; i < oldBytes.Length; i++)
            {
                if (bytes[Cfg.PatchOffset + i] != oldBytes[i])
                    throw new Exception("补丁位置内容与预期不符，可能不是该版本，已停止。");
            }
            string backup = dllPath + ".orig";
            if (!File.Exists(backup))
            {
                File.Copy(dllPath, backup, true);
                if (log != null) log("已备份原始文件：" + backup);
            }
            else if (log != null) log("已存在备份：" + backup);
            Array.Copy(newBytes, 0, bytes, Cfg.PatchOffset, newBytes.Length);
            WriteAllBytesRetry(dllPath, bytes);
            string after = Sha256(File.ReadAllBytes(dllPath));
            if (after != Cfg.GuiPatchedSha256) throw new Exception("补丁写入后校验失败。");
            if (log != null) log("ownCloudGui.dll 补丁完成（仅修改 20 个字节）。");
        }

        private static void WriteAllBytesRetry(string path, byte[] bytes)
        {
            for (int attempt = 0; attempt < 10; attempt++)
            {
                try { File.WriteAllBytes(path, bytes); return; }
                catch (IOException) { Thread.Sleep(300); }
                catch (UnauthorizedAccessException) { Thread.Sleep(300); }
            }
            File.WriteAllBytes(path, bytes);
        }

        public static void InstallQm(Action<string> log)
        {
            byte[] qm = ReadResource(Cfg.QmResource);
            if (Sha256(qm) != Cfg.QmSha256) throw new Exception("内置语言包校验失败。");
            Directory.CreateDirectory(Cfg.L10nDir);
            string target = Path.Combine(Cfg.L10nDir, Cfg.QmResource);
            File.WriteAllBytes(target, qm);
            if (Sha256File(target) != Cfg.QmSha256) throw new Exception("语言包写入后校验失败。");
            if (log != null) log("语言包已安装：" + target);
        }

        public static int Run(string exe, string args)
        {
            ProcessStartInfo psi = new ProcessStartInfo(exe, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi))
            {
                p.WaitForExit();
                return p.ExitCode;
            }
        }

        public static void Download(string url, string dest, Action<string> log)
        {
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
            if (File.Exists(dest)) File.Delete(dest);
            using (WebClient wc = new WebClient())
            {
                wc.DownloadProgressChanged += delegate(object sender, DownloadProgressChangedEventArgs e)
                {
                    if (log != null)
                        log(string.Format("正在下载官方安装包… {0}%  ({1:F1} MB / {2:F1} MB)",
                            e.ProgressPercentage, e.BytesReceived / 1048576.0,
                            e.TotalBytesToReceive > 0 ? e.TotalBytesToReceive / 1048576.0 : 37.6));
                };
                wc.DownloadFileAsync(new Uri(url), dest);
                while (wc.IsBusy) Thread.Sleep(200);
            }
        }
    }

    internal sealed class SetupForm : Form
    {
        private const string ProductTitle = "ownCloud 7.1.1 简体中文安装程序";

        private readonly Label lblDetect;
        private readonly Label lblStatus;
        private readonly TextBox txtLog;
        private readonly ProgressBar bar;
        private readonly Button btnInstall;
        private readonly Button btnClose;

        private string installDir;
        private bool installed;

        public SetupForm()
        {
            installDir = Installer.FindInstallDir(null);
            installed = File.Exists(Path.Combine(installDir, "owncloud.exe"));
            SuspendLayout();
            Text = ProductTitle;
            ClientSize = new Size(660, 500);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Microsoft YaHei UI", 9F);

            Label lblTitle = new Label();
            lblTitle.Text = "ownCloud 桌面客户端  简体中文版";
            lblTitle.Font = new Font("Microsoft YaHei UI", 16F, FontStyle.Bold);
            lblTitle.AutoSize = true;
            lblTitle.Location = new Point(22, 18);
            Controls.Add(lblTitle);

            Label lblDesc = new Label();
            lblDesc.Text = "版本 " + Cfg.ProductVersion + "（64 位）  ·  非官方社区汉化\r\n"
                         + "安装程序会使用官方原版安装包（SHA-256 校验）并添加中文界面。";
            lblDesc.AutoSize = true;
            lblDesc.ForeColor = Color.DimGray;
            lblDesc.Location = new Point(24, 58);
            Controls.Add(lblDesc);

            lblDetect = new Label();
            lblDetect.AutoSize = true;
            lblDetect.Location = new Point(24, 102);
            lblDetect.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold);
            lblDetect.Text = installed
                ? "检测结果：已安装 ownCloud（" + installDir + "），将为其添加中文界面。"
                : "检测结果：未安装 ownCloud，将先安装官方原版，再添加中文界面。";
            Controls.Add(lblDetect);

            Label lblNotice = new Label();
            lblNotice.Text = "提示：安装过程中如客户端正在运行，程序会自动结束其进程。";
            lblNotice.AutoSize = true;
            lblNotice.ForeColor = Color.DimGray;
            lblNotice.Location = new Point(24, 126);
            Controls.Add(lblNotice);

            bar = new ProgressBar();
            bar.Location = new Point(26, 152);
            bar.Size = new Size(606, 16);
            bar.Style = ProgressBarStyle.Continuous;
            bar.Minimum = 0;
            bar.Maximum = 100;
            bar.Value = 0;
            Controls.Add(bar);

            lblStatus = new Label();
            lblStatus.Text = "就绪。点击“开始安装”继续。";
            lblStatus.AutoSize = true;
            lblStatus.Location = new Point(24, 174);
            Controls.Add(lblStatus);

            txtLog = new TextBox();
            txtLog.Location = new Point(26, 198);
            txtLog.Size = new Size(606, 220);
            txtLog.Multiline = true;
            txtLog.ReadOnly = true;
            txtLog.ScrollBars = ScrollBars.Vertical;
            txtLog.BackColor = Color.White;
            txtLog.Font = new Font("Consolas", 8.5F);
            Controls.Add(txtLog);

            btnInstall = new Button();
            btnInstall.Text = "开始安装";
            btnInstall.Size = new Size(120, 34);
            btnInstall.Location = new Point(398, 440);
            btnInstall.Click += new EventHandler(btnInstall_Click);
            Controls.Add(btnInstall);

            btnClose = new Button();
            btnClose.Text = "退出";
            btnClose.Size = new Size(92, 34);
            btnClose.Location = new Point(540, 440);
            btnClose.Click += delegate { Close(); };
            Controls.Add(btnClose);

            ResumeLayout(false);
        }

        private void btnInstall_Click(object sender, EventArgs e)
        {
            btnInstall.Enabled = false;
            btnClose.Enabled = false;
            bar.Style = ProgressBarStyle.Marquee;
            lblStatus.Text = "正在安装，请稍候…";
            Thread t = new Thread(InstallWorker);
            t.IsBackground = true;
            t.Start();
        }

        private void Log(string line)
        {
            if (InvokeRequired)
            {
                BeginInvoke(new Action<string>(Log), line);
                return;
            }
            txtLog.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + line + "\r\n");
        }

        private void SetStatus(string s)
        {
            if (InvokeRequired) { BeginInvoke(new Action<string>(SetStatus), s); return; }
            lblStatus.Text = s;
        }

        private void SetProgress(int v)
        {
            if (InvokeRequired) { BeginInvoke(new Action<int>(SetProgress), v); return; }
            bar.Style = ProgressBarStyle.Continuous;
            bar.Value = Math.Max(0, Math.Min(100, v));
        }

        private void Finish(bool ok, string message)
        {
            if (InvokeRequired) { BeginInvoke(new Action<bool, string>(Finish), ok, message); return; }
            bar.Style = ProgressBarStyle.Continuous;
            if (ok) bar.Value = 100;
            lblStatus.Text = message;
            btnClose.Text = ok ? "完成" : "关闭";
            btnClose.Enabled = true;
            btnInstall.Enabled = false;
        }

        private T InvokeFunc<T>(Func<T> f)
        {
            if (InvokeRequired) return (T)Invoke(f);
            return f();
        }

        private void InstallWorker()
        {
            try
            {
                Log("=== ownCloud 简体中文安装程序（非官方） ===");
                Log("安装目录：" + installDir);

                installed = File.Exists(Path.Combine(installDir, "owncloud.exe"));
                if (!installed)
                {
                    SetStatus("正在获取官方安装包…");
                    Log("未检测到已安装的客户端，需要先安装官方原版。");
                    string msi = AcquireMsi();
                    if (msi == null) { Finish(false, "已取消：没有获得经过校验的官方安装包。"); return; }
                    Log("使用安装包：" + msi);
                    SetProgress(30);

                    string msiLog = Path.Combine(Path.GetTempPath(), "ownCloud-install.log");
                    SetStatus("正在静默安装官方原版 ownCloud…");
                    int code = Installer.Run("msiexec.exe", "/i \"" + msi + "\" /qn /norestart /l*v \"" + msiLog + "\"");
                    Log("MSI 安装退出代码：" + code + "（日志：" + msiLog + "）");
                    if (code != 0 && code != 3010) throw new Exception("官方安装包执行失败（代码 " + code + "）。");
                    SetProgress(65);

                    installDir = Installer.FindInstallDir(null);
                    lblDetect.Text = "检测结果：已安装 ownCloud（" + installDir + "）。";
                    for (int i = 0; i < 20 && !File.Exists(Path.Combine(installDir, "owncloud.exe")); i++) Thread.Sleep(500);
                    if (!File.Exists(Path.Combine(installDir, "owncloud.exe"))) throw new Exception("安装完成后仍未找到 owncloud.exe。");
                    Log("安装完成：" + installDir);
                }
                else
                {
                    Log("检测到已安装的 ownCloud，跳过主程序安装。");
                    SetProgress(30);
                }

                SetStatus("正在结束客户端进程…");
                Installer.KillClient(Log);
                SetProgress(70);

                SetStatus("正在应用中文界面补丁…");
                Installer.PatchDll(Path.Combine(installDir, Cfg.GuiDllName), Log);
                SetProgress(90);

                SetStatus("正在安装简体中文语言包…");
                Installer.InstallQm(Log);
                SetProgress(100);

                Log("=== 安装完成 ===");
                Log("打开 ownCloud 后即为简体中文界面。");
                Log("还原英文：删除 C:\\ProgramData\\ocL10n，并把 ownCloudGui.dll.orig 复制回 ownCloudGui.dll。");
                Finish(true, "已完成：ownCloud 简体中文界面安装成功。");
            }
            catch (Exception ex)
            {
                Log("错误：" + ex.Message);
                Finish(false, "安装失败：" + ex.Message);
            }
        }

        /// <summary>获取官方 MSI：本机查找 → 官方下载 → 让用户选择；任何来源都必须通过 SHA-256 校验。</summary>
        private string AcquireMsi()
        {
            string[] candidates = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads", Cfg.MsiFileName),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Cfg.MsiFileName),
                Path.Combine(Environment.CurrentDirectory, Cfg.MsiFileName),
                Path.Combine(Path.GetTempPath(), Cfg.MsiFileName),
            };
            for (int i = 0; i < candidates.Length; i++)
            {
                if (!File.Exists(candidates[i])) continue;
                string h = Installer.Sha256File(candidates[i]);
                if (h == Cfg.MsiSha256)
                {
                    Log("已在本机找到官方安装包并通过校验：" + candidates[i]);
                    return candidates[i];
                }
                Log("忽略本机文件（SHA-256 不符）：" + candidates[i]);
            }

            string tmp = Path.Combine(Path.GetTempPath(), Cfg.MsiFileName);
            try
            {
                SetStatus("正在从官方服务器下载官方安装包…");
                Log("从官方地址下载：" + Cfg.MsiUrl);
                Installer.Download(Cfg.MsiUrl, tmp, Log);
                string h = Installer.Sha256File(tmp);
                if (h == Cfg.MsiSha256) return tmp;
                Log("下载文件校验失败（SHA-256 " + h.Substring(0, 16) + "…），将改用其它方式。");
            }
            catch (Exception ex)
            {
                Log("自动下载失败：" + ex.Message);
            }

            for (int attempt = 0; attempt < 3; attempt++)
            {
                string picked = InvokeFunc<string>(delegate
                {
                    using (OpenFileDialog d = new OpenFileDialog())
                    {
                        d.Title = "请选择官方 " + Cfg.MsiFileName + "（下载自 ownCloud 官方站点）";
                        d.Filter = "ownCloud 安装包 (*.msi)|*.msi|所有文件 (*.*)|*.*";
                        d.CheckFileExists = true;
                        if (d.ShowDialog() == DialogResult.OK) return d.FileName;
                        return null;
                    }
                });
                if (string.IsNullOrEmpty(picked)) return null;
                string h = Installer.Sha256File(picked);
                if (h == Cfg.MsiSha256) return picked;
                Log("所选文件不是官方 " + Cfg.ProductVersion + " 安装包（SHA-256 不符），请重新选择。");
            }
            return null;
        }
    }
}
