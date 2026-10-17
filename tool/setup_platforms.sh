#!/usr/bin/env bash
# Genereert de iOS- en Android-projectmappen en zet achtergrondaudio aan.
# Eenmalig uitvoeren vanuit de projectmap:  bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d ios ] || [ ! -d android ]; then
  flutter create . --org nl.hetrechtepad --project-name minaret --platforms=ios,android --no-overwrite
fi

python3 tool/patch_platforms.py
flutter pub get
echo "Klaar. Start met: flutter run --dart-define=API_BASE_URL=http://localhost:8888/hetrechtepad/api/v1"
