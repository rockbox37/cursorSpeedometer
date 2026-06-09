#!/usr/bin/env python3
"""Generate cursorSpeedometer.xcodeproj from repository source layout."""

from __future__ import annotations

import pathlib
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "cursorSpeedometer"
TEST_DIR = ROOT / "cursorSpeedometerTests"
PROJECT_DIR = ROOT / "cursorSpeedometer.xcodeproj"


FIXED_IDS = {
    "app-target": "A1B2C3D4E5F6478990ABCDE1",
    "test-target": "A1B2C3D4E5F6478990ABCDE2",
    "app-product": "A1B2C3D4E5F6478990ABCDE3",
    "test-product": "A1B2C3D4E5F6478990ABCDE4",
    "project": "A1B2C3D4E5F6478990ABCDE5",
}


def uid(name: str) -> str:
    if name in FIXED_IDS:
        return FIXED_IDS[name]
    return uuid.uuid5(uuid.NAMESPACE_DNS, f"cursorSpeedometer:{name}").hex[:24].upper()


def pbx_file_ref(path: pathlib.Path, name: str | None = None) -> str:
    return (
        f"\t\t{uid(str(path))} /* {name or path.name} */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = {file_type(path)}; "
        f"path = {path.name}; sourceTree = \"<group>\"; }};"
    )


def file_type(path: pathlib.Path) -> str:
    if path.suffix == ".swift":
        return "sourcecode.swift"
    if path.suffix == ".storyboard":
        return "file.storyboard"
    if path.suffix == ".json" and "xcassets" in str(path):
        return "text.json"
    if path.name.endswith(".xcassets"):
        return "folder.assetcatalog"
    return "text"


def collect_swift_files(directory: pathlib.Path) -> list[pathlib.Path]:
    return sorted(directory.rglob("*.swift"))


