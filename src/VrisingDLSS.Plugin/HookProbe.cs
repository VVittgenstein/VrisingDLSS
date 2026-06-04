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
                log.LogWarning($"Hook target type not found: {target.TypeName}");
                continue;
            }

            log.LogInfo($"Hook target type found: {type.FullName} in {type.Assembly.GetName().Name}");
            foreach (var memberName in target.MemberNames)
            {
                var methods = HookTargetCatalog.FindMethods(type, memberName);
                if (methods.Count == 0)
                {
                    log.LogWarning($"Hook target member not found: {target.TypeName}.{memberName}");
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
