#!/bin/sh
# =============================================================================
# Xcode Cloud — klon sonrası kurulum (Moorira iOS, mağaza fazı).
# Xcode Cloud bu betiği her derlemeden önce otomatik çalıştırır: Flutter'ı
# kurar, Mapbox SDK indirme kimliğini bağlar, bağımlılıkları çeker ve Xcode
# yapılandırmasını üretir. Ortam değişkenleri (Xcode Cloud workflow ayarından):
#   MAPBOX_DOWNLOADS_TOKEN  (secret, sk. ile başlar — pod indirme)
#   MAPBOX_ACCESS_TOKEN     (pk. ile başlar — haritanın kendisi)
# =============================================================================
set -e

echo "== Flutter 3.27.4 kuruluyor (CI ile aynı sürüm) =="
git clone https://github.com/flutter/flutter.git --depth 1 --branch 3.27.4 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --version
flutter precache --ios

if [ -n "${MAPBOX_DOWNLOADS_TOKEN:-}" ]; then
  echo "== Mapbox indirme kimliği bağlanıyor =="
  cat > "$HOME/.netrc" <<NETRC
machine api.mapbox.com
login mapbox
password ${MAPBOX_DOWNLOADS_TOKEN}
NETRC
  chmod 600 "$HOME/.netrc"
else
  echo "UYARI: MAPBOX_DOWNLOADS_TOKEN tanımlı değil — pod indirme başarısız olabilir."
fi

cd "$CI_PRIMARY_REPOSITORY_PATH/apps/mobile"

# Sunucu adresi ve ortam etiketi. Xcode Cloud workflow ayarindan
# degistirilebilir; verilmezse asagidaki varsayilan kullanilir. Yanlis ya da
# yerel bir adresle paket URETILMEZ — denetim derlemeyi durdurur.
: "${API_BASE_URL:=https://dockly-proje.onrender.com}"
: "${FLAVOR:=staging}"

echo "== Yayin yapilandirmasi denetimi =="
sh tool/check_release_config.sh "$API_BASE_URL" "$FLAVOR"

echo "== Bağımlılıklar =="
flutter pub get

echo "== Xcode yapılandırması (dart-define sabitleriyle) =="
flutter build ios --release --config-only \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=FLAVOR="$FLAVOR" \
  --dart-define=MAPBOX_ACCESS_TOKEN="${MAPBOX_ACCESS_TOKEN:-}"

echo "== CocoaPods =="
cd ios
pod install

echo "== ci_post_clone tamam =="
