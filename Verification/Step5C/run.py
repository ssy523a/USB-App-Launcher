#!/usr/bin/env python3
"""Run Swift Testing against authoritative sources, using only disposable configuration."""
from pathlib import Path
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parent.parent
with tempfile.TemporaryDirectory(prefix="USB-Step5C-") as temporary:
    package = Path(temporary)
    sources = package / "Sources/Core"
    tests = package / "Tests/CoreTests"
    sources.mkdir(parents=True)
    tests.mkdir(parents=True)
    for name in ["USBDevice", "RegisteredUSBDevice", "SelectedApplication",
                 "USBRegistrationStore", "AutomationLease", "ApplicationAutomationService"]:
        (sources / (name + ".swift")).symlink_to(root / "USB App Launcher" / (name + ".swift"))
    (sources / "ConfigurationWatcher.swift").symlink_to(root / "USBAppLauncherHelper/ConfigurationWatcher.swift")
    (tests / "ConfigurationTests.swift").symlink_to(here / "ConfigurationTests.swift")
    (package / "Package.swift").write_text('''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Step5CVerification", platforms: [.macOS(.v14)],
    targets: [.target(name: "Core"), .testTarget(name: "CoreTests", dependencies: ["Core"])],
    swiftLanguageModes: [.v5])
''')
    result = subprocess.run(["swift", "test", "--package-path", str(package)])
    raise SystemExit(result.returncode)
