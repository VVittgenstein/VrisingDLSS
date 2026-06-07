using BepInEx.Logging;
using System;
using System.Text.RegularExpressions;

namespace VrisingDLSS.Plugin;

internal static class HdrpEasuInputOutputCorrelationProbeState
{
    private const int MaxStatusLogs = 8;
    private const int MaxCorrelationFrameDelta = 5;

    private static readonly object Sync = new();
    private static HdrpInputSnapshot? LatestHdrpInput;
    private static EasuOutputSnapshot? LatestEasuOutput;
    private static bool Active;
    private static bool AdvancedLogged;
    private static int StatusLogCount;

    internal static void Reset(bool active = false)
    {
        lock (Sync)
        {
            LatestHdrpInput = null;
            LatestEasuOutput = null;
            Active = active;
            AdvancedLogged = false;
            StatusLogCount = 0;
        }
    }

    internal static bool ShouldRefreshEasuOutput()
    {
        lock (Sync)
        {
            return Active && !AdvancedLogged;
        }
    }

    internal static bool TryGetFrameDescriptor(out FrameDescriptorSnapshot descriptor)
    {
        lock (Sync)
        {
            descriptor = default;
            if (!Active || !LatestHdrpInput.HasValue || !LatestEasuOutput.HasValue)
            {
                return false;
            }

            var hdrp = LatestHdrpInput.Value;
            var easu = LatestEasuOutput.Value;
            if (hdrp.DepthPointer == IntPtr.Zero
                || hdrp.MotionPointer == IntPtr.Zero
                || easu.SourcePointer == IntPtr.Zero
                || easu.DestinationPointer == IntPtr.Zero
                || !TryBuildCorrelationFactsLocked(hdrp, easu, out var facts)
                || !facts.Ready)
            {
                return false;
            }

            descriptor = new FrameDescriptorSnapshot(
                easu.SourcePointer,
                easu.DestinationPointer,
                hdrp.DepthPointer,
                hdrp.MotionPointer,
                facts.InputWidth,
                facts.InputHeight,
                facts.OutputWidth,
                facts.OutputHeight,
                hdrp.FrameCount,
                easu.SourceFrameCount,
                easu.DestinationFrameCount,
                easu.TargetCompile,
                hdrp.MethodLabel,
                easu.TargetManagedPassData,
                easu.TupleSummary,
                hdrp.GlobalTextureSummary,
                easu.SourceObservation,
                easu.DestinationObservation);
            return true;
        }
    }

    internal static void RecordHdrpInput(ManualLogSource? log, HdrpInputSnapshot snapshot)
    {
        string? advanced;
        string? status;
        lock (Sync)
        {
            LatestHdrpInput = snapshot;
            advanced = TryBuildAdvancedMessageLocked();
            status = advanced is null ? TryBuildStatusMessageLocked("hdrp") : null;
        }

        LogMessages(log, advanced, status);
    }

    internal static void RecordEasuOutput(ManualLogSource? log, EasuOutputSnapshot snapshot)
    {
        string? advanced;
        string? status;
        lock (Sync)
        {
            LatestEasuOutput = snapshot;
            advanced = TryBuildAdvancedMessageLocked();
            status = advanced is null ? TryBuildStatusMessageLocked("easu") : null;
        }

        LogMessages(log, advanced, status);
    }

