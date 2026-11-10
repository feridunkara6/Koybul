/* ============================================================
   KOYBUL WEB ortak betik (WEB-1).
   - API tabanı: uygulamayla AYNI açık uçlar; sözleşme değişmez.
   - ESKİ PWA TEMİZLİĞİ: koybul.com kökü eskiden Flutter uygulamasıydı ve
     kök kapsamında bir service worker + önbellek bıraktı. Temizlenmezse
     dönen ziyaretçi yeni siteyi değil önbellekteki eski uygulamayı görür.
     Uygulamanın YENİ evi /app/ kapsamındaki worker'a dokunulmaz.
   ============================================================ */
'use strict';
window.KOYBUL_API = 'https://dockly-proje.onrender.com';

(function cleanOldPwa() {
  try {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (r) {
        if (new URL(r.scope).pathname === '/') r.unregister();
      });
    }).catch(function () {});
    if (window.caches && caches.keys) {
      caches.keys().then(function (keys) {
        keys.forEach(function (k) {
          // Flutter'ın kök önbellek adları; /app/ kapsamınınkiler farklı doğar.
          if (k.indexOf('flutter') === 0 || k.indexOf('dockly') === 0) caches.delete(k);
        });
      }).catch(function () {});
    }
  } catch (e) { /* temizlik en iyi çaba — sayfayı asla düşürmez */ }
})();

/* Arama kutusu: /v1/locations/search ucuna canlı sorgu; sonuç seçilince
   keşfet sayfasına konumla gidilir. Her sayfada aynı davranış. */
function koybulSearchInit(inputId, resultsId) {
  var input = document.getElementById(inputId);
  var box = document.getElementById(resultsId);
  if (!input || !box) return;
  var timer = null;
  input.addEventListener('input', function () {
    clearTimeout(timer);
    var q = input.value.trim();
    if (q.length < 2) { box.hidden = true; box.innerHTML = ''; return; }
    timer = setTimeout(function () { runSearch(q); }, 250);
  });
  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
      var first = box.querySelector('button');
      if (first) first.click();
    }
  });
  document.addEventListener('click', function (e) {
    if (!box.contains(e.target) && e.target !== input) box.hidden = true;
  });
  function runSearch(q) {
    fetch(window.KOYBUL_API + '/v1/locations/search?q=' + encodeURIComponent(q) + '&limit=6')
      .then(function (r) { return r.json(); })
      .then(function (j) {
        var rows = (j && j.data) || [];
        if (!rows.length) {
          box.innerHTML = '<button disabled><small>Sonuç bulunamadı</small></button>';
          box.hidden = false;
          return;
        }
        box.innerHTML = '';
        rows.forEach(function (p) {
          var b = document.createElement('button');
          var city = p.city ? ' · ' + p.city : '';
          b.innerHTML = '<b>' + escapeHtml(p.name) + '</b> <small>' +
            escapeHtml(koybulTypeLabel(p.type)) + city + '</small>';
          b.addEventListener('click', function () {
            location.href = '/kesfet/#c=' + p.position.lon.toFixed(5) + ',' +
              p.position.lat.toFixed(5) + ',14';
          });
          box.appendChild(b);
        });
        box.hidden = false;
      })
      .catch(function () {
        box.innerHTML = '<button disabled><small>Sunucuya ulaşılamadı — birazdan tekrar dene</small></button>';
        box.hidden = false;
      });
  }
}

var KOYBUL_TYPES = {
  private_marina: 'Özel Marina', municipal_marina: 'Belediye Marinası',
  municipal_pier: 'Belediye İskelesi', guest_mooring: 'Misafir Bağlama Noktası',
  restaurant_pier: 'Restoran İskelesi', fuel_pier: 'Yakıt İskelesi',
  boat_club: 'Tekne Kulübü', mooring_point: 'Bağlama Noktası', buoy: 'Şamandıra'
};
function koybulTypeLabel(code) { return KOYBUL_TYPES[code] || 'Bağlama Noktası'; }
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}
