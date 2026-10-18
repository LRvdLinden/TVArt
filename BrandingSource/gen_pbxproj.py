"""Generates a clean TVArt.xcodeproj/project.pbxproj (tvOS app target)."""
import sys, os, hashlib

ROOT = sys.argv[1]
BUILD = sys.argv[2] if len(sys.argv) > 2 else "2"
TEAM = "EU3UY476T6"

def oid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

swift = ["TVArtApp.swift", "Theme.swift", "SplashView.swift", "Models.swift", "MuseumService.swift",
         "ImagePipeline.swift", "HomeView.swift", "GalleryView.swift", "SlideshowView.swift", "SettingsView.swift"]
fonts = ["CormorantGaramond-SemiBold.ttf", "CormorantGaramond-Medium.ttf"]
for f in swift: assert os.path.exists(f"{ROOT}/TVArt/{f}"), f
for f in fonts: assert os.path.exists(f"{ROOT}/TVArt/Fonts/{f}"), f

L = []
def add(s): L.append(s)

files = {}
for f in swift:
    files[f] = (oid("ref" + f), f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }}")
for f in fonts:
    files[f] = (oid("ref" + f), f"{{isa = PBXFileReference; lastKnownFileType = file; path = {f}; sourceTree = \"<group>\"; }}")
files["Assets.xcassets"] = (oid("refassets"), "{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }")
files["Info.plist"] = (oid("refinfo"), "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }")
files["OFL.txt"] = (oid("refofl"), "{isa = PBXFileReference; lastKnownFileType = text; path = OFL.txt; sourceTree = \"<group>\"; }")
APP = oid("refapp")

build = {f: oid("build" + f) for f in swift + fonts + ["Assets.xcassets"]}

G_MAIN, G_APP, G_FONTS, G_PROD = oid("gmain"), oid("gapp"), oid("gfonts"), oid("gprod")
P_SRC, P_RES, P_FW = oid("psrc"), oid("pres"), oid("pfw")
TARGET, PROJECT = oid("target"), oid("project")
CL_PROJ, CL_TGT = oid("clproj"), oid("cltgt")
C_PD, C_PR, C_TD, C_TR = oid("cpd"), oid("cpr"), oid("ctd"), oid("ctr")

add("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n")
add("/* Begin PBXBuildFile section */")
for f, b in build.items():
    phase = "Sources" if f.endswith(".swift") else "Resources"
    add(f"\t\t{b} /* {f} in {phase} */ = {{isa = PBXBuildFile; fileRef = {files[f][0]} /* {f} */; }};")
