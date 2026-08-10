#!/usr/bin/env python3
"""Generate MyCoach.xcodeproj with stable UUIDs.

Walks MyCoach/, MyCoachTests/, and MyCoachUITests/ via os.walk and includes
every .swift file, plus Assets.xcassets, PrivacyInfo.xcprivacy, and
StoreKit/MyCoach.storekit. Also writes the shared MyCoach scheme with a
StoreKit configuration reference.

Usage:
  python3 Scripts/generate_xcode_project.py
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.company.mycoach"
IOS_DEPLOYMENT = "17.0"
SWIFT_VERSION = "5.0"
OBJECT_VERSION = 56


def uid(key: str) -> str:
    return hashlib.md5(f"MyCoach|{key}".encode()).hexdigest()[:24].upper()


def collect_swift(rel_dir: str) -> list[str]:
    base = ROOT / rel_dir
    files: list[str] = []
    for dirpath, _, filenames in os.walk(base):
        for name in sorted(filenames):
            if name.endswith(".swift"):
                full = Path(dirpath) / name
                files.append(str(full.relative_to(ROOT)).replace("\\", "/"))
    return sorted(files)


def emit_tree(root: str, files: list[str], extra_at: dict[str, list[tuple[str, str]]]) -> list[str]:
    all_dirs: set[str] = {root}
    for p in files:
        parts = p.split("/")
        for i in range(1, len(parts)):
            all_dirs.add("/".join(parts[:i]))
    for d in extra_at:
        parts = d.split("/")
        for i in range(1, len(parts) + 1):
            all_dirs.add("/".join(parts[:i]))

    children: dict[str, set[str]] = {d: set() for d in all_dirs}
    for p in files:
        parent = "/".join(p.split("/")[:-1])
        children.setdefault(parent, set()).add(f"F:{p}")
    for d in all_dirs:
        if d == root:
            continue
        parent = "/".join(d.split("/")[:-1])
        children.setdefault(parent, set()).add(f"D:{d}")
    for d, extras in extra_at.items():
        for path, _ in extras:
            children.setdefault(d, set()).add(f"F:{path}")

    blocks: list[str] = []
    for d in sorted(all_dirs):
        display = Path(d).name
        kids = sorted(children.get(d, set()), key=lambda x: x.split(":", 1)[1])
        lines = [
            f"\t\t{uid(f'group:{d}')} /* {display} */ = {{",
            "\t\t\tisa = PBXGroup;",
            "\t\t\tchildren = (",
        ]
        for kid in kids:
            kind, rest = kid.split(":", 1)
            if kind == "F":
                cid = uid(f"file:{rest}")
                cname = Path(rest).name
            else:
                cid = uid(f"group:{rest}")
                cname = Path(rest).name
            lines.append(f"\t\t\t\t{cid} /* {cname} */,")
        lines += [
            "\t\t\t);",
            f"\t\t\tpath = {display};",
            '\t\t\tsourceTree = "<group>";',
            "\t\t};",
        ]
        blocks.append("\n".join(lines))
    return blocks


def sources_phase(phase_id: str, files: list[str]) -> str:
    lines = [
        f"\t\t{phase_id} /* Sources */ = {{",
        "\t\t\tisa = PBXSourcesBuildPhase;",
        "\t\t\tbuildActionMask = 2147483647;",
        "\t\t\tfiles = (",
    ]
    for p in files:
        lines.append(f"\t\t\t\t{uid(f'build:{p}')} /* {Path(p).name} in Sources */,")
    lines += ["\t\t\t);", "\t\t\trunOnlyForDeploymentPostprocessing = 0;", "\t\t};"]
    return "\n".join(lines)


def empty_frameworks(phase_id: str) -> str:
    return "\n".join(
        [
            f"\t\t{phase_id} /* Frameworks */ = {{",
            "\t\t\tisa = PBXFrameworksBuildPhase;",
            "\t\t\tbuildActionMask = 2147483647;",
            "\t\t\tfiles = (",
            "\t\t\t);",
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
            "\t\t};",
        ]
    )


def project_cfg(cfg_id: str, name: str) -> str:
    debug = name == "Debug"
    return f"""\t\t{cfg_id} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = {"dwarf" if debug else "dwarf-with-dsym"};
