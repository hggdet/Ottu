#!/usr/bin/env python3
"""Validate that a packaged IPA contains unsigned iOS-device Mach-O binaries."""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import struct
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

IOS_DEVICE = 2
CPU_TYPE_ARM64 = 0x0100000C
# ARM64_ALL, ARM64_V8, ARM64E, and ARM64E ABI variants.
VALID_ARM64_SUBTYPES = {0, 1, 2, 3}
CPU_SUBTYPE_MASK = 0x00FFFFFF
LC_BUILD_VERSION = 0x32
LC_CODE_SIGNATURE = 0x1D
MACHO_MAGICS = {
    b"\xfe\xed\xfa\xce": (">", 28),
    b"\xce\xfa\xed\xfe": ("<", 28),
    b"\xfe\xed\xfa\xcf": (">", 32),
    b"\xcf\xfa\xed\xfe": ("<", 32),
}
FAT_MAGICS = {
    b"\xca\xfe\xba\xbe": (">", False),
    b"\xbe\xba\xfe\xca": ("<", False),
    b"\xca\xfe\xba\xbf": (">", True),
    b"\xbf\xba\xfe\xca": ("<", True),
}
DEFAULT_MANIFEST = Path(__file__).with_name("maplibre_device_manifest.json")
EXPECTED_APP_BUNDLE_IDENTIFIER = "iq.ottu.ios"
EXPECTED_WIDGET_BUNDLE_IDENTIFIER = "iq.ottu.ios.widget"