add("/* End PBXBuildFile section */\n\n/* Begin PBXFileReference section */")
add(f"\t\t{APP} /* TVArt.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TVArt.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for f, (r, body) in files.items():
    add(f"\t\t{r} /* {f} */ = {body};")
add("/* End PBXFileReference section */\n\n/* Begin PBXFrameworksBuildPhase section */")
add(f"\t\t{P_FW} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
add("/* End PBXFrameworksBuildPhase section */\n\n/* Begin PBXGroup section */")
def group(gid, name, children, path=None):
    ch = "".join(f"\t\t\t\t{c},\n" for c in children)
    p = f"\t\t\tpath = {path};\n" if path else ""
    n = f"\t\t\tname = {name};\n" if name and not path else ""
    add(f"\t\t{gid} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{ch}\t\t\t);\n{n}{p}\t\t\tsourceTree = \"<group>\";\n\t\t}};")
group(G_MAIN, None, [G_APP, G_PROD])
group(G_APP, "TVArt", [files[f][0] for f in swift] + [G_FONTS, files["Assets.xcassets"][0], files["Info.plist"][0]], path="TVArt")
group(G_FONTS, "Fonts", [files[f][0] for f in fonts] + [files["OFL.txt"][0]], path="Fonts")
group(G_PROD, "Products", [APP])
add("/* End PBXGroup section */\n\n/* Begin PBXNativeTarget section */")
add(f"""\t\t{TARGET} /* TVArt */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CL_TGT};
\t\t\tbuildPhases = (
\t\t\t\t{P_SRC} /* Sources */,
\t\t\t\t{P_FW} /* Frameworks */,
\t\t\t\t{P_RES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = TVArt;
\t\t\tproductName = TVArt;
\t\t\tproductReference = {APP} /* TVArt.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};""")
add("/* End PBXNativeTarget section */\n\n/* Begin PBXProject section */")
add(f"""\t\t{PROJECT} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{TARGET} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {CL_PROJ};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = nl;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tnl,
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {G_MAIN};
\t\t\tproductRefGroup = {G_PROD} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{TARGET} /* TVArt */,
\t\t\t);
\t\t}};""")
add("/* End PBXProject section */\n\n/* Begin PBXResourcesBuildPhase section */")
res = "".join(f"\t\t\t\t{build[f]} /* {f} in Resources */,\n" for f in ["Assets.xcassets"] + fonts)
add(f"\t\t{P_RES} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{res}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
add("/* End PBXResourcesBuildPhase section */\n\n/* Begin PBXSourcesBuildPhase section */")
src = "".join(f"\t\t\t\t{build[f]} /* {f} in Sources */,\n" for f in swift)
add(f"\t\t{P_SRC} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{src}\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
add("/* End PBXSourcesBuildPhase section */\n\n/* Begin XCBuildConfiguration section */")

common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "SDKROOT": "appletvos", "TVOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0",
}
debug = dict(common, **{"DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_OPTIMIZATION_LEVEL": "0",
                        "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "\"DEBUG $(inherited)\"",
                        "SWIFT_OPTIMIZATION_LEVEL": "\"-Onone\""})
release = dict(common, **{"DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"", "ENABLE_NS_ASSERTIONS": "NO",
                          "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES"})
target = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "\"App Icon & Top Shelf Image\"",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": BUILD, "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES", "GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "TVArt/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t)",
    "MARKETING_VERSION": "1.0.0", "PRODUCT_BUNDLE_IDENTIFIER": "nl.lrvdlinden.tvart",
    "PRODUCT_NAME": "\"$(TARGET_NAME)\"", "SWIFT_EMIT_LOC_STRINGS": "YES", "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "3", "TVOS_DEPLOYMENT_TARGET": "17.0",
}
def cfg(cid, name, settings):
    body = "".join(f"\t\t\t\t{k} = {v};\n" for k, v in sorted(settings.items()))
    add(f"\t\t{cid} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{body}\t\t\t}};\n\t\t\tname = {name};\n\t\t}};")
cfg(C_PD, "Debug", debug); cfg(C_PR, "Release", release)
cfg(C_TD, "Debug", target); cfg(C_TR, "Release", target)
add("/* End XCBuildConfiguration section */\n\n/* Begin XCConfigurationList section */")
for cl, a, b in ((CL_PROJ, C_PD, C_PR), (CL_TGT, C_TD, C_TR)):
    add(f"\t\t{cl} = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{a} /* Debug */,\n\t\t\t\t{b} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
add("/* End XCConfigurationList section */\n\t};\n\trootObject = " + PROJECT + " /* Project object */;\n}\n")

os.makedirs(f"{ROOT}/TVArt.xcodeproj", exist_ok=True)
open(f"{ROOT}/TVArt.xcodeproj/project.pbxproj", "w").write("\n".join(L))

# Shared scheme so the project opens ready to run.
sd = f"{ROOT}/TVArt.xcodeproj/xcshareddata/xcschemes"
os.makedirs(sd, exist_ok=True)
ref = f'''<BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{TARGET}" BuildableName = "TVArt.app" BlueprintName = "TVArt" ReferencedContainer = "container:TVArt.xcodeproj"></BuildableReference>'''
open(f"{sd}/TVArt.xcscheme", "w").write(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            {ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES"></TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
''')
print("pbxproj written", len(L), "lines")
