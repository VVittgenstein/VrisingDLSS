using BepInEx.Logging;
using System;

namespace VrisingDLSS.Plugin;

internal static class HookProbe
{
    internal static void Run(ManualLogSource log)
    {
        log.LogInfo("Running read-only HDRP hook probe.");

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        log.LogInfo($"Loaded assembly count: {assemblies.Length}");

        foreach (var target in HookTargetCatalog.Targets)
        {
            var type = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (type is null)
            {
                var message = $"Hook target type not found: {target.TypeName}";
                if (target.Optional)
                {
                    log.LogInfo($"{message} (optional)");
                }
                else
                {
                    log.LogWarning(message);
                }

                continue;
            }

            log.LogInfo($"Hook target type found: {type.FullName} in {type.Assembly.GetName().Name}");
            foreach (var memberName in target.MemberNames)
            {
                var methods = HookTargetCatalog.FindMethods(type, memberName);
                if (methods.Count == 0)
                {
                    var message = $"Hook target member not found: {target.TypeName}.{memberName}";
                    if (target.Optional)
                    {
                        log.LogInfo($"{message} (optional)");
                    }
                    else
                    {
                        log.LogWarning(message);
                    }

                    continue;
                }

                foreach (var method in methods)
                {
                    log.LogInfo($"Candidate method: {HookTargetCatalog.FormatMethod(method)}");
                }
            }
        }
    }
}