class ValidationError(Exception):
    """An IPA failed one or more structural or platform checks."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha256_and_size(path: Path) -> tuple[str, int]:
    """Return a streaming SHA256 and the exact number of bytes read from a file."""
    digest = hashlib.sha256()
    size = 0
    try:
        with path.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
                size += len(chunk)
    except OSError as exc:
        raise ValidationError(f"{path}: cannot read IPA for SHA256: {exc}") from exc
    return digest.hexdigest(), size


def require_bundle_identifier(info: dict[str, Any], expected: str, path: str) -> None:
    actual = info.get("CFBundleIdentifier")
    require(actual == expected,
            f"{path}: CFBundleIdentifier must be {expected!r}, got {actual!r}")


def macho_slices(data: bytes, path: str) -> list[tuple[int, int, int | None, int | None]]:
    """Return each thin slice range plus the universal-header CPU fields, if any."""
    magic = data[:4]
    if magic in MACHO_MAGICS:
        return [(0, len(data), None, None)]
    require(magic in FAT_MAGICS, f"{path}: unrecognized Mach-O format")
    endian, is_64 = FAT_MAGICS[magic]
    require(len(data) >= 8, f"{path}: truncated universal Mach-O header")
    count = struct.unpack_from(endian + "I", data, 4)[0]
    entry_size = 32 if is_64 else 20
    require(count > 0, f"{path}: universal Mach-O has no slices")
    require(8 + count * entry_size <= len(data), f"{path}: truncated universal architecture table")
    slices: list[tuple[int, int, int | None, int | None]] = []
    seen: set[tuple[int, int]] = set()
    offset = 8
    for _ in range(count):
        if is_64:
            cpu_type, cpu_subtype, slice_offset, slice_size, _, _ = struct.unpack_from(endian + "IIQQII", data, offset)
        else:
            cpu_type, cpu_subtype, slice_offset, slice_size, _ = struct.unpack_from(endian + "IIIII", data, offset)
        require(slice_size > 0 and slice_offset + slice_size <= len(data), f"{path}: invalid universal slice bounds")
        require(data[slice_offset : slice_offset + 4] in MACHO_MAGICS, f"{path}: universal slice is not a thin Mach-O")
        arch = (cpu_type, cpu_subtype)
        require(arch not in seen, f"{path}: duplicate universal architecture entry {arch}")
        seen.add(arch)
        slices.append((slice_offset, slice_size, cpu_type, cpu_subtype))
        offset += entry_size
    return slices


def inspect_macho_slice(data: bytes, path: str, index: int,
                        fat_cpu_type: int | None = None,
                        fat_cpu_subtype: int | None = None) -> dict[str, Any]:
    magic = data[:4]
    require(magic in MACHO_MAGICS, f"{path}: slice {index} has an unsupported Mach-O header")
    endian, header_size = MACHO_MAGICS[magic]
    require(len(data) >= header_size, f"{path}: slice {index} has a truncated Mach-O header")
    cpu_type, cpu_subtype, _, command_count, command_bytes, _ = struct.unpack_from(endian + "iiIIII", data, 4)
    require(cpu_type == CPU_TYPE_ARM64, f"{path}: slice {index} CPU type 0x{cpu_type & 0xffffffff:08x} is not arm64")
    subtype = cpu_subtype & CPU_SUBTYPE_MASK
    require(subtype in VALID_ARM64_SUBTYPES, f"{path}: slice {index} has invalid arm64 CPU subtype {subtype}")
    if fat_cpu_type is not None:
        require((cpu_type & 0xFFFFFFFF) == fat_cpu_type and (cpu_subtype & 0xFFFFFFFF) == fat_cpu_subtype,
                f"{path}: universal entry CPU type/subtype does not match thin slice {index}")
    require(header_size + command_bytes <= len(data), f"{path}: slice {index} has truncated load commands")

    offset = header_size
    command_end = header_size + command_bytes
    platforms: list[int] = []
    has_signature = False
    for _ in range(command_count):
        require(offset + 8 <= command_end, f"{path}: slice {index} has a truncated load command")
        command, command_size = struct.unpack_from(endian + "II", data, offset)
        require(command_size >= 8 and offset + command_size <= command_end,
                f"{path}: slice {index} has an invalid load command size")
        if command == LC_BUILD_VERSION:
            require(command_size >= 24, f"{path}: slice {index} has a truncated LC_BUILD_VERSION")
            platforms.append(struct.unpack_from(endian + "I", data, offset + 8)[0])
        if command == LC_CODE_SIGNATURE:
            has_signature = True
        offset += command_size
    require(offset == command_end, f"{path}: slice {index} load-command sizes do not match the header")
    require(len(platforms) == 1 and platforms[0] == IOS_DEVICE,
            f"{path}: slice {index} must have exactly one LC_BUILD_VERSION for iOS device (2), found {platforms}")
    require(not has_signature, f"{path}: slice {index} contains LC_CODE_SIGNATURE")
    return {
        "architecture": "arm64",
        "cpu_type": f"0x{cpu_type & 0xffffffff:08x}",
        "cpu_subtype": subtype,
        "platform": IOS_DEVICE,
        "platform_name": "iOS device",
    }


def find_simulator_markers(value: Any, key: str = "") -> list[str]:
    markers: list[str] = []
    if isinstance(value, dict):
        for child_key, child in value.items():
            markers.extend(find_simulator_markers(child, str(child_key)))
    elif isinstance(value, (list, tuple)):
        for child in value:
            markers.extend(find_simulator_markers(child, key))
    elif isinstance(value, str):
        folded = value.casefold().replace(" ", "")
        if folded.startswith(("iphonesimulator", "tvosimulator", "watchossimulator", "visionsimulator")) or (
            "platform" in key.casefold() and folded == "simulator"
        ):
            markers.append(f"{key}={value}")
    return markers


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValidationError(f"cannot read MapLibre device-source manifest {path}: {exc}") from exc
    require(isinstance(value, dict) and value.get("schema_version") == 1,
            f"{path}: unsupported or malformed manifest")
    source = value.get("source")
    slice_info = value.get("xcframework_slice")
    require(isinstance(source, dict) and isinstance(slice_info, dict), f"{path}: incomplete manifest")
    files = slice_info.get("framework_files_sha256")
    require(isinstance(files, dict) and files, f"{path}: manifest has no framework file hashes")
    require(source.get("archive_sha256") == "de3aaa435dd86768b06d90245e630d068dd7eef1491afae7217d1654c52c462a",
            f"{path}: unexpected MapLibre source archive checksum")
    require(slice_info.get("library_identifier") == "ios-arm64"
            and slice_info.get("supported_architectures") == ["arm64"],
            f"{path}: device slice is not the pinned ios-arm64 slice")
    return value


def prove_maplibre_framework(archive: zipfile.ZipFile, names: set[str], root: str,
                             manifest: dict[str, Any]) -> dict[str, Any]:
    """Prove exact framework provenance; only public headers/modules may be stripped."""
    item = manifest["xcframework_slice"]
    expected: dict[str, str] = item["framework_files_sha256"]
    prefix = root
    actual_paths = {name[len(prefix):] for name in names if name.startswith(prefix)}
    required = set(item["required_files"])
    optional = set(item["optional_strippable_files"])
    require(required | optional == set(expected), f"manifest: file classification is inconsistent")
    missing = required - actual_paths
    extra = actual_paths - set(expected)
    require(not missing, f"{root}: missing required MapLibre source resources/files: {sorted(missing)}")
    require(not extra, f"{root}: unrecognized files prevent MapLibre provenance proof: {sorted(extra)}")
    compared: dict[str, str] = {}
    for relative_path in sorted(actual_paths):
        member = prefix + relative_path
        actual_hash = sha256(archive.read(member))
        require(actual_hash == expected[relative_path],
                f"{member}: SHA256 differs from pinned MapLibre ios-arm64 source manifest")
        compared[relative_path] = actual_hash
    require("Info.plist" in compared and "MapLibre" in compared,
            f"{root}: framework Info.plist and executable must both match the source manifest")
    return {
        "status": "PASS",
        "source_url": manifest["source"]["url"],
        "source_revision": manifest["source"]["revision"],
        "source_archive_sha256": manifest["source"]["archive_sha256"],
        "xcframework_library_identifier": item["library_identifier"],
        "matched_executable_sha256": compared["MapLibre"],
        "matched_framework_info_plist_sha256": compared["Info.plist"],
        "matched_file_count": len(compared),
        "omitted_strippable_header_or_module_file_count": len(optional - actual_paths),
        "selection_proof": "packaged MapLibre.framework executable hash matches the pinned ios-arm64 XCFramework executable",
    }


def load_plist(archive: zipfile.ZipFile, path: str) -> dict[str, Any]:
    try:
        value = plistlib.loads(archive.read(path))
    except (KeyError, plistlib.InvalidFileException, ValueError) as exc:
        raise ValidationError(f"{path}: cannot read property list: {exc}") from exc
    require(isinstance(value, dict), f"{path}: property list root is not a dictionary")
    return value


def require_device_bundle_info(info: dict[str, Any], path: str) -> None:
    require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
            f"{path}: CFBundleSupportedPlatforms must be ['iPhoneOS'], got {info.get('CFBundleSupportedPlatforms')!r}")
    require(info.get("DTPlatformName") == "iphoneos",
            f"{path}: DTPlatformName must be 'iphoneos', got {info.get('DTPlatformName')!r}")
    sdk = info.get("DTSDKName")
    require(isinstance(sdk, str) and sdk.casefold().startswith("iphoneos"),
            f"{path}: DTSDKName must identify iphoneos, got {sdk!r}")
    markers = find_simulator_markers(info)
    require(not markers, f"{path}: simulator platform metadata is forbidden for executable bundles: {markers}")


def ancestors_with_info(path: str, info_paths: set[str]) -> list[str]:
    parts = PurePosixPath(path).parts[:-1]
    candidates = []
    for end in range(1, len(parts) + 1):
        candidate = "/".join((*parts[:end], "Info.plist"))
        if candidate in info_paths:
            candidates.append(candidate)
    return candidates


def validate(path: str, manifest_path: str | Path | None = None) -> dict[str, Any]:
    ipa_path = Path(path)
    ipa_sha256, ipa_size_bytes = file_sha256_and_size(ipa_path)
    manifest = load_manifest(Path(manifest_path) if manifest_path else DEFAULT_MANIFEST)
    try:
        archive = zipfile.ZipFile(ipa_path)
    except (OSError, zipfile.BadZipFile) as exc:
        raise ValidationError(f"{path}: not a readable IPA/ZIP: {exc}") from exc

    with archive:
        try:
            bad_member = archive.testzip()
        except (OSError, RuntimeError, zipfile.BadZipFile) as exc:
            raise ValidationError(f"{path}: ZIP integrity check failed: {exc}") from exc
        require(bad_member is None, f"{path}: ZIP CRC failure in {bad_member}")
        names = [name for name in archive.namelist() if not name.endswith("/")]
        name_set = set(names)
        require(len(names) == len(name_set), "IPA contains duplicate ZIP member names")
        require(any(name.startswith("Payload/") for name in names), "IPA has no Payload directory")
        for name in names:
            parts = PurePosixPath(name).parts
            require(not name.startswith("/") and ".." not in parts, f"IPA contains unsafe member path {name!r}")

        signatures = [
            name for name in names
            if "_CodeSignature" in PurePosixPath(name).parts
            or PurePosixPath(name).name in {"CodeResources", "embedded.mobileprovision", "embedded.provisionprofile"}
        ]
        require(not signatures, f"unsigned IPA contains signature/provisioning files: {signatures}")

        info_paths = {name for name in names if PurePosixPath(name).name == "Info.plist"}
        infos = {info_path: load_plist(archive, info_path) for info_path in sorted(info_paths)}
        app_infos = [name for name in infos if name.startswith("Payload/") and name.count("/") == 2 and name.endswith(".app/Info.plist")]
        require(len(app_infos) == 1, f"expected exactly one top-level app Info.plist, found {app_infos}")
        app_info_path = app_infos[0]
        app_root = app_info_path.removesuffix("Info.plist")
        require_bundle_identifier(infos[app_info_path], EXPECTED_APP_BUNDLE_IDENTIFIER, app_info_path)
        widget_infos = [
            name for name in infos
            if name.startswith(app_root + "PlugIns/") and name.endswith(".appex/Info.plist")
        ]
        require(len(widget_infos) == 1, f"expected exactly one embedded widget extension, found {widget_infos}")
        widget_info = infos[widget_infos[0]]
        require_bundle_identifier(widget_info, EXPECTED_WIDGET_BUNDLE_IDENTIFIER, widget_infos[0])

        framework_roots = {
            "/".join(parts[:index + 1]) + "/"
            for name in names
            for parts in [PurePosixPath(name).parts]
            for index, part in enumerate(parts)
            if part.endswith(".framework")
        }
        maplibre_proofs: dict[str, dict[str, Any]] = {}
        for framework_root in sorted(framework_roots):
            info_path = framework_root + "Info.plist"
            require(info_path in infos, f"framework {framework_root} has no Info.plist")
            info = infos[info_path]
            executable = info.get("CFBundleExecutable")
            require(isinstance(executable, str) and executable and "/" not in executable,
                    f"{info_path}: framework has no valid CFBundleExecutable")
            require(framework_root + executable in name_set,
                    f"{info_path}: missing framework executable {framework_root + str(executable)}")
            if PurePosixPath(framework_root.rstrip("/")).name == "MapLibre.framework":
                maplibre_proofs[framework_root] = prove_maplibre_framework(archive, name_set, framework_root, manifest)

        executable_bundles: dict[str, tuple[str, dict[str, Any]]] = {}
        for info_path, info in infos.items():
            executable = info.get("CFBundleExecutable")
            if not executable:
                continue
            require(isinstance(executable, str) and "/" not in executable and executable not in {".", ".."},
                    f"{info_path}: invalid CFBundleExecutable {executable!r}")
            executable_path = info_path.removesuffix("Info.plist") + executable
            require(executable_path in name_set, f"{info_path}: missing executable {executable_path}")
            executable_bundles[executable_path] = (info_path, info)

        app_executable = app_root + str(infos[app_info_path].get("CFBundleExecutable", ""))
        require(app_executable in executable_bundles, f"{app_info_path}: app executable is missing")
        require(widget_info.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension",
                f"{widget_infos[0]}: not a WidgetKit extension")

        # Enforce device metadata for every executable bundle. The sole exception
        # requires an exact manifest proof for the known upstream MapLibre framework.
        metadata_warnings: list[dict[str, str]] = []
        proof_by_info = {root + "Info.plist": proof for root, proof in maplibre_proofs.items()}
        for executable_path, (info_path, info) in executable_bundles.items():
            if info_path in proof_by_info:
                markers = find_simulator_markers(info)
                if markers:
                    metadata_warnings.append({
                        "path": info_path,
                        "warning": "Verified pinned upstream MapLibre ios-arm64 framework metadata is mislabeled as simulator; exact Info.plist and every packaged framework file match the device-source manifest, and the executable's Mach-O platform is validated independently.",
                        "markers": "; ".join(markers),
                    })
            else:
                require_device_bundle_info(info, info_path)

        macho_files: list[str] = []
        binary_reports: list[dict[str, Any]] = []
        total_slices = 0
        for member in names:
            data = archive.read(member)
            if data[:4] not in MACHO_MAGICS and data[:4] not in FAT_MAGICS:
                require(not member.casefold().endswith(".dylib"), f"{member}: .dylib is not a Mach-O binary")
                require(member not in executable_bundles, f"{member}: CFBundleExecutable is not a Mach-O binary")
                continue
            slices = macho_slices(data, member)
            parents = ancestors_with_info(member, set(infos))
            require(bool(parents), f"{member}: Mach-O has no enclosing bundle Info.plist")
            nearest_info_path = parents[-1]
            require(nearest_info_path in proof_by_info or nearest_info_path in infos,
                    f"{member}: missing enclosing bundle metadata")
            slice_reports = []
            for index, (offset, size, fat_cpu_type, fat_cpu_subtype) in enumerate(slices):
                slice_reports.append(inspect_macho_slice(data[offset:offset + size], member, index, fat_cpu_type, fat_cpu_subtype))
                total_slices += 1
            proof = proof_by_info.get(nearest_info_path)
            binary_report: dict[str, Any] = {
                "path": member,
                "sha256": sha256(data),
                "architectures": slice_reports,
                "manifest_proof": proof if member == nearest_info_path.removesuffix("Info.plist") + "MapLibre" else None,
            }
            macho_files.append(member)
            binary_reports.append(binary_report)

        require(app_executable in macho_files, f"{app_info_path}: app executable is not a valid Mach-O")
        widget_executable = widget_infos[0].removesuffix("Info.plist") + str(widget_info.get("CFBundleExecutable", ""))
        require(widget_executable in macho_files, f"{widget_infos[0]}: widget executable is not a valid Mach-O")
        require(macho_files, "IPA contains no Mach-O binaries")
        require(maplibre_proofs, "IPA contains no MapLibre.framework with verifiable pinned ios-arm64 device-source provenance")

        return {
            "ipa": str(ipa_path),
            "ipa_sha256": ipa_sha256,
            "ipa_size_bytes": ipa_size_bytes,
            "zip_integrity": "PASS",
            "unsigned": True,
            "platform": "iOS device",
            "app": app_info_path,
            "widget": widget_infos[0],
            "macho_files": len(macho_files),
            "macho_slices": total_slices,
            "binaries": binary_reports,
            "maplibre_device_manifest": {
                "source": manifest["source"],
                "xcframework_slice": manifest["xcframework_slice"]["library_identifier"],
                "frameworks": maplibre_proofs,
                "metadata_warnings": metadata_warnings,
            },
            "result": "PASS",
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", help="path to the packaged unsigned IPA")
    parser.add_argument("--manifest", help="path to the MapLibre provenance manifest")
    parser.add_argument("--json-output", help="also save the complete validation JSON report here")
    args = parser.parse_args()
    try:
        result = validate(args.ipa, args.manifest)
    except (ValidationError, KeyError, OSError, struct.error, zipfile.BadZipFile) as exc:
        result = {"ipa": args.ipa, "result": "FAIL", "error": str(exc)}
        print(f"IPA validation FAILED: {exc}", file=sys.stderr)
        if args.json_output:
            try:
                Path(args.json_output).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            except OSError as write_exc:
                print(f"could not write validation JSON: {write_exc}", file=sys.stderr)
        return 1
    serialized = json.dumps(result, indent=2, ensure_ascii=False)
    print(serialized)
    if args.json_output:
        try:
            Path(args.json_output).write_text(serialized + "\n", encoding="utf-8")
        except OSError as exc:
            print(f"could not write validation JSON: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