    private static string? TryBuildAdvancedMessageLocked()
    {
        if (AdvancedLogged || !LatestHdrpInput.HasValue || !LatestEasuOutput.HasValue)
        {
            return null;
        }

        var hdrp = LatestHdrpInput.Value;
        var easu = LatestEasuOutput.Value;
        if (!TryBuildCorrelationFactsLocked(hdrp, easu, out var facts) || !facts.Ready)
        {
            return null;
        }

        AdvancedLogged = true;
        return "HDRP/EASU input-output correlation advanced: " +
            $"hdrpFrame={hdrp.FrameCount}; " +
            $"easuSourceFrame={easu.SourceFrameCount}; " +
            $"easuDestinationFrame={easu.DestinationFrameCount}; " +
            $"sourceFrameDelta={facts.SourceFrameDeltaText}; " +
            $"destinationFrameDelta={facts.DestinationFrameDeltaText}; " +
            $"frameDeltaWithinWindow={facts.FrameDeltaWithinWindow}; " +
            $"hdrpCameraMatchesEasuInput={facts.HdrpCameraMatchesEasuInput}; " +
            $"hdrpColorMatchesEasuInput={facts.HdrpColorMatchesEasuInput}; " +
            $"hdrpDepthMotionMatchEasuInput={facts.HdrpDepthMotionMatchEasuInput}; " +
            $"easuSourceMatchesEasuInput={facts.EasuSourceMatchesEasuInput}; " +
            $"easuDestinationMatchesEasuOutput={facts.EasuDestinationMatchesEasuOutput}; " +
            $"easuUpscales={facts.EasuUpscales}; " +
            $"hdrp=(call={hdrp.CallCount}; method={hdrp.MethodLabel}; {hdrp.CameraSummary}; {hdrp.SourceSummary}; {hdrp.DestinationSummary}; {hdrp.GlobalTextureSummary}); " +
            $"easu=(source=({easu.SourceObservation}); destination=({easu.DestinationObservation}); targetCompile={easu.TargetCompile}; targetManagedPassData={easu.TargetManagedPassData}; tuple={easu.TupleSummary})";
    }

    private static bool TryBuildCorrelationFactsLocked(HdrpInputSnapshot hdrp, EasuOutputSnapshot easu, out CorrelationFacts facts)
    {
        facts = default;
        if (!TryParseEasuTuple(easu.TupleSummary, out var inputWidth, out var inputHeight, out var outputWidth, out var outputHeight))
        {
            return false;
        }

        var inputToken = $"{inputWidth}x{inputHeight}";
        var outputToken = $"{outputWidth}x{outputHeight}";
        var sourceFrameDeltaText = TryGetFrameDelta(hdrp.FrameCount, easu.SourceFrameCount, out var sourceFrameDeltaValue)
            ? sourceFrameDeltaValue.GetValueOrDefault().ToString()
            : "unknown";
        var destinationFrameDeltaText = TryGetFrameDelta(hdrp.FrameCount, easu.DestinationFrameCount, out var destinationFrameDeltaValue)
            ? destinationFrameDeltaValue.GetValueOrDefault().ToString()
            : "unknown";

        facts = new CorrelationFacts(
            inputWidth,
            inputHeight,
            outputWidth,
            outputHeight,
            Contains(hdrp.CameraSummary, $"actualWidth={inputWidth}") && Contains(hdrp.CameraSummary, $"actualHeight={inputHeight}"),
            Contains(hdrp.SourceSummary, inputToken),
            Contains(hdrp.GlobalTextureSummary, inputToken),
            Contains(easu.SourceObservation, inputToken),
            Contains(easu.DestinationObservation, outputToken),
            outputWidth > inputWidth && outputHeight > inputHeight,
            sourceFrameDeltaValue.HasValue
                && destinationFrameDeltaValue.HasValue
                && Math.Abs(sourceFrameDeltaValue.Value) <= MaxCorrelationFrameDelta
                && Math.Abs(destinationFrameDeltaValue.Value) <= MaxCorrelationFrameDelta,
            sourceFrameDeltaText,
            destinationFrameDeltaText);
        return true;
    }

    private static string? TryBuildStatusMessageLocked(string source)
    {
        StatusLogCount++;
        if (StatusLogCount > MaxStatusLogs)
        {
            return null;
        }

        return "HDRP/EASU input-output correlation status #" + StatusLogCount + ": " +
            $"source={source}; " +
            $"hasHdrpInput={LatestHdrpInput.HasValue}; " +
            $"hasEasuOutput={LatestEasuOutput.HasValue}; " +
            $"advanced={AdvancedLogged}; " +
            $"hdrpFrame={(LatestHdrpInput.HasValue ? LatestHdrpInput.Value.FrameCount.ToString() : "unknown")}; " +
            $"easuSourceFrame={(LatestEasuOutput.HasValue ? LatestEasuOutput.Value.SourceFrameCount.ToString() : "unknown")}; " +
            $"easuDestinationFrame={(LatestEasuOutput.HasValue ? LatestEasuOutput.Value.DestinationFrameCount.ToString() : "unknown")}; " +
            $"easuTuple=\"{(LatestEasuOutput.HasValue ? LatestEasuOutput.Value.TupleSummary : "unknown")}\"";
    }

