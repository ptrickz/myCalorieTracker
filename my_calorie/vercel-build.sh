#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b 3.44.4 _flutter
export PATH="$PATH:$(pwd)/_flutter/bin"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://mct.up.railway.app
