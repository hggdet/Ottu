#!/usr/bin/env python3
"""Validate Quick Action resources without Xcode. Does not compile or run iOS code."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
KEYS = {
    "quick_action.support.title", "quick_action.support.subtitle",
    "quick_action.support.subject", "quick_action.support.body",
    "quick_action.support.unavailable", "quick_action.support.copy",
    "quick_action.stay.title", "quick_action.stay.subtitle",
    "quick_action.stay.message", "quick_action.stay.keep",
}
MENU_KEYS = {
    "quick_action.support.title", "quick_action.support.subtitle",
    "quick_action.stay.title", "quick_action.stay.subtitle",
}
STRING_LINE = re.compile(r'\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;\s*')


def strings(path):
    values = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.strip().startswith("/*") or line.strip().startswith("//"):
            continue
        match = STRING_LINE.fullmatch(line)
        if not match:
            raise AssertionError(f"Invalid strings syntax: {path}:{number}")
        key, value = map(json.loads, match.groups())
        if key in values:
            raise AssertionError(f"Duplicate key: {path}:{number}: {key}")
        values[key] = value
    return values


class QuickActionResourcesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.project = yaml.safe_load((ROOT / "project.yml").read_text())
        cls.info = plistlib.loads((ROOT / "Support/Info.plist").read_bytes())
        cls.source = (ROOT / "Sources/Ottu/App/HomeScreenQuickActions.swift").read_text()

    def test_plist_and_project_generator_agree(self):
        generated = self.project["targets"]["Ottu"]["info"]["properties"]["UIApplicationShortcutItems"]
        self.assertEqual(self.info["UIApplicationShortcutItems"], generated)

    def test_route_identifiers_are_unique_and_match_plist(self):
        routes = re.findall(r'case \w+ = "(iq\.ottu\.ios\.quick-action\.[^"]+)"', self.source)
        self.assertEqual(len(routes), 2)
        self.assertEqual(len(set(routes)), 2)
        self.assertEqual(set(routes), {i["UIApplicationShortcutItemType"] for i in self.info["UIApplicationShortcutItems"]})
        for item in self.info["UIApplicationShortcutItems"]:
            self.assertIn(item["UIApplicationShortcutItemTitle"], MENU_KEYS)
            self.assertIn(item["UIApplicationShortcutItemSubtitle"], MENU_KEYS)
            self.assertIn(item["UIApplicationShortcutItemIconType"], {"UIApplicationShortcutIconTypeMail", "UIApplicationShortcutIconTypeLove"})

    def test_every_localization_has_matching_menu_and_app_copy(self):
        for language in ["ar", "en", "ku"]:
            with self.subTest(language=language):
                base = ROOT / "Resources" / f"{language}.lproj"
                app = strings(base / "Localizable.strings")
                menu = strings(base / "InfoPlist.strings")
                self.assertEqual({key for key in app if key.startswith("quick_action.")}, KEYS)
                self.assertEqual({key for key in menu if key.startswith("quick_action.")}, MENU_KEYS)
                for key in KEYS:
                    self.assertTrue(app[key].strip())
                for key in MENU_KEYS:
                    self.assertEqual(menu[key], app[key])

    def test_arabic_requested_title_and_friendly_message(self):
        ar = strings(ROOT / "Resources/ar.lproj/Localizable.strings")
        self.assertEqual(ar["quick_action.stay.title"], "ليش تحذفني؟ 😢")
        self.assertIn("القرار إلك", ar["quick_action.stay.message"])
        self.assertIn("\n\n", ar["quick_action.support.body"])

    def test_support_address_is_not_invented(self):
        previous_settings = subprocess.check_output(
            ["git", "show", "HEAD:Sources/Ottu/Features/Settings/AppSettingsView.swift"], cwd=ROOT, text=True
        )
        address = re.search(r'mailto:([^"\s]+)', previous_settings).group(1)
        self.assertIn(f'static let email = "{address}"', self.source)
        settings = (ROOT / "Sources/Ottu/Features/Settings/AppSettingsView.swift").read_text()
        self.assertIn("SupportContact.mailURL(", settings)
        self.assertIn("composer.mailComposeDelegate = self", self.source)
        self.assertIn("MFMailComposeViewController.canSendMail()", self.source)

    def test_app_and_tests_are_included_by_project_paths(self):
        self.assertIn("@UIApplicationDelegateAdaptor(QuickActionAppDelegate.self)",
                      (ROOT / "Sources/Ottu/App/OttuApp.swift").read_text())
        self.assertTrue((ROOT / "Tests/OttuTests/HomeScreenQuickActionsTests.swift").is_file())
        targets = self.project["targets"]
        self.assertIn({"path": "Sources/Ottu"}, targets["Ottu"]["sources"])
        self.assertIn({"path": "Tests/OttuTests"}, targets["OttuTests"]["sources"])

    def test_protected_map_files_have_no_diff(self):
        for name in ["MapHomeView.swift", "FloatingMapControls.swift", "ProgressiveMapEdgeBlur.swift"]:
            result = subprocess.run(["git", "diff", "HEAD", "--exit-code", "--", f"Sources/Ottu/Features/Map/{name}"],
                                    cwd=ROOT, capture_output=True)
            self.assertEqual(result.returncode, 0, f"Unexpected change to {name}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