    private static void LogMessages(ManualLogSource? log, string? advanced, string? status)
    {
        if (advanced is not null)
        {
            log?.LogInfo(advanced);
            return;
        }

        if (status is not null)
        {
            log?.LogInfo(status);
        }
    }

    private static bool TryParseEasuTuple(string tuple, out int inputWidth, out int inputHeight, out int outputWidth, out int outputHeight)
    {
        inputWidth = 0;
        inputHeight = 0;
        outputWidth = 0;
        outputHeight = 0;

        var match = Regex.Match(tuple, @"input=(\d+)x(\d+);\s*output=(\d+)x(\d+)", RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            return false;
        }

        return int.TryParse(match.Groups[1].Value, out inputWidth)
            && int.TryParse(match.Groups[2].Value, out inputHeight)
            && int.TryParse(match.Groups[3].Value, out outputWidth)
            && int.TryParse(match.Groups[4].Value, out outputHeight);
    }

    private static bool Contains(string text, string value)
    {
        return text.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static bool TryGetFrameDelta(int hdrpFrame, int easuFrame, out int? delta)
    {
        if (hdrpFrame < 0 || easuFrame < 0)
        {
            delta = null;
            return false;
        }

        delta = easuFrame - hdrpFrame;
        return true;
    }

    internal readonly record struct HdrpInputSnapshot(
        int CallCount,
        int FrameCount,
        string MethodLabel,
        string CameraSummary,
        string SourceSummary,
        string DestinationSummary,
        string GlobalTextureSummary,
        IntPtr DepthPointer,
        IntPtr MotionPointer);

    internal readonly record struct EasuOutputSnapshot(
        IntPtr SourcePointer,
        IntPtr DestinationPointer,
        int SourceFrameCount,
        int DestinationFrameCount,
        int TargetCompile,
        string TargetManagedPassData,
        string TupleSummary,
        string SourceObservation,
        string DestinationObservation);

    internal readonly record struct FrameDescriptorSnapshot(
        IntPtr SourcePointer,
        IntPtr DestinationPointer,
        IntPtr DepthPointer,
        IntPtr MotionPointer,
        int InputWidth,
        int InputHeight,
        int OutputWidth,
        int OutputHeight,
        int HdrpFrame,
        int EasuSourceFrame,
        int EasuDestinationFrame,
        int TargetCompile,
        string HdrpMethodLabel,
        string TargetManagedPassData,
        string TupleSummary,
        string HdrpGlobalTextureSummary,
        string EasuSourceObservation,
        string EasuDestinationObservation);

    private readonly record struct CorrelationFacts(
        int InputWidth,
        int InputHeight,
        int OutputWidth,
        int OutputHeight,
        bool HdrpCameraMatchesEasuInput,
        bool HdrpColorMatchesEasuInput,
        bool HdrpDepthMotionMatchEasuInput,
        bool EasuSourceMatchesEasuInput,
        bool EasuDestinationMatchesEasuOutput,
        bool EasuUpscales,
        bool FrameDeltaWithinWindow,
        string SourceFrameDeltaText,
        string DestinationFrameDeltaText)
    {
        internal bool Ready =>
            HdrpCameraMatchesEasuInput
            && HdrpColorMatchesEasuInput
            && HdrpDepthMotionMatchEasuInput
            && EasuSourceMatchesEasuInput
            && EasuDestinationMatchesEasuOutput
            && EasuUpscales
            && FrameDeltaWithinWindow;
    }
}
