#!/bin/sh
# =============================================================================
# YAYIN DERLEMESI ON DENETIMI — Koybul (denetim Faz 0)
#
# Amac: yanlis sunucu adresiyle bir IPA/web paketi URETILMESIN. Uygulamanin
# icinde de ayni kural var (lib/config/flavor.dart) ama o kural ancak paket
# hazir olduktan SONRA, telefonda calisir. Burada daha ucuz bir yerde,
# derleme baslamadan durduruyoruz.
#
# Kullanim:  sh tool/check_release_config.sh "$API_BASE_URL" "$FLAVOR"
# Cikis:     0 = tamam, 1 = derlemeyi durdur
# =============================================================================
set -eu

URL="${1:-}"
FLAVOR="${2:-}"

die() {
  echo ""
  echo "  ============================================================"
  echo "  DERLEME DURDURULDU: $1"
  echo "  ============================================================"
  echo "  Duzeltme: Codemagic / GitHub panelinde API_BASE_URL degiskenini"
  echo "  https://... bicimindeki GERCEK sunucu adresine, FLAVOR degiskenini"
  echo "  de dev | staging | prod degerlerinden birine ayarla."
  echo ""
  exit 1
}

# Panele yapistirirken bulasan bas/son bosluklari at. Uygulama da ayni sekilde
# trim eder (lib/config/flavor.dart) — denetim ile uygulama AYNI seyi kabul
# etmezse denetim koruma olmaktan cikar, gurultu olur.
URL=$(printf '%s' "$URL" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
FLAVOR=$(printf '%s' "$FLAVOR" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

[ -n "$URL" ] || die "API_BASE_URL bos. Adres verilmeden alinan paket her istegi
  gelistirici bilgisayarina gonderir; uygulama canli gorunup olu kalir."

# Buyuk/kucuk harf duyarsiz karsilastirma: uygulama sema ve alan adini kucuk
# harfe cevirip bakiyor. Duyarli birakilsaydi 'https://LOCALHOST:3000' denetimi
# gecer, IPA imzalanip TestFlight'a yuklendikten SONRA yakalanirdi.
URL_LC=$(printf '%s' "$URL" | tr '[:upper:]' '[:lower:]')

case "$URL_LC" in
  https://?*) ;;
  *) die "API_BASE_URL https:// ile baslamiyor (su an: '$URL').
  iOS sifresiz baglantiyi keser, veri de acik agda okunabilir olur." ;;
esac

case "$URL_LC" in
  https:///*) die "API_BASE_URL'de alan adi yok (su an: '$URL').
  Beklenen bicim: https://alanadi.com" ;;
esac

case "$URL_LC" in
  *//localhost*|*//127.0.0.1*|*//0.0.0.0*|*//10.0.2.2*|*//\[::1\]*)
    die "API_BASE_URL yerel bilgisayari gosteriyor (su an: '$URL').
  Kullanicinin telefonunda boyle bir sunucu yoktur." ;;
esac

# Uygulamadaki kKnownFlavorNames listesiyle AYNI olmali (lib/config/flavor.dart).
case "$(printf '%s' "$FLAVOR" | tr '[:upper:]' '[:lower:]')" in
  dev|development|staging|stg|prod|production) ;;
  "") die "FLAVOR bos. Derlemenin hangi ortam oldugu belirtilmeli." ;;
  *) die "FLAVOR taninmiyor (su an: '$FLAVOR'). Beklenen: dev | staging | prod" ;;
esac

echo "  Yayin yapilandirmasi OK  ->  $FLAVOR  @  $URL"
