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
        if (!TryParseEasuTuple(easu.TupleSummary, out var inputWidth, out var inputHeight, out var outputWidth, out var outputHeight))
        {
            return null;
        }

        var inputToken = $"{inputWidth}x{inputHeight}";
        var outputToken = $"{outputWidth}x{outputHeight}";
        var hdrpCameraMatchesEasuInput = Contains(hdrp.CameraSummary, $"actualWidth={inputWidth}")
            && Contains(hdrp.CameraSummary, $"actualHeight={inputHeight}");
        var hdrpColorMatchesEasuInput = Contains(hdrp.SourceSummary, inputToken);
        var hdrpDepthMotionMatchEasuInput = Contains(hdrp.GlobalTextureSummary, inputToken);
        var easuSourceMatchesEasuInput = Contains(easu.SourceObservation, inputToken);
        var easuDestinationMatchesEasuOutput = Contains(easu.DestinationObservation, outputToken);
        var easuUpscales = outputWidth > inputWidth && outputHeight > inputHeight;
        var sourceFrameDelta = TryGetFrameDelta(hdrp.FrameCount, easu.SourceFrameCount, out var sourceFrameDeltaValue)
            ? sourceFrameDeltaValue.ToString()
            : "unknown";
        var destinationFrameDelta = TryGetFrameDelta(hdrp.FrameCount, easu.DestinationFrameCount, out var destinationFrameDeltaValue)
            ? destinationFrameDeltaValue.ToString()
            : "unknown";
        var frameDeltaWithinWindow = sourceFrameDeltaValue.HasValue
            && destinationFrameDeltaValue.HasValue
            && Math.Abs(sourceFrameDeltaValue.Value) <= MaxCorrelationFrameDelta
            && Math.Abs(destinationFrameDeltaValue.Value) <= MaxCorrelationFrameDelta;
        if (!hdrpCameraMatchesEasuInput
            || !hdrpColorMatchesEasuInput
            || !hdrpDepthMotionMatchEasuInput
            || !easuSourceMatchesEasuInput
            || !easuDestinationMatchesEasuOutput
            || !easuUpscales
            || !frameDeltaWithinWindow)
        {
            return null;
        }

        AdvancedLogged = true;
        return "HDRP/EASU input-output correlation advanced: " +
            $"hdrpFrame={hdrp.FrameCount}; " +
            $"easuSourceFrame={easu.SourceFrameCount}; " +
            $"easuDestinationFrame={easu.DestinationFrameCount}; " +
            $"sourceFrameDelta={sourceFrameDelta}; " +
            $"destinationFrameDelta={destinationFrameDelta}; " +
            $"frameDeltaWithinWindow={frameDeltaWithinWindow}; " +
            $"hdrpCameraMatchesEasuInput={hdrpCameraMatchesEasuInput}; " +
            $"hdrpColorMatchesEasuInput={hdrpColorMatchesEasuInput}; " +
            $"hdrpDepthMotionMatchEasuInput={hdrpDepthMotionMatchEasuInput}; " +
            $"easuSourceMatchesEasuInput={easuSourceMatchesEasuInput}; " +
            $"easuDestinationMatchesEasuOutput={easuDestinationMatchesEasuOutput}; " +
            $"easuUpscales={easuUpscales}; " +
            $"hdrp=(call={hdrp.CallCount}; method={hdrp.MethodLabel}; {hdrp.CameraSummary}; {hdrp.SourceSummary}; {hdrp.DestinationSummary}; {hdrp.GlobalTextureSummary}); " +
            $"easu=(source=({easu.SourceObservation}); destination=({easu.DestinationObservation}); targetCompile={easu.TargetCompile}; targetManagedPassData={easu.TargetManagedPassData}; tuple={easu.TupleSummary})";
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
        string GlobalTextureSummary);

    internal readonly record struct EasuOutputSnapshot(
        int SourceFrameCount,
        int DestinationFrameCount,
        int TargetCompile,
        string TargetManagedPassData,
        string TupleSummary,
        string SourceObservation,
        string DestinationObservation);
}
