import argparse
import contextlib
import io
import json
import platform
import re
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Read V Rising HDRP asset dynamic-resolution/DLSS settings without launching the game."
    )
    parser.add_argument("--game-path", required=True)
    parser.add_argument("--dummy-dll-path", required=True)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def read_text_or_none(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None


def read_unity_version(globalgamemanagers_path):
    try:
        raw = Path(globalgamemanagers_path).read_bytes()
    except OSError:
        return None

    match = re.search(rb"\b20\d{2}\.\d+\.\d+f\d+\b", raw)
    if not match:
        return None
    return match.group(0).decode("ascii", errors="replace")


def printable_strings(raw, min_len=4):
    pattern = rb"[ -~]{" + str(min_len).encode("ascii") + rb",}"
    return [value.decode("utf-8", errors="replace") for value in re.findall(pattern, raw)]


def get_pptr_path_id(value):
    if isinstance(value, dict):
        return value.get("m_PathID")
    return getattr(value, "path_id", None)


def get_pptr_file_id(value):
    if isinstance(value, dict):
        return value.get("m_FileID")
    return getattr(value, "file_id", None)


def enum_name(enum_map, value):
    return enum_map.get(value, None)


def make_error(status, message, game_path, dummy_dll_path):
    return {
        "Status": status,
        "LaunchesGame": False,
        "ModifiesGameFiles": False,
        "GamePath": str(game_path),
        "DummyDllPath": str(dummy_dll_path),
        "Error": message,
    }


def main():
    args = parse_args()
    game_path = Path(args.game_path)
    dummy_dll_path = Path(args.dummy_dll_path)
    data_path = game_path / "VRising_Data"
    globalgamemanagers_path = data_path / "globalgamemanagers"
    globalgamemanagers_assets_path = data_path / "globalgamemanagers.assets"

    if not game_path.exists():
        print(json.dumps(make_error("Fail", f"Game path not found: {game_path}", game_path, dummy_dll_path), indent=2))
        return 2

    if not globalgamemanagers_path.exists() or not globalgamemanagers_assets_path.exists():
        print(json.dumps(make_error("Fail", "Required globalgamemanagers asset files are missing.", game_path, dummy_dll_path), indent=2))
        return 2

    if not dummy_dll_path.exists():
        print(json.dumps(make_error("Fail", f"DummyDll path not found: {dummy_dll_path}", game_path, dummy_dll_path), indent=2))
        return 2

    try:
        import UnityPy
        from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator
    except Exception as exc:
        message = (
            f"Missing Python dependency: {type(exc).__name__}: {exc}. "
            "Install UnityPy and TypeTreeGeneratorAPI into the selected Python environment."
        )
        print(json.dumps(make_error("Fail", message, game_path, dummy_dll_path), indent=2))
        return 2

    unity_version = read_unity_version(globalgamemanagers_path) or "2022.3.58f1"
    game_version = read_text_or_none(game_path / "VERSION")
    warnings = []

    graphics_settings = {}
    try:
        env_global = UnityPy.load(str(globalgamemanagers_path))
        graphics_objects = [obj for obj in env_global.objects if str(obj.type.name) == "GraphicsSettings"]
        if graphics_objects:
            graphics_tree = graphics_objects[0].read_typetree()
            custom_pipeline = graphics_tree.get("m_CustomRenderPipeline", {})
            graphics_settings = {
                "PathId": graphics_objects[0].path_id,
                "CustomRenderPipeline": {
                    "FileId": get_pptr_file_id(custom_pipeline),
                    "PathId": get_pptr_path_id(custom_pipeline),
                },
            }
        else:
            warnings.append("GraphicsSettings object was not found in globalgamemanagers.")
    except Exception as exc:
        warnings.append(f"Failed to read GraphicsSettings: {type(exc).__name__}: {exc}")

    type_tree_log = io.StringIO()
    try:
        with contextlib.redirect_stdout(type_tree_log), contextlib.redirect_stderr(type_tree_log):
            generator = TypeTreeGenerator(unity_version)
            generator.load_local_dll_folder(str(dummy_dll_path))
    except Exception as exc:
        result = make_error(
            "Fail",
            f"Failed to initialize TypeTreeGenerator from DummyDll: {type(exc).__name__}: {exc}",
            game_path,
            dummy_dll_path,
        )
        result["ToolingLog"] = type_tree_log.getvalue().strip()
        print(json.dumps(result, indent=2))
        return 2

    if type_tree_log.getvalue().strip():
        warnings.append(type_tree_log.getvalue().strip())

    env_assets = UnityPy.load(str(globalgamemanagers_assets_path))
    env_assets.typetree_generator = generator

    script_names = {}
    for obj in env_assets.objects:
        if str(obj.type.name) != "MonoScript":
            continue
        try:
            data = obj.read()
            script_names[obj.path_id] = getattr(data, "name", "") or getattr(data, "m_Name", "") or ""
        except Exception:
            continue

    upsample_filter_names = {
        0: "Bilinear",
        1: "CatmullRom",
        2: "Lanczos",
        3: "ContrastAdaptiveSharpen",
        4: "EdgeAdaptiveScalingUpres",
        5: "TAAU",
    }
    dyn_res_type_names = {
        0: "Software",
        1: "Hardware",
    }
    dlss_injection_names = {
        0: "BeforePost",
        1: "AfterDepthOfField",
        2: "AfterPost",
    }

    active_path_id = graphics_settings.get("CustomRenderPipeline", {}).get("PathId")
    hdrp_assets = []
    global_settings = []

    for obj in env_assets.objects:
        if str(obj.type.name) != "MonoBehaviour":
            continue

        try:
            head = obj.parse_monobehaviour_head()
        except Exception:
            continue

        script_id = getattr(head.m_Script, "path_id", None)
        script_name = script_names.get(script_id, "")
        name = head.m_Name

        if script_name == "HDRenderPipelineAsset":
            entry = {
                "PathId": obj.path_id,
                "Name": name,
                "ScriptPathId": script_id,
                "ScriptName": script_name,
                "IsActiveCustomRenderPipeline": obj.path_id == active_path_id,
                "ParseStatus": "Unknown",
            }
            try:
                tree = obj.read_typetree()
                drs = tree.get("m_RenderPipelineSettings", {}).get("dynamicResolutionSettings", {})
                entry.update(
                    {
                        "ParseStatus": "Pass",
                        "AllowShaderVariantStripping": tree.get("allowShaderVariantStripping"),
                        "EnableSRPBatcher": tree.get("enableSRPBatcher"),
                        "UseRenderGraph": tree.get("m_UseRenderGraph"),
                        "Version": tree.get("m_Version"),
                        "DynamicResolutionSettings": dict(drs),
                    }
                )
                if "upsampleFilter" in drs:
                    entry["DynamicResolutionSettings"]["upsampleFilterName"] = enum_name(
                        upsample_filter_names, drs.get("upsampleFilter")
                    )
                if "dynResType" in drs:
                    entry["DynamicResolutionSettings"]["dynResTypeName"] = enum_name(
                        dyn_res_type_names, drs.get("dynResType")
                    )
                if "DLSSInjectionPoint" in drs:
                    entry["DynamicResolutionSettings"]["DLSSInjectionPointName"] = enum_name(
                        dlss_injection_names, drs.get("DLSSInjectionPoint")
                    )
            except Exception as exc:
                entry["ParseStatus"] = "Fail"
                entry["Error"] = f"{type(exc).__name__}: {exc}"

            hdrp_assets.append(entry)

        elif script_name == "HDRenderPipelineGlobalSettings":
            entry = {
                "PathId": obj.path_id,
                "Name": name,
                "ScriptPathId": script_id,
                "ScriptName": script_name,
                "ParseStatus": "Unknown",
            }
            try:
                tree = obj.read_typetree()
                entry["ParseStatus"] = "Pass"
                entry["TopLevelKeys"] = list(tree.keys())
            except Exception as exc:
                raw_strings = printable_strings(obj.get_raw_data())
                entry["ParseStatus"] = "Partial"
                entry["Error"] = f"{type(exc).__name__}: {exc}"
                entry["ProjectMTypeStrings"] = [
                    value for value in raw_strings if "ProjectM" in value or value in {"CustomVignette", "DarkForeground", "BatFormFog"}
                ]
            global_settings.append(entry)

    active_asset = next((asset for asset in hdrp_assets if asset.get("IsActiveCustomRenderPipeline")), None)
    status = "Pass" if active_asset and active_asset.get("ParseStatus") == "Pass" else "Fail"
    summary = {}
    if active_asset:
        drs = active_asset.get("DynamicResolutionSettings", {})
        summary = {
            "ActiveAssetName": active_asset.get("Name"),
            "ActiveAssetPathId": active_asset.get("PathId"),
            "UseRenderGraph": active_asset.get("UseRenderGraph"),
            "DynamicResolutionEnabled": drs.get("enabled"),
            "EnableDLSS": drs.get("enableDLSS"),
            "DLSSInjectionPoint": drs.get("DLSSInjectionPoint"),
            "DLSSInjectionPointName": drs.get("DLSSInjectionPointName"),
            "DynamicResolutionType": drs.get("dynResType"),
            "DynamicResolutionTypeName": drs.get("dynResTypeName"),
            "UpsampleFilter": drs.get("upsampleFilter"),
            "UpsampleFilterName": drs.get("upsampleFilterName"),
        }

    result = {
        "Status": status,
        "LaunchesGame": False,
        "ModifiesGameFiles": False,
        "GamePath": str(game_path),
        "GameVersion": game_version,
        "UnityVersion": unity_version,
        "DummyDllPath": str(dummy_dll_path),
        "Python": sys.executable,
        "PythonVersion": platform.python_version(),
        "UnityPyVersion": getattr(UnityPy, "__version__", None),
        "GraphicsSettings": graphics_settings,
        "Summary": summary,
        "HdrpAssets": sorted(hdrp_assets, key=lambda item: item.get("PathId", 0)),
        "HdrpGlobalSettings": global_settings,
        "Warnings": warnings,
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Status: {result['Status']}")
        print(f"LaunchesGame: {result['LaunchesGame']}")
        print(f"ModifiesGameFiles: {result['ModifiesGameFiles']}")
        print(f"GameVersion: {result.get('GameVersion')}")
        print(f"UnityVersion: {result.get('UnityVersion')}")
        if summary:
            print(
                "ActiveHDRP: "
                f"name={summary.get('ActiveAssetName')}; "
                f"pathId={summary.get('ActiveAssetPathId')}; "
                f"useRenderGraph={summary.get('UseRenderGraph')}; "
                f"dynamicResolutionEnabled={summary.get('DynamicResolutionEnabled')}; "
                f"enableDLSS={summary.get('EnableDLSS')}; "
                f"DLSSInjectionPoint={summary.get('DLSSInjectionPointName')}; "
                f"dynResType={summary.get('DynamicResolutionTypeName')}; "
                f"upsampleFilter={summary.get('UpsampleFilterName')}"
            )
        for asset in result["HdrpAssets"]:
            drs = asset.get("DynamicResolutionSettings", {})
            print(
                "HDRPAsset: "
                f"name={asset.get('Name')}; "
                f"pathId={asset.get('PathId')}; "
                f"active={asset.get('IsActiveCustomRenderPipeline')}; "
                f"parse={asset.get('ParseStatus')}; "
                f"useRenderGraph={asset.get('UseRenderGraph')}; "
                f"drsEnabled={drs.get('enabled')}; "
                f"enableDLSS={drs.get('enableDLSS')}; "
                f"upsampleFilter={drs.get('upsampleFilterName')}"
            )
        if warnings:
            print("Warnings:")
            for warning in warnings:
                print(f"- {warning}")

    return 0 if status == "Pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