def main() -> None:
    app_swift = collect_swift_files(APP_DIR)
    test_swift = collect_swift_files(TEST_DIR)
    assets = APP_DIR / "Resources" / "Assets.xcassets"
    extra_resources = [APP_DIR / "Resources" / "LaunchScreen.storyboard"]

    def rel(path: pathlib.Path) -> pathlib.Path:
        return path.relative_to(ROOT)

    file_refs = []
    for path in app_swift + test_swift:
        file_refs.append(pbx_file_ref(rel(path), path.name))

    assets_rel = assets.relative_to(APP_DIR)
    assets_uid = uid(str(assets.relative_to(ROOT)))
    file_refs.append(
        f"\t\t{assets_uid} /* Assets.xcassets */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
        f"path = {assets_rel}; sourceTree = \"<group>\"; }};"
    )

    app_build_files = [
        f"\t\t{uid('build-' + str(rel(p)))} /* {p.name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {uid(str(rel(p)))} /* {p.name} */; }};"
        for p in app_swift
    ]
    app_build_files.append(
        f"\t\t{uid('build-assets')} /* Assets.xcassets in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {assets_uid} /* Assets.xcassets */; }};"
    )
    extra_resource_lines = []
    for resource in extra_resources:
        resource_rel = resource.relative_to(ROOT)
        resource_uid = uid(str(resource_rel))
        resource_path = resource.relative_to(APP_DIR)
        file_refs.append(
            f"\t\t{resource_uid} /* {resource.name} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = file.storyboard; "
            f"path = {resource_path}; sourceTree = \"<group>\"; }};"
        )
        app_build_files.append(
            f"\t\t{uid('build-' + str(resource_rel))} /* {resource.name} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {resource_uid} /* {resource.name} */; }};"
        )
        extra_resource_lines.append(
            f"\t\t\t\t{uid('build-' + str(resource_rel))} /* {resource.name} in Resources */"
        )
    extra_resource_joined = ",\n".join(extra_resource_lines)
    extra_resource_file_ref_uid = uid(str(extra_resources[0].relative_to(ROOT)))

    test_build_files = [
        f"\t\t{uid('testbuild-' + str(rel(p)))} /* {p.name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {uid(str(rel(p)))} /* {p.name} */; }};"
        for p in test_swift
    ]

    def group_children(paths: list[pathlib.Path]) -> str:
        return ",\n".join(f"\t\t\t\t{uid(str(rel(p)))} /* {p.name} */" for p in paths)

    groups = []
    for folder in sorted({p.parent for p in app_swift}):
        folder_rel = folder.relative_to(APP_DIR)
        children = [p for p in app_swift if p.parent == folder]
        groups.append(
            f"\t\t{uid('group-' + str(folder_rel))} /* {folder_rel.name} */ = {{\n"
            f"\t\t\tisa = PBXGroup;\n"
            f"\t\t\tchildren = (\n{group_children(children)}\n\t\t\t);\n"
            f"\t\t\tpath = {folder_rel};\n"
            f"\t\t\tsourceTree = \"<group>\";\n"
            f"\t\t}};"
        )

    top_app_children = ",\n".join(
        f"\t\t\t\t{uid('group-' + str(d.relative_to(APP_DIR)))} /* {d.relative_to(APP_DIR).name} */"
        for d in sorted({p.parent for p in app_swift})
    )

    app_source_lines = ",\n".join(
        f"\t\t\t\t{uid('build-' + str(rel(p)))} /* {p.name} in Sources */" for p in app_swift
    )
    test_source_lines = ",\n".join(
        f"\t\t\t\t{uid('testbuild-' + str(rel(p)))} /* {p.name} in Sources */" for p in test_swift
    )

    pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(app_build_files)}
{chr(10).join(test_build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t{uid('app-product')} /* cursorSpeedometer.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = cursorSpeedometer.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{uid('test-product')} /* cursorSpeedometerTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = cursorSpeedometerTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{uid('app-frameworks')} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{uid('test-frameworks')} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{uid('root-group')} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uid('app-group')} /* cursorSpeedometer */,
\t\t\t\t{uid('test-group')} /* cursorSpeedometerTests */,
\t\t\t\t{uid('products-group')} /* Products */,
\t\t\t);
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{uid('products-group')} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uid('app-product')} /* cursorSpeedometer.app */,
\t\t\t\t{uid('test-product')} /* cursorSpeedometerTests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{uid('app-group')} /* cursorSpeedometer */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{top_app_children},
\t\t\t\t{assets_uid} /* Assets.xcassets */,
\t\t\t\t{extra_resource_file_ref_uid} /* LaunchScreen.storyboard */,
\t\t\t);
\t\t\tpath = cursorSpeedometer;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{uid('test-group')} /* cursorSpeedometerTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children(test_swift)}
\t\t\t);
\t\t\tpath = cursorSpeedometerTests;
\t\t\tsourceTree = \"<group>\";
\t\t}};
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{uid('app-target')} /* cursorSpeedometer */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uid('app-config-list')} /* Build configuration list for PBXNativeTarget \"cursorSpeedometer\" */;
\t\t\tbuildPhases = (
\t\t\t\t{uid('app-sources')} /* Sources */,
\t\t\t\t{uid('app-frameworks')} /* Frameworks */,
\t\t\t\t{uid('app-resources')} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = cursorSpeedometer;
\t\t\tproductName = cursorSpeedometer;
\t\t\tproductReference = {uid('app-product')} /* cursorSpeedometer.app */;
\t\t\tproductType = \"com.apple.product-type.application\";
\t\t}};
\t\t{uid('test-target')} /* cursorSpeedometerTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uid('test-config-list')} /* Build configuration list for PBXNativeTarget \"cursorSpeedometerTests\" */;
\t\t\tbuildPhases = (
\t\t\t\t{uid('test-sources')} /* Sources */,
\t\t\t\t{uid('test-frameworks')} /* Frameworks */,
\t\t\t\t{uid('test-resources')} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{uid('test-dep')} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = cursorSpeedometerTests;
\t\t\tproductName = cursorSpeedometerTests;
\t\t\tproductReference = {uid('test-product')} /* cursorSpeedometerTests.xctest */;
\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{uid('project')} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{uid('app-target')} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t\t{uid('test-target')} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tTestTargetID = {uid('app-target')};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {uid('project-config-list')} /* Build configuration list for PBXProject \"cursorSpeedometer\" */;
\t\t\tcompatibilityVersion = \"Xcode 14.0\";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {uid('root-group')};
\t\t\tproductRefGroup = {uid('products-group')} /* Products */;
\t\t\tprojectDirPath = \"\";
\t\t\tprojectRoot = \"\";
\t\t\ttargets = (
\t\t\t\t{uid('app-target')} /* cursorSpeedometer */,
\t\t\t\t{uid('test-target')} /* cursorSpeedometerTests */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{uid('app-resources')} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{uid('build-assets')} /* Assets.xcassets in Resources */,
{extra_resource_joined}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{uid('test-resources')} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{uid('app-sources')} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{app_source_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{uid('test-sources')} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{test_source_lines}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{uid('test-dep')} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {uid('app-target')} /* cursorSpeedometer */;
\t\t\ttargetProxy = {uid('test-proxy')} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
\t\t{uid('test-proxy')} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {uid('project')} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {uid('app-target')};
\t\t\tremoteInfo = cursorSpeedometer;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin XCBuildConfiguration section */
\t\t{uid('debug-project')} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uid('release-project')} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{uid('debug-app')} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = \"cursorSpeedometer needs your location to show GPS speed and trip distance while riding.\";
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.cursorspeedometer.app;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uid('release-app')} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = \"cursorSpeedometer needs your location to show GPS speed and trip distance while riding.\";
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t\"$(inherited)\",
\t\t\t\t\t\"@executable_path/Frameworks\",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.cursorspeedometer.app;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{uid('debug-test')} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.cursorspeedometer.appTests;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/cursorSpeedometer.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/cursorSpeedometer\";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uid('release-test')} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.cursorspeedometer.appTests;
\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/cursorSpeedometer.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/cursorSpeedometer\";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{uid('project-config-list')} /* Build configuration list for PBXProject \"cursorSpeedometer\" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uid('debug-project')} /* Debug */,
\t\t\t\t{uid('release-project')} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{uid('app-config-list')} /* Build configuration list for PBXNativeTarget \"cursorSpeedometer\" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uid('debug-app')} /* Debug */,
\t\t\t\t{uid('release-app')} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{uid('test-config-list')} /* Build configuration list for PBXNativeTarget \"cursorSpeedometerTests\" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uid('debug-test')} /* Debug */,
\t\t\t\t{uid('release-test')} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {uid('project')} /* Project object */;
}}
"""

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('app-target')}" BuildableName="cursorSpeedometer.app" BlueprintName="cursorSpeedometer" ReferencedContainer="container:cursorSpeedometer.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO" parallelizable="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('test-target')}" BuildableName="cursorSpeedometerTests.xctest" BlueprintName="cursorSpeedometerTests" ReferencedContainer="container:cursorSpeedometer.xcodeproj"/>
      </TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('app-target')}" BuildableName="cursorSpeedometer.app" BlueprintName="cursorSpeedometer" ReferencedContainer="container:cursorSpeedometer.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('app-target')}" BuildableName="cursorSpeedometer.app" BlueprintName="cursorSpeedometer" ReferencedContainer="container:cursorSpeedometer.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
"""

    workspace_contents = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text(pbxproj)
    scheme_dir = PROJECT_DIR / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "cursorSpeedometer.xcscheme").write_text(scheme)
    workspace_dir = PROJECT_DIR / "project.xcworkspace"
    workspace_dir.mkdir(parents=True, exist_ok=True)
    (workspace_dir / "contents.xcworkspacedata").write_text(workspace_contents)
    print(f"Wrote {PROJECT_DIR / 'project.pbxproj'}")


if __name__ == "__main__":
    main()