\t\t\t\tENABLE_TESTABILITY = {"YES" if debug else "NO"};
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {IOS_DEPLOYMENT};
\t\t\t\tONLY_ACTIVE_ARCH = {"YES" if debug else "NO"};
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = {"DEBUG" if debug else '""'};
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = {'"-Onone"' if debug else '"-O"'};
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t}};
\t\t\tname = {name};
\t\t}};"""


def app_cfg(cfg_id: str, name: str) -> str:
    return f"""\t\t{cfg_id} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MyCoach/Resources/MyCoach.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "My Coach";
\t\t\t\tINFOPLIST_KEY_CFBundleName = MyCoach;
\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Camera access allows you to take weekly progress photos.";
\t\t\t\tINFOPLIST_KEY_NSHealthShareUsageDescription = "Step data is used optionally to compare against your step target. Manual entry always works.";
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = {name};
\t\t}};"""


def unit_cfg(cfg_id: str, name: str) -> str:
    return f"""\t\t{cfg_id} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {IOS_DEPLOYMENT};
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/MyCoach.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MyCoach";
\t\t\t}};
\t\t\tname = {name};
\t\t}};"""


def uitest_cfg(cfg_id: str, name: str) -> str:
    return f"""\t\t{cfg_id} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {IOS_DEPLOYMENT};
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.uitests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_TARGET_NAME = MyCoach;
\t\t\t}};
\t\t\tname = {name};
\t\t}};"""


def main() -> None:
    app_files = collect_swift("MyCoach")
    unit_files = collect_swift("MyCoachTests")
    ui_files = collect_swift("MyCoachUITests")

    ids = {
        "project": uid("project"),
        "root_group": uid("group:"),
        "products_group": uid("group:Products"),
        "frameworks_group": uid("group:Frameworks"),
        "app_product": uid("product:MyCoach.app"),
        "tests_product": uid("product:MyCoachTests.xctest"),
        "uitests_product": uid("product:MyCoachUITests.xctest"),
        "app_target": uid("target:MyCoach"),
        "tests_target": uid("target:MyCoachTests"),
        "uitests_target": uid("target:MyCoachUITests"),
        "app_sources": uid("phase:sources:MyCoach"),
        "app_resources": uid("phase:resources:MyCoach"),
        "app_frameworks": uid("phase:frameworks:MyCoach"),
        "tests_sources": uid("phase:sources:MyCoachTests"),
        "tests_frameworks": uid("phase:frameworks:MyCoachTests"),
        "uitests_sources": uid("phase:sources:MyCoachUITests"),
        "uitests_frameworks": uid("phase:frameworks:MyCoachUITests"),
        "app_proj_cfg": uid("cfg:project:debug"),
        "app_proj_cfg_r": uid("cfg:project:release"),
        "app_tgt_cfg": uid("cfg:target:MyCoach:debug"),
        "app_tgt_cfg_r": uid("cfg:target:MyCoach:release"),
        "tests_tgt_cfg": uid("cfg:target:MyCoachTests:debug"),
        "tests_tgt_cfg_r": uid("cfg:target:MyCoachTests:release"),
        "uitests_tgt_cfg": uid("cfg:target:MyCoachUITests:debug"),
        "uitests_tgt_cfg_r": uid("cfg:target:MyCoachUITests:release"),
        "proj_config_list": uid("list:project"),
        "app_config_list": uid("list:MyCoach"),
        "tests_config_list": uid("list:MyCoachTests"),
        "uitests_config_list": uid("list:MyCoachUITests"),
        "healthkit": uid("framework:HealthKit"),
        "storekit": uid("framework:StoreKit"),
        "storekit_build": uid("buildfile:framework:StoreKit"),
        "healthkit_build": uid("buildfile:framework:HealthKit"),
    }

    file_entries: list[str] = []
    build_files: list[str] = []

    for path in app_files + unit_files + ui_files:
        name = Path(path).name
        fid = uid(f"file:{path}")
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f'path = {name}; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{uid(f'build:{path}')} /* {name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )

    res_specs = [
        ("MyCoach/Resources/Assets.xcassets", "folder.assetcatalog", "Assets.xcassets"),
        ("MyCoach/Resources/PrivacyInfo.xcprivacy", "text.xml", "PrivacyInfo.xcprivacy"),
        ("MyCoach/Resources/StoreKit/MyCoach.storekit", "text", "MyCoach.storekit"),
    ]
    for path, lkt, name in res_specs:
        fid = uid(f"file:{path}")
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {lkt}; "
            f'path = {name}; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{uid(f'build:{path}')} /* {name} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )

    file_entries += [
        f"\t\t{ids['app_product']} /* MyCoach.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MyCoach.app; sourceTree = BUILT_PRODUCTS_DIR; }};",
        f"\t\t{ids['tests_product']} /* MyCoachTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MyCoachTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};",
        f"\t\t{ids['uitests_product']} /* MyCoachUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MyCoachUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};",
        f"\t\t{ids['healthkit']} /* HealthKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = HealthKit.framework; path = System/Library/Frameworks/HealthKit.framework; sourceTree = SDKROOT; }};",
        f"\t\t{ids['storekit']} /* StoreKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = StoreKit.framework; path = System/Library/Frameworks/StoreKit.framework; sourceTree = SDKROOT; }};",
    ]
    build_files += [
        f"\t\t{ids['healthkit_build']} /* HealthKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['healthkit']} /* HealthKit.framework */; }};",
        f"\t\t{ids['storekit_build']} /* StoreKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['storekit']} /* StoreKit.framework */; }};",
    ]

    extra_resources = {
        "MyCoach/Resources": [
            ("MyCoach/Resources/Assets.xcassets", "Assets.xcassets"),
            ("MyCoach/Resources/PrivacyInfo.xcprivacy", "PrivacyInfo.xcprivacy"),
        ],
        "MyCoach/Resources/StoreKit": [
            ("MyCoach/Resources/StoreKit/MyCoach.storekit", "MyCoach.storekit"),
        ],
    }

    group_blocks = []
    group_blocks.extend(emit_tree("MyCoach", app_files, extra_resources))
    group_blocks.extend(emit_tree("MyCoachTests", unit_files, {}))
    group_blocks.extend(emit_tree("MyCoachUITests", ui_files, {}))
    group_blocks.append(
        f"""\t\t{ids['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids['app_product']} /* MyCoach.app */,
\t\t\t\t{ids['tests_product']} /* MyCoachTests.xctest */,
\t\t\t\t{ids['uitests_product']} /* MyCoachUITests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    group_blocks.append(
        f"""\t\t{ids['frameworks_group']} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ids['healthkit']} /* HealthKit.framework */,
\t\t\t\t{ids['storekit']} /* StoreKit.framework */,
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    group_blocks.append(
        f"""\t\t{ids['root_group']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uid('group:MyCoach')} /* MyCoach */,
\t\t\t\t{uid('group:MyCoachTests')} /* MyCoachTests */,
\t\t\t\t{uid('group:MyCoachUITests')} /* MyCoachUITests */,
\t\t\t\t{ids['frameworks_group']} /* Frameworks */,
\t\t\t\t{ids['products_group']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )

    resources_phase = "\n".join(
        [
            f"\t\t{ids['app_resources']} /* Resources */ = {{",
            "\t\t\tisa = PBXResourcesBuildPhase;",
            "\t\t\tbuildActionMask = 2147483647;",
            "\t\t\tfiles = (",
            *[
                f"\t\t\t\t{uid(f'build:{path}')} /* {name} in Resources */,"
                for path, _, name in res_specs
            ],
            "\t\t\t);",
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
            "\t\t};",
        ]
    )

    frameworks_app = f"""\t\t{ids['app_frameworks']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{ids['healthkit_build']} /* HealthKit.framework in Frameworks */,
\t\t\t\t{ids['storekit_build']} /* StoreKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

    app_target = f"""\t\t{ids['app_target']} /* MyCoach */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids['app_config_list']} /* Build configuration list for PBXNativeTarget "MyCoach" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids['app_sources']} /* Sources */,
\t\t\t\t{ids['app_frameworks']} /* Frameworks */,
\t\t\t\t{ids['app_resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MyCoach;
\t\t\tproductName = MyCoach;
\t\t\tproductReference = {ids['app_product']} /* MyCoach.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};"""

    tests_target = f"""\t\t{ids['tests_target']} /* MyCoachTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids['tests_config_list']} /* Build configuration list for PBXNativeTarget "MyCoachTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids['tests_sources']} /* Sources */,
\t\t\t\t{ids['tests_frameworks']} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{uid('dep:MyCoachTests')} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = MyCoachTests;
\t\t\tproductName = MyCoachTests;
\t\t\tproductReference = {ids['tests_product']} /* MyCoachTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};"""

    uitests_target = f"""\t\t{ids['uitests_target']} /* MyCoachUITests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ids['uitests_config_list']} /* Build configuration list for PBXNativeTarget "MyCoachUITests" */;
\t\t\tbuildPhases = (
\t\t\t\t{ids['uitests_sources']} /* Sources */,
\t\t\t\t{ids['uitests_frameworks']} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{uid('dep:MyCoachUITests')} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = MyCoachUITests;
\t\t\tproductName = MyCoachUITests;
\t\t\tproductReference = {ids['uitests_product']} /* MyCoachUITests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.ui-testing";
\t\t}};"""

    container_proxy_tests = f"""\t\t{uid('proxy:MyCoachTests')} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids['project']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['app_target']};
\t\t\tremoteInfo = MyCoach;
\t\t}};"""

    container_proxy_uitests = f"""\t\t{uid('proxy:MyCoachUITests')} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ids['project']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {ids['app_target']};
\t\t\tremoteInfo = MyCoach;
\t\t}};"""

    dep_tests = f"""\t\t{uid('dep:MyCoachTests')} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['app_target']} /* MyCoach */;
\t\t\ttargetProxy = {uid('proxy:MyCoachTests')} /* PBXContainerItemProxy */;
\t\t}};"""

    dep_uitests = f"""\t\t{uid('dep:MyCoachUITests')} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {ids['app_target']} /* MyCoach */;
\t\t\ttargetProxy = {uid('proxy:MyCoachUITests')} /* PBXContainerItemProxy */;
\t\t}};"""

    project_object = f"""\t\t{ids['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ids['app_target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{ids['tests_target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t\tTestTargetID = {ids['app_target']};
\t\t\t\t\t}};
\t\t\t\t\t{ids['uitests_target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t\tTestTargetID = {ids['app_target']};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ids['proj_config_list']} /* Build configuration list for PBXProject "MyCoach" */;
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {ids['root_group']};
\t\t\tproductRefGroup = {ids['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ids['app_target']} /* MyCoach */,
\t\t\t\t{ids['tests_target']} /* MyCoachTests */,
\t\t\t\t{ids['uitests_target']} /* MyCoachUITests */,
\t\t\t);
\t\t}};"""

    config_lists = f"""\t\t{ids['proj_config_list']} /* Build configuration list for PBXProject "MyCoach" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids['app_proj_cfg']} /* Debug */,
\t\t\t\t{ids['app_proj_cfg_r']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ids['app_config_list']} /* Build configuration list for PBXNativeTarget "MyCoach" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids['app_tgt_cfg']} /* Debug */,
\t\t\t\t{ids['app_tgt_cfg_r']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ids['tests_config_list']} /* Build configuration list for PBXNativeTarget "MyCoachTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids['tests_tgt_cfg']} /* Debug */,
\t\t\t\t{ids['tests_tgt_cfg_r']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ids['uitests_config_list']} /* Build configuration list for PBXNativeTarget "MyCoachUITests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ids['uitests_tgt_cfg']} /* Debug */,
\t\t\t\t{ids['uitests_tgt_cfg_r']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""

    sections = [
        "\n".join(["/* Begin PBXBuildFile section */", *sorted(build_files), "/* End PBXBuildFile section */"]),
        "\n".join(
            [
                "/* Begin PBXContainerItemProxy section */",
                container_proxy_tests,
                container_proxy_uitests,
                "/* End PBXContainerItemProxy section */",
            ]
        ),
        "\n".join(
            ["/* Begin PBXFileReference section */", *sorted(file_entries), "/* End PBXFileReference section */"]
        ),
        "\n".join(
            [
                "/* Begin PBXFrameworksBuildPhase section */",
                frameworks_app,
                empty_frameworks(ids["tests_frameworks"]),
                empty_frameworks(ids["uitests_frameworks"]),
                "/* End PBXFrameworksBuildPhase section */",
            ]
        ),
        "\n".join(["/* Begin PBXGroup section */", *group_blocks, "/* End PBXGroup section */"]),
        "\n".join(
            ["/* Begin PBXNativeTarget section */", app_target, tests_target, uitests_target, "/* End PBXNativeTarget section */"]
        ),
        "\n".join(["/* Begin PBXProject section */", project_object, "/* End PBXProject section */"]),
        "\n".join(["/* Begin PBXResourcesBuildPhase section */", resources_phase, "/* End PBXResourcesBuildPhase section */"]),
        "\n".join(
            [
                "/* Begin PBXSourcesBuildPhase section */",
                sources_phase(ids["app_sources"], app_files),
                sources_phase(ids["tests_sources"], unit_files),
                sources_phase(ids["uitests_sources"], ui_files),
                "/* End PBXSourcesBuildPhase section */",
            ]
        ),
        "\n".join(["/* Begin PBXTargetDependency section */", dep_tests, dep_uitests, "/* End PBXTargetDependency section */"]),
        "\n".join(
            [
                "/* Begin XCBuildConfiguration section */",
                project_cfg(ids["app_proj_cfg"], "Debug"),
                project_cfg(ids["app_proj_cfg_r"], "Release"),
                app_cfg(ids["app_tgt_cfg"], "Debug"),
                app_cfg(ids["app_tgt_cfg_r"], "Release"),
                unit_cfg(ids["tests_tgt_cfg"], "Debug"),
                unit_cfg(ids["tests_tgt_cfg_r"], "Release"),
                uitest_cfg(ids["uitests_tgt_cfg"], "Debug"),
                uitest_cfg(ids["uitests_tgt_cfg_r"], "Release"),
                "/* End XCBuildConfiguration section */",
            ]
        ),
        "\n".join(["/* Begin XCConfigurationList section */", config_lists, "/* End XCConfigurationList section */"]),
    ]

    archive = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = {OBJECT_VERSION};
\tobjects = {{

{chr(10).join(sections)}

\t}};
\trootObject = {ids['project']} /* Project object */;
}}
"""

    out = ROOT / "MyCoach.xcodeproj" / "project.pbxproj"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(archive, encoding="utf-8")

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
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
               BlueprintIdentifier = "{ids['app_target']}"
               BuildableName = "MyCoach.app"
               BlueprintName = "MyCoach"
               ReferencedContainer = "container:MyCoach.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['tests_target']}"
               BuildableName = "MyCoachTests.xctest"
               BlueprintName = "MyCoachTests"
               ReferencedContainer = "container:MyCoach.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['uitests_target']}"
               BuildableName = "MyCoachUITests.xctest"
               BlueprintName = "MyCoachUITests"
               ReferencedContainer = "container:MyCoach.xcodeproj">
            </BuildableReference>
         </TestableReference>
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
            BlueprintIdentifier = "{ids['app_target']}"
            BuildableName = "MyCoach.app"
            BlueprintName = "MyCoach"
            ReferencedContainer = "container:MyCoach.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "MyCoach/Resources/StoreKit/MyCoach.storekit">
      </StoreKitConfigurationFileReference>
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
            BlueprintIdentifier = "{ids['app_target']}"
            BuildableName = "MyCoach.app"
            BlueprintName = "MyCoach"
            ReferencedContainer = "container:MyCoach.xcodeproj">
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
    scheme_path = ROOT / "MyCoach.xcodeproj" / "xcshareddata" / "xcschemes" / "MyCoach.xcscheme"
    scheme_path.parent.mkdir(parents=True, exist_ok=True)
    scheme_path.write_text(scheme, encoding="utf-8")

    ws = ROOT / "MyCoach.xcodeproj" / "project.xcworkspace" / "contents.xcworkspacedata"
    ws.parent.mkdir(parents=True, exist_ok=True)
    ws.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
        encoding="utf-8",
    )

    ref_names = []
    for line in archive.splitlines():
        if "lastKnownFileType = sourcecode.swift" in line and "path = " in line:
            ref_names.append(line.split("path = ", 1)[1].split(";", 1)[0].strip())
    disk_names = [Path(p).name for p in app_files + unit_files + ui_files]
    missing = sorted(set(disk_names) - set(ref_names))
    extra = sorted(set(ref_names) - set(disk_names))

    print(f"App Swift files:   {len(app_files)}")
    print(f"Unit test files:   {len(unit_files)}")
    print(f"UI test files:     {len(ui_files)}")
    print(f"Total Swift:       {len(disk_names)}")
    print(f"Referenced Swift:  {len(ref_names)}")
    print(f"Missing from pbx:  {missing}")
    print(f"Extra in pbx:      {extra}")
    print(f"Wrote {out}")
    print(f"Wrote {scheme_path}")


if __name__ == "__main__":
    main()
