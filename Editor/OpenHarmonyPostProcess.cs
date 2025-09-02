#if UNITY_OPENHARMONY
using System;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.OpenHarmony;
using UnityEngine;

public class OpenHarmonyPostProcess : IPostGenerateOpenHarmonyProject
{
    public int callbackOrder => 100;
    private const string SoFileName = "libgilzoide-sqlite-net.so";
    private const string PackageName = "com.gilzoide.sqlite-net";
    private const string AssemblyName = "com.gilzoide.sqlite-net.Editor.asmdef";
    public void OnPostGenerateOpenHarmonyProject(string path)
    {
        NativePluginProcess(path);
    }

    private void NativePluginProcess(string path)
    {
        Debug.Log("NativePluginProcess start");
        //找到libs目录
        var targetLibsDir = Path.Combine(path, "libs","arm64-v8a");
        if (!Directory.Exists(targetLibsDir))
        {
            throw new DirectoryNotFoundException("libs directory not found");
        }

        //找到源so文件
        var packageRoot = GetPackageDirectory(PackageName,AssemblyName);
        var srcSoFilePath = Path.Combine(packageRoot, "Plugins", "lib", "OpenHarmony", "arm64", SoFileName);
        if (!File.Exists(srcSoFilePath))
        {
            throw new FileNotFoundException($"libgilzoide-sqlite-net.so not found,in {srcSoFilePath}");
        }

        //复制so文件到libs目录
        var tartgetSoFilePath = Path.Combine(targetLibsDir, SoFileName);
        FileUtil.CopyFileOrDirectory(srcSoFilePath, tartgetSoFilePath);
        Debug.Log("NativePluginProcess finished");
    }
    public static string GetPackageDirectory(string packageName, string assemblyName)
    {
        // 1. PackageCache
        string packageCachePath =
            Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Library", "PackageCache"));
        string[] packageDirs =
            Directory.GetDirectories(packageCachePath, $"{packageName}*", SearchOption.TopDirectoryOnly);
        if (packageDirs.Length > 0)
        {
            if (packageDirs.Length > 1)
                Debug.Log($"[PackagePathUtil] 在 {packageCachePath} 找到多个 {packageName}，使用第一个：{packageDirs[0]}");
            return packageDirs[0];
        }

        // 2. Packages 目录下查找包含指定程序集的文件夹
        string packagesPath = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Packages"));
        foreach (var dir in Directory.GetDirectories(packagesPath))
        {
            string assemblyPath = Path.Combine(dir, assemblyName);
            if (File.Exists(assemblyPath))
            {
                return dir;
            }
        }

        // 3. manifest.json
        string manifestPath = Path.Combine(packagesPath, "manifest.json");
        if (File.Exists(manifestPath))
        {
            try
            {
                string json = File.ReadAllText(manifestPath);
                JObject jObject = JObject.Parse(json);
                var dependencies = jObject["dependencies"];
                if (dependencies != null && dependencies[packageName] != null)
                {
                    string filePath = dependencies[packageName].ToString().Replace("file:", "");
                    string fullPath = Path.GetFullPath(Path.Combine(packagesPath, filePath));
                    if (Directory.Exists(fullPath))
                        return fullPath;
                    else
                        throw new Exception($"manifest.json 里声明的 {packageName} 路径不存在: {fullPath}");
                }
                else
                {
                    throw new Exception($"manifest.json 中未找到 {packageName} 依赖项");
                }
            }
            catch (Exception e)
            {
                Debug.LogException(e);
                throw new BuildFailedException("解析 manifest.json 失败，构建中止");
            }
        }

        throw new BuildFailedException($"未能找到包 {packageName} 或程序集 {assemblyName} 的目录");
    }
}
#endif
