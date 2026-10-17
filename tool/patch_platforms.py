#!/usr/bin/env python3
"""Past de door `flutter create` gegenereerde platformbestanden aan voor achtergrondaudio
(just_audio_background / audio_service). Idempotent: opnieuw draaien kan geen kwaad."""
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def patch_android() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        sys.exit("AndroidManifest.xml niet gevonden; draai eerst flutter create.")
    s = manifest.read_text()

    perms = [
        "android.permission.INTERNET",
        "android.permission.WAKE_LOCK",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.POST_NOTIFICATIONS",
    ]
    for p in perms:
        if p not in s:
            s = s.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)

    if 'android:label="minaret"' in s:
        s = s.replace('android:label="minaret"', 'android:label="Het Rechte Pad"')

    if "com.ryanheise.audioservice.AudioService" not in s:
        block = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    </application>"""
        s = s.replace("</application>", block, 1)
    manifest.write_text(s)

    # Alleen in debug: http naar de lokale ontwikkelserver (MAMP) toestaan.
    debug = ROOT / "android/app/src/debug/AndroidManifest.xml"
    if debug.exists():
        d = debug.read_text()
        if "usesCleartextTraffic" not in d:
            d = d.replace("</manifest>", '    <application android:usesCleartextTraffic="true" />\n</manifest>', 1)
            debug.write_text(d)

    # MainActivity moet AudioServiceActivity uitbreiden.
    for act in ROOT.glob("android/app/src/main/kotlin/**/MainActivity.kt"):
        k = act.read_text()
        if "AudioServiceActivity" not in k:
            k = k.replace("import io.flutter.embedding.android.FlutterActivity", "import com.ryanheise.audioservice.AudioServiceActivity")
            k = re.sub(r"class MainActivity\s*:\s*FlutterActivity\(\)", "class MainActivity : AudioServiceActivity()", k)
            act.write_text(k)
    for act in ROOT.glob("android/app/src/main/java/**/MainActivity.java"):
        j = act.read_text()
        if "AudioServiceActivity" not in j:
            j = j.replace("import io.flutter.embedding.android.FlutterActivity;", "import com.ryanheise.audioservice.AudioServiceActivity;")
            j = j.replace("extends FlutterActivity", "extends AudioServiceActivity")
            act.write_text(j)


def patch_ios() -> None:
    plist_path = ROOT / "ios/Runner/Info.plist"
    if not plist_path.exists():
        sys.exit("ios/Runner/Info.plist niet gevonden; draai eerst flutter create.")
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)
    modes = plist.get("UIBackgroundModes", [])
    if "audio" not in modes:
        modes.append("audio")
    plist["UIBackgroundModes"] = modes
    plist["CFBundleDisplayName"] = "Het Rechte Pad"
    # Lokale ontwikkelserver via http toestaan; productie gebruikt https.
    ats = plist.get("NSAppTransportSecurity", {})
    ats["NSAllowsLocalNetworking"] = True
    plist["NSAppTransportSecurity"] = ats
    with plist_path.open("wb") as f:
        plistlib.dump(plist, f)


def remove_template_test() -> None:
    # flutter create maakt een voorbeeldtest die naar MyApp verwijst; die bestaat hier niet.
    t = ROOT / "test/widget_test.dart"
    if t.exists() and "MyApp" in t.read_text():
        t.unlink()


if __name__ == "__main__":
    patch_android()
    patch_ios()
    remove_template_test()
    print("Platformbestanden aangepast voor achtergrondaudio.")
