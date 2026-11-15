"""Compile and test the iOS app's non-UI code with the Swift toolchain on Windows/Linux.

SwiftUI, UIKit, StoreKit and AVFoundation only exist on Apple platforms, so this builds everything else —
models, engines (meal planner, adaptive model, cardio, quotes, day plan), AppEnvironment (against small
stand-ins in Scripts/ios-check/AppleShims.swift) — and runs the XCTest suites that don't need UI.

Usage:  python Scripts/check_ios_on_windows.py          (needs `swift` on PATH)
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRS = [
    "MyCoach/Models",
    "MyCoach/Core/Configuration",
    "MyCoach/Core/Utilities",
    "MyCoach/Services/AI",
    "MyCoach/Services/Adaptive",
    "MyCoach/Services/Coaching",
    "MyCoach/Services/FoodDatabase",
    "MyCoach/Services/Nutrition",
]
EXTRA_SOURCES = ["MyCoach/Services/Persistence/AppDataStore.swift"]
TESTS = [
    "AdaptiveModelTests", "AdaptiveModelFixture", "MealPlannerTests", "MealPlannerFixture", "TodayFeaturesTests",
    "NutritionEngineTests", "CoachingDecisionEngineTests", "MealPlanSolverTests", "BarcodeLookupTests",
    "WorkoutReviewTests",
]

PACKAGE = """// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "MyCoachIOSCheck",
    targets: [
        .target(name: "MyCoach", path: "Sources/MyCoach", swiftSettings: [.unsafeFlags(["-swift-version", "5"])]),
        .testTarget(name: "MyCoachTests", dependencies: ["MyCoach"], path: "Tests/MyCoachTests"),
    ]
)
"""


def main() -> int:
    if not shutil.which("swift"):
        print("swift not found on PATH")
        return 1
    work = Path(tempfile.mkdtemp(prefix="mycoach-ios-check-"))
    src = work / "Sources" / "MyCoach"
    tests = work / "Tests" / "MyCoachTests"
    src.mkdir(parents=True)
    tests.mkdir(parents=True)
    (work / "Package.swift").write_text(PACKAGE, encoding="utf-8")
    for d in SOURCE_DIRS:
        for f in (ROOT / d).glob("*.swift"):
            shutil.copy(f, src / f.name)
    for f in EXTRA_SOURCES:
        shutil.copy(ROOT / f, src)
    # AppEnvironment without the Apple-only imports, plus stand-ins for what it uses from them.
    env = (ROOT / "MyCoach/App/AppEnvironment.swift").read_text(encoding="utf-8").replace("\r\n", "\n")
    env = "\n".join(l for l in env.split("\n") if l.strip() not in ("import SwiftUI", "import UIKit"))
    (src / "AppEnvironment.swift").write_text(env, encoding="utf-8")
    shutil.copy(ROOT / "Scripts/ios-check/AppleShims.swift", src / "AppleShims.swift")
    for t in TESTS:
        shutil.copy(ROOT / "MyCoachTests" / f"{t}.swift", tests)
    print(f"Building in {work} ...")
    result = subprocess.run(["swift", "test"], cwd=work)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
