#!/usr/bin/env bash
# 시연용 APK 빌드 — 배포된 백엔드를 가리키도록 API_BASE_URL을 반드시 주입한다.
#
# ⚠️ `flutter build apk`를 그냥 돌리면 앱이 에뮬레이터 전용 주소(10.0.2.2:8000)를
# 가리킨 채 만들어진다. 앱은 정상적으로 설치·실행되고, 로그인 시점에야 아무것도
# 안 된다는 걸 안다 — 시연 자리에서 발견하기 딱 좋은 실패다.
# `Env.assertConfigured()`가 시작 시점에 막지만, 애초에 잘못 빌드하지 않는 편이 낫다.
#
# 사용: scripts/build-apk.sh [API_BASE_URL]
set -euo pipefail

API_BASE_URL="${1:-https://backend-production-d97b.up.railway.app}"
cd "$(dirname "$0")/../app"

echo "API_BASE_URL = $API_BASE_URL"
flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"

echo
echo "APK: app/build/app/outputs/flutter-apk/app-release.apk"
echo "설치: adb install -r app/build/app/outputs/flutter-apk/app-release.apk"
