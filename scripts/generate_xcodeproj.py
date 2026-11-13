#!/usr/bin/env python3
"""Generate AntennaPod.xcodeproj from the source tree.

The project is intentionally generated: every Swift file under AntennaPod/ is
picked up automatically, so adding a screen never requires editing a fragile
pbxproj by hand. Run from the repository root:

    python3 scripts/generate_xcodeproj.py

Requires nothing beyond the Python standard library.
"""

from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "AntennaPod"
PACKAGE_RELATIVE = "Packages/AntennaPodCore"
PROJECT_NAME = "AntennaPod"
BUNDLE_ID = "org.antennapod.ios"
TARGET_NAME = "AntennaPod"
DEPLOYMENT_TARGET = "15.0"
SWIFT_VERSION = "5.0"


def uid(*parts: str) -> str:
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest().upper()
    return digest[:24]


def quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def path_comment(path: str) -> str:
    return path.replace("*/", "*_/")


class Generator:
    def __init__(self) -> None:
        self.file_refs: list[tuple[str, str, str, str]] = []  # uuid, name, path, type
        self.build_files: list[tuple[str, str, str, str]] = []  # uuid, ref uuid, name, phase
        self.groups: list[str] = []
        self.sources: list[tuple[str, str]] = []
        self.resources: list[tuple[str, str]] = []

    def build(self) -> str:
        self.groups.append(self.render_group("AntennaPod", APP_DIR, APP_DIR, top_level=True))

        product_ref = uid("product", TARGET_NAME)
        products_group = uid("group", "Products")
        main_group = uid("group", "main")

        source_phase = uid("phase", "sources")
        framework_phase = uid("phase", "frameworks")
        resources_phase = uid("phase", "resources")
        target = uid("target", TARGET_NAME)
        project = uid("project", PROJECT_NAME)
        project_config_list = uid("configlist", "project")
        target_config_list = uid("configlist", "target")
        project_debug = uid("config", "project", "debug")
        project_release = uid("config", "project", "release")
        target_debug = uid("config", "target", "debug")
        target_release = uid("config", "target", "release")
        package_ref = uid("package", PACKAGE_RELATIVE)
        package_product = uid("packageproduct", "AntennaPodCore")
        package_build_file = uid("buildfile", "AntennaPodCore")

        lines: list[str] = []
        add = lines.append

        add("// !$*UTF8*$!")
        add("{")
        add("\tarchiveVersion = 1;")
        add("\tclasses = {")
        add("\t};")
        add("\tobjectVersion = 56;")
        add("\tobjects = {")
        add("")

        add("/* Begin PBXBuildFile section */")
        for build_uuid, ref_uuid, name, phase in self.build_files:
            add(
                f"\t\t{build_uuid} /* {path_comment(name)} in {phase} */ = "
                f"{{isa = PBXBuildFile; fileRef = {ref_uuid} /* {path_comment(name)} */; }};"
            )
        add(
            f"\t\t{package_build_file} /* AntennaPodCore in Frameworks */ = "
            f"{{isa = PBXBuildFile; productRef = {package_product} /* AntennaPodCore */; }};"
        )
        add("/* End PBXBuildFile section */")
        add("")

        add("/* Begin PBXFileReference section */")
        for ref_uuid, name, path, file_type in self.file_refs:
            add(
                f"\t\t{ref_uuid} /* {path_comment(name)} */ = "
                f"{{isa = PBXFileReference; lastKnownFileType = {file_type}; "
                f"path = {quote(path)}; sourceTree = \"<group>\"; }};"
            )
        add(
            f"\t\t{product_ref} /* {TARGET_NAME}.app */ = "
            f"{{isa = PBXFileReference; explicitFileType = wrapper.application; "
            f"includeInIndex = 0; path = {TARGET_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
        )
        add("/* End PBXFileReference section */")
        add("")

        add("/* Begin PBXFrameworksBuildPhase section */")
        add(f"\t\t{framework_phase} /* Frameworks */ = {{")
        add("\t\t\tisa = PBXFrameworksBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        add(f"\t\t\t\t{package_build_file} /* AntennaPodCore in Frameworks */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
        add("/* End PBXFrameworksBuildPhase section */")
        add("")

        add("/* Begin PBXGroup section */")
        add(f"\t\t{main_group} = {{")
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        add(f"\t\t\t\t{uid('group', str(APP_DIR))} /* AntennaPod */,")
        add(f"\t\t\t\t{products_group} /* Products */,")
        add("\t\t\t);")
        add("\t\t\tsourceTree = \"<group>\";")
        add("\t\t};")
        for group in self.groups:
            add(group)
        add(f"\t\t{products_group} /* Products */ = {{")
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        add(f"\t\t\t\t{product_ref} /* {TARGET_NAME}.app */,")
        add("\t\t\t);")
        add("\t\t\tname = Products;")
        add("\t\t\tsourceTree = \"<group>\";")
        add("\t\t};")
        add("/* End PBXGroup section */")
        add("")

        add("/* Begin PBXNativeTarget section */")
        add(f"\t\t{target} /* {TARGET_NAME} */ = {{")
        add("\t\t\tisa = PBXNativeTarget;")
        add(f"\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */;")
        add("\t\t\tbuildPhases = (")
        add(f"\t\t\t\t{source_phase} /* Sources */,")
        add(f"\t\t\t\t{framework_phase} /* Frameworks */,")
        add(f"\t\t\t\t{resources_phase} /* Resources */,")
        add("\t\t\t);")
        add("\t\t\tbuildRules = (")
        add("\t\t\t);")
        add("\t\t\tdependencies = (")
        add("\t\t\t);")
        add(f"\t\t\tname = {TARGET_NAME};")
        add("\t\t\tpackageProductDependencies = (")
        add(f"\t\t\t\t{package_product} /* AntennaPodCore */,")
        add("\t\t\t);")
        add(f"\t\t\tproductName = {TARGET_NAME};")
        add(f"\t\t\tproductReference = {product_ref} /* {TARGET_NAME}.app */;")
        add("\t\t\tproductType = \"com.apple.product-type.application\";")
        add("\t\t};")
        add("/* End PBXNativeTarget section */")
        add("")

        add("/* Begin PBXProject section */")
        add(f"\t\t{project} /* Project object */ = {{")
        add("\t\t\tisa = PBXProject;")
        add("\t\t\tattributes = {")
        add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
        add("\t\t\t\tLastSwiftUpdateCheck = 1500;")
        add("\t\t\t\tLastUpgradeCheck = 1500;")
        add("\t\t\t\tTargetAttributes = {")
        add(f"\t\t\t\t\t{target} = {{")
        add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
        add("\t\t\t\t\t};")
        add("\t\t\t\t};")
        add("\t\t\t};")
        add(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
        add("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
        add("\t\t\tdevelopmentRegion = en;")
        add("\t\t\thasScannedForEncodings = 0;")
        add("\t\t\tknownRegions = (")
        add("\t\t\t\ten,")
        add("\t\t\t\tBase,")
        add("\t\t\t);")
        add(f"\t\t\tmainGroup = {main_group};")
        add("\t\t\tpackageReferences = (")
        add(f"\t\t\t\t{package_ref} /* XCLocalSwiftPackageReference {quote(PACKAGE_RELATIVE)} */,")
        add("\t\t\t);")
        add(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
        add("\t\t\tprojectDirPath = \"\";")
        add("\t\t\tprojectRoot = \"\";")
        add("\t\t\ttargets = (")
        add(f"\t\t\t\t{target} /* {TARGET_NAME} */,")
        add("\t\t\t);")
        add("\t\t};")
        add("/* End PBXProject section */")
        add("")

        add("/* Begin PBXResourcesBuildPhase section */")
        add(f"\t\t{resources_phase} /* Resources */ = {{")
        add("\t\t\tisa = PBXResourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for build_uuid, name in self.resources:
            add(f"\t\t\t\t{build_uuid} /* {path_comment(name)} in Resources */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
        add("/* End PBXResourcesBuildPhase section */")
        add("")

        add("/* Begin PBXSourcesBuildPhase section */")
        add(f"\t\t{source_phase} /* Sources */ = {{")
        add("\t\t\tisa = PBXSourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for build_uuid, name in self.sources:
            add(f"\t\t\t\t{build_uuid} /* {path_comment(name)} in Sources */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
        add("/* End PBXSourcesBuildPhase section */")
        add("")

        add("/* Begin XCBuildConfiguration section */")
        add(self.render_config(project_debug, "Debug", target=False, debug=True))
        add(self.render_config(project_release, "Release", target=False, debug=False))
        add(self.render_config(target_debug, "Debug", target=True, debug=True))
        add(self.render_config(target_release, "Release", target=True, debug=False))
        add("/* End XCBuildConfiguration section */")
        add("")

        add("/* Begin XCConfigurationList section */")
        add(self.render_config_list(project_config_list,
                                    f'Build configuration list for PBXProject "{PROJECT_NAME}"',
                                    project_debug, project_release))
        add(self.render_config_list(target_config_list,
                                    f'Build configuration list for PBXNativeTarget "{TARGET_NAME}"',
                                    target_debug, target_release))
        add("/* End XCConfigurationList section */")
        add("")

        add("/* Begin XCLocalSwiftPackageReference section */")
        add(f"\t\t{package_ref} /* XCLocalSwiftPackageReference {quote(PACKAGE_RELATIVE)} */ = {{")
        add("\t\t\tisa = XCLocalSwiftPackageReference;")
        add(f"\t\t\trelativePath = {quote(PACKAGE_RELATIVE)};")
        add("\t\t};")
        add("/* End XCLocalSwiftPackageReference section */")
        add("")

        add("/* Begin XCSwiftPackageProductDependency section */")
        add(f"\t\t{package_product} /* AntennaPodCore */ = {{")
        add("\t\t\tisa = XCSwiftPackageProductDependency;")
        add("\t\t\tproductName = AntennaPodCore;")
        add("\t\t};")
        add("/* End XCSwiftPackageProductDependency section */")
        add("\t};")
        add(f"\trootObject = {project} /* Project object */;")
        add("}")
        return "\n".join(lines) + "\n"

    # -- tree rendering -------------------------------------------------

    def render_group(self, name: str, path: Path, base: Path, top_level: bool = False) -> str:
        group_uuid = uid("group", str(path))
        children: list[tuple[str, str]] = []

        for entry in sorted(os.listdir(path), key=str.lower):
            if entry.startswith("."):
                continue
            full = path / entry
            if full.is_dir():
                if entry.endswith(".xcassets"):
                    ref_uuid = self.add_file(entry, full.relative_to(base), "folder.assetcatalog")
                    children.append((ref_uuid, entry))
                    build_uuid = uid("buildfile", str(full))
                    self.build_files.append((build_uuid, ref_uuid, entry, "Resources"))
                    self.resources.append((build_uuid, entry))
                elif entry.endswith(".xcodeproj") or entry.endswith(".xcworkspace"):
                    continue
                else:
                    children.append((uid("group", str(full)), entry))
                    self.groups.append(self.render_group(entry, full, base))
            elif entry.endswith(".swift"):
                ref_uuid = self.add_file(entry, full.relative_to(base), "sourcecode.swift")
                children.append((ref_uuid, entry))
                build_uuid = uid("buildfile", str(full))
                self.build_files.append((build_uuid, ref_uuid, entry, "Sources"))
                self.sources.append((build_uuid, entry))
            elif entry.endswith(".plist") or entry.endswith(".json") or entry.endswith(".strings"):
                ref_uuid = self.add_file(entry, full.relative_to(base), "text.plist.xml")
                children.append((ref_uuid, entry))

        lines = [f"\t\t{group_uuid} /* {path_comment(name)} */ = {{"]
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for child_uuid, child_name in children:
            lines.append(f"\t\t\t\t{child_uuid} /* {path_comment(child_name)} */,")
        lines.append("\t\t\t);")
        if top_level:
            lines.append(f"\t\t\tpath = {quote(name)};")
        else:
            lines.append(f"\t\t\tpath = {quote(name)};")
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
        return "\n".join(lines)

    def add_file(self, name: str, relative: Path, file_type: str) -> str:
        ref_uuid = uid("fileref", str(APP_DIR / relative))
        self.file_refs.append((ref_uuid, name, relative.name, file_type))
        return ref_uuid

    # -- build configurations -------------------------------------------

    def render_config(self, config_uuid: str, name: str, target: bool, debug: bool) -> str:
        lines = [f"\t\t{config_uuid} /* {name} */ = {{"]
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")

        if target:
            settings = [
                ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
                ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
                ("CODE_SIGN_STYLE", "Automatic"),
                ("CURRENT_PROJECT_VERSION", "1"),
                ("ENABLE_PREVIEWS", "YES"),
                ("GENERATE_INFOPLIST_FILE", "NO"),
                ("INFOPLIST_FILE", '"AntennaPod/Info.plist"'),
                ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
                ("LD_RUNPATH_SEARCH_PATHS", '("$(inherited)", "@executable_path/Frameworks")'),
                ("MARKETING_VERSION", "1.0"),
                ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
                ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
                ("SWIFT_EMIT_LOC_STRINGS", "YES"),
                ("SWIFT_VERSION", SWIFT_VERSION),
                ("TARGETED_DEVICE_FAMILY", '"1,2"'),
            ]
            for key, value in settings:
                lines.append(f"\t\t\t\t{key} = {value};")
        else:
            settings = [
                ("ALWAYS_SEARCH_USER_PATHS", "NO"),
                ("CLANG_ANALYZER_NONNULL", "YES"),
                ("CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION", "YES_AGGRESSIVE"),
                ("CLANG_CXX_LANGUAGE_STANDARD", '"gnu++20"'),
                ("CLANG_ENABLE_MODULES", "YES"),
                ("CLANG_ENABLE_OBJC_ARC", "YES"),
                ("CLANG_ENABLE_OBJC_WEAK", "YES"),
                ("CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING", "YES"),
                ("CLANG_WARN_BOOL_CONVERSION", "YES"),
                ("CLANG_WARN_COMMA", "YES"),
                ("CLANG_WARN_CONSTANT_CONVERSION", "YES"),
                ("CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS", "YES"),
                ("CLANG_WARN_DIRECT_OBJC_ISA_USAGE", "YES_ERROR"),
                ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
                ("CLANG_WARN_EMPTY_BODY", "YES"),
                ("CLANG_WARN_ENUM_CONVERSION", "YES"),
                ("CLANG_WARN_INFINITE_RECURSION", "YES"),
                ("CLANG_WARN_INT_CONVERSION", "YES"),
                ("CLANG_WARN_NON_LITERAL_NULL_CONVERSION", "YES"),
                ("CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF", "YES"),
                ("CLANG_WARN_OBJC_LITERAL_CONVERSION", "YES"),
                ("CLANG_WARN_OBJC_ROOT_CLASS", "YES_ERROR"),
                ("CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER", "YES"),
                ("CLANG_WARN_RANGE_LOOP_ANALYSIS", "YES"),
                ("CLANG_WARN_STRICT_PROTOTYPES", "YES"),
                ("CLANG_WARN_SUSPICIOUS_MOVE", "YES"),
                ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
                ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
                ("CLANG_WARN__DUPLICATE_METHOD_MATCH", "YES"),
                ("COPY_PHASE_STRIP", "NO" if debug else "YES"),
                ("DEBUG_INFORMATION_FORMAT", "dwarf" if debug else "dwarf-with-dsym"),
                ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
                ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
                ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
                ("GCC_DYNAMIC_NO_PIC", "NO"),
                ("GCC_NO_COMMON_BLOCKS", "YES"),
                ("GCC_OPTIMIZATION_LEVEL", "0" if debug else "s"),
                ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
                ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE" if debug else "NO"),
                ("MTL_FAST_MATH", "YES"),
                ("SDKROOT", "iphoneos"),
                ("SWIFT_VERSION", SWIFT_VERSION),
            ]
            if debug:
                settings.extend([
                    ("ENABLE_TESTABILITY", "YES"),
                    ("GCC_PREPROCESSOR_DEFINITIONS", '("DEBUG=1", "$(inherited)")'),
                    ("ONLY_ACTIVE_ARCH", "YES"),
                    ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
                    ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
                ])
            else:
                settings.extend([
                    ("ENABLE_NS_ASSERTIONS", "NO"),
                    ("GCC_PREPROCESSOR_DEFINITIONS", '("$(inherited)")'),
                    ("SWIFT_COMPILATION_MODE", "wholemodule"),
                    ("VALIDATE_PRODUCT", "YES"),
                ])
            for key, value in settings:
                lines.append(f"\t\t\t\t{key} = {value};")

        lines.append("\t\t\t};")
        lines.append(f"\t\t\tname = {name};")
        lines.append("\t\t};")
        return "\n".join(lines)

    def render_config_list(self, config_list_uuid: str, comment: str,
                           debug_uuid: str, release_uuid: str) -> str:
        return "\n".join([
            f"\t\t{config_list_uuid} /* {comment} */ = {{",
            "\t\t\tisa = XCConfigurationList;",
            "\t\t\tbuildConfigurations = (",
            f"\t\t\t\t{debug_uuid} /* Debug */,",
            f"\t\t\t\t{release_uuid} /* Release */,",
            "\t\t\t);",
            "\t\t\tdefaultConfigurationIsVisible = 0;",
            "\t\t\tdefaultConfigurationName = Release;",
            "\t\t};",
        ])


SCHEME_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "AntennaPod.app"
               BlueprintName = "AntennaPod"
               ReferencedContainer = "container:AntennaPod.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "AntennaPod.app"
            BlueprintName = "AntennaPod"
            ReferencedContainer = "container:AntennaPod.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "AntennaPod.app"
            BlueprintName = "AntennaPod"
            ReferencedContainer = "container:AntennaPod.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def main() -> int:
    if not APP_DIR.is_dir():
        print(f"error: {APP_DIR} not found", file=sys.stderr)
        return 1

    generator = Generator()
    contents = generator.build()

    project_dir = ROOT / f"{PROJECT_NAME}.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    (project_dir / "project.pbxproj").write_text(contents, encoding="utf-8")

    scheme_dir = project_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    target_uuid = uid("target", TARGET_NAME)
    (scheme_dir / f"{TARGET_NAME}.xcscheme").write_text(
        SCHEME_TEMPLATE.format(target=target_uuid), encoding="utf-8"
    )

    swift_files = len([name for _, name in generator.sources])
    print(f"wrote {project_dir}/project.pbxproj")
    print(f"wrote {scheme_dir}/{TARGET_NAME}.xcscheme")
    print(f"{swift_files} Swift files, {len(generator.resources)} resources")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
