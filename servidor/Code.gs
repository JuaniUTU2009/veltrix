/**
 * OptiFrag - servidor de licencias (Google Apps Script, gratis)
 *
 * Que hace:
 *  - a=activar : recibe email + codigo de compra (HP...) + id de la PC.
 *                Pregunta a Hotmart si la compra existe, es de este producto y esta aprobada.
 *                Ata la licencia a la PC (maximo MAX_PCS por compra) y devuelve un token.
 *  - a=app     : con el token valido, devuelve el codigo completo de OptiFrag (guardado en tu Drive, privado).
 *
 * Datos que tenes que cargar UNA vez en Configuracion del proyecto > Propiedades del script:
 *   HOTMART_CLIENT_ID, HOTMART_CLIENT_SECRET, HOTMART_BASIC   (Hotmart > Herramientas > Credenciales)
 *   HOTMART_PRODUCT_ID   (ID numerico de tu producto OptiFrag en Hotmart)
 * La planilla "OptiFrag - Licencias" se crea sola la primera vez.
 */

var MAX_PCS = 2;
var REVISAR_HOTMART_CADA_HS = 24;
var ESTADOS_OK = ['APPROVED', 'COMPLETE', 'COMPLETED'];

function doGet(e) {
  var p = (e && e.parameter) || {};
  try {
    if (p.a === 'activar') return json_(activar_(p));
    if (p.a === 'app') return app_(p);
    if (p.a === 'ping') return json_({ ok: true, msg: 'OptiFrag licencias funcionando' });
    return json_({ ok: false, msg: 'Pedido no valido.' });
  } catch (err) {
    return json_({ ok: false, msg: 'Error del servidor: ' + err.message });
  }
}

// ------------------------------------------------------------------ activar
function activar_(p) {
  var email = String(p.email || '').trim().toLowerCase();
  var tx = String(p.tx || '').trim().toUpperCase();
  var hw = String(p.hw || '').trim();
  if (!email || !tx || hw.length < 16) return { ok: false, msg: 'Completa tu email y tu codigo de compra.' };

  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var hoja = hoja_();
    var fila = buscarFila_(hoja, tx);
    var reg = fila ? leer_(hoja, fila) : null;

    if (!reg) {
      // Licencia nueva: hay que confirmarla con Hotmart
      var v = verificarHotmart_(tx, email);
      if (!v.ok) return v;
      hoja.appendRow([tx, email, 'ACTIVA', '', new Date(), new Date(), v.estado, 'Hotmart']);
      fila = hoja.getLastRow();
      reg = leer_(hoja, fila);
    }

    if (reg.email !== email) return { ok: false, msg: 'Ese codigo de compra no corresponde a ese email. Usa el email con el que compraste.' };
    if (reg.estado !== 'ACTIVA') return { ok: false, msg: 'Esta licencia esta desactivada (' + reg.estado + '). Escribinos si es un error.' };

    var pcs = reg.pcs ? reg.pcs.split(',') : [];
    if (pcs.indexOf(hw) < 0) {
      if (pcs.length >= MAX_PCS) return { ok: false, msg: 'Esta licencia ya esta usada en ' + MAX_PCS + ' PCs. Si cambiaste de PC, escribinos y la liberamos.' };
      pcs.push(hw);
      hoja.getRange(fila, 4).setValue(pcs.join(','));
    }
    hoja.getRange(fila, 6).setValue(new Date());
    return { ok: true, msg: 'Licencia activada. Disfruta OptiFrag!', token: token_(tx, hw), tx: tx };
  } finally {
    lock.releaseLock();
  }
}

// ------------------------------------------------------------------ entregar la app
function app_(p) {
  var tx = String(p.tx || '').trim().toUpperCase();
  var hw = String(p.hw || '').trim();
  var t = String(p.t || '');
  if (!tx || !hw || t !== token_(tx, hw)) return texto_('#OPTIFRAG_ERROR Licencia no valida. Volve a activarla.');

  var hoja = hoja_();
  var fila = buscarFila_(hoja, tx);
  if (!fila) return texto_('#OPTIFRAG_ERROR Licencia no encontrada.');
  var reg = leer_(hoja, fila);
  if (reg.estado !== 'ACTIVA') return texto_('#OPTIFRAG_ERROR Licencia desactivada (' + reg.estado + ').');
  if ((reg.pcs || '').split(',').indexOf(hw) < 0) return texto_('#OPTIFRAG_ERROR Esta PC no esta registrada en la licencia.');

  // Cada tanto se vuelve a preguntar a Hotmart (por reembolsos o contracargos)
  if (reg.origen === 'Hotmart') {
    var horas = (new Date() - new Date(reg.revisado)) / 36e5;
    if (!(horas < REVISAR_HOTMART_CADA_HS)) {
      var v = verificarHotmart_(tx, reg.email);
      if (v.ok) {
        hoja.getRange(fila, 7).setValue(v.estado);
      } else if (v.definitivo) {
        hoja.getRange(fila, 3).setValue('REEMBOLSADA');
        hoja.getRange(fila, 7).setValue(v.estado || '');
        return texto_('#OPTIFRAG_ERROR ' + v.msg);
      }
      hoja.getRange(fila, 6).setValue(new Date());
    }
  }

  return texto_(leerApp_());
}

// La app es el archivo "optifrag-app.ps1" mas nuevo de tu Drive (para actualizar, se sube uno nuevo con ese nombre)
function leerApp_() {
  var it = DriveApp.getFilesByName('optifrag-app.ps1');
  var mejor = null;
  while (it.hasNext()) { var f = it.next(); if (!f.isTrashed() && (!mejor || f.getDateCreated() > mejor.getDateCreated())) mejor = f; }
  if (!mejor) throw new Error('No encuentro optifrag-app.ps1 en tu Drive.');
  return mejor.getBlob().getDataAsString('UTF-8');
}

// ------------------------------------------------------------------ Hotmart
function consultaVentas_(tx, extra) {
  var url = 'https://developers.hotmart.com/payments/api/v1/sales/history?transaction=' + encodeURIComponent(tx) + (extra || '');
  var r = UrlFetchApp.fetch(url, { headers: { Authorization: 'Bearer ' + tokenHotmart_() }, muteHttpExceptions: true });
  if (r.getResponseCode() === 401) { CacheService.getScriptCache().remove('hm_token'); }
  return r;
}

function verificarHotmart_(tx, email) {
  var r1 = consultaVentas_(tx, '');
  var items = [];
  if (r1.getResponseCode() === 200) items = (JSON.parse(r1.getContentText()).items) || [];
  var r2 = null;
  if (!items.length) {
    r2 = consultaVentas_(tx, '&start_date=1577836800000&end_date=' + Date.now());
    if (r2.getResponseCode() === 200) items = (JSON.parse(r2.getContentText()).items) || [];
  }
  if (!items.length && r1.getResponseCode() !== 200 && (!r2 || r2.getResponseCode() !== 200)) {
    console.log('Hotmart: ' + r1.getResponseCode() + ' ' + r1.getContentText().slice(0, 300) + ' | ' + (r2 ? r2.getResponseCode() + ' ' + r2.getContentText().slice(0, 300) : ''));
    return { ok: false, msg: 'No pudimos consultar Hotmart ahora (codigo ' + r1.getResponseCode() + '/' + (r2 ? r2.getResponseCode() : '-') + '). Proba de nuevo en unos minutos.' };
  }
  if (!items.length) return { ok: false, definitivo: true, msg: 'No encontramos una compra con ese codigo. Revisa el mail de Hotmart (empieza con HP).' };

  var it = items[0];
  var prod = String((it.product && it.product.id) || '');
  var mail = String((it.buyer && it.buyer.email) || '').toLowerCase();
  var estado = String((it.purchase && it.purchase.status) || '').toUpperCase();
  var productoOk = prop_('HOTMART_PRODUCT_ID');

  if (productoOk && prod !== String(productoOk)) return { ok: false, definitivo: true, msg: 'Ese codigo es de otro producto.' };
  if (mail !== email) return { ok: false, msg: 'Ese codigo de compra no corresponde a ese email. Usa el email con el que compraste.' };
  if (ESTADOS_OK.indexOf(estado) < 0) {
    var definitivo = ['REFUNDED', 'CHARGEBACK', 'CANCELLED', 'CANCELED', 'PROTESTED', 'EXPIRED', 'BLOCKED'].indexOf(estado) >= 0;
    return { ok: false, definitivo: definitivo, estado: estado, msg: definitivo ? 'Esta compra fue reembolsada o cancelada.' : 'Tu pago todavia no esta aprobado (' + estado + '). Proba cuando Hotmart lo confirme.' };
  }
  return { ok: true, estado: estado };
}

function tokenHotmart_() {
  var cache = CacheService.getScriptCache();
  var t = cache.get('hm_token');
  if (t) return t;
  var url = 'https://api-sec-vlc.hotmart.com/security/oauth/token?grant_type=client_credentials'
    + '&client_id=' + encodeURIComponent(prop_('HOTMART_CLIENT_ID'))
    + '&client_secret=' + encodeURIComponent(prop_('HOTMART_CLIENT_SECRET'));
  var r = UrlFetchApp.fetch(url, {
    method: 'post',
    headers: { Authorization: 'Basic ' + prop_('HOTMART_BASIC').replace(/^Basic\s+/i, '') },
    muteHttpExceptions: true
  });
  if (r.getResponseCode() !== 200) throw new Error('Hotmart no acepto las credenciales (' + r.getResponseCode() + ').');
  var j = JSON.parse(r.getContentText());
  cache.put('hm_token', j.access_token, Math.min(21000, Math.max(60, (j.expires_in || 3600) - 120)));
  return j.access_token;
}

// ------------------------------------------------------------------ planilla
// Columnas: Codigo | Email | Estado | PCs | Creada | Revisado | Estado Hotmart | Origen
function hoja_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty('SHEET_ID');
  var ss;
  if (id) { ss = SpreadsheetApp.openById(id); }
  else {
    ss = SpreadsheetApp.create('OptiFrag - Licencias');
    props.setProperty('SHEET_ID', ss.getId());
    var h0 = ss.getSheets()[0];
    h0.setName('Licencias');
    h0.appendRow(['Codigo de compra', 'Email', 'Estado (ACTIVA / DESACTIVADA)', 'PCs (no tocar)', 'Creada', 'Ultimo uso', 'Estado en Hotmart', 'Origen']);
    h0.setFrozenRows(1);
    h0.getRange('A1:H1').setFontWeight('bold');
  }
  return ss.getSheetByName('Licencias');
}

function buscarFila_(hoja, tx) {
  var n = hoja.getLastRow();
  if (n < 2) return 0;
  var vals = hoja.getRange(2, 1, n - 1, 1).getValues();
  for (var i = 0; i < vals.length; i++) if (String(vals[i][0]).trim().toUpperCase() === tx) return i + 2;
  return 0;
}

function leer_(hoja, fila) {
  var v = hoja.getRange(fila, 1, 1, 8).getValues()[0];
  return {
    tx: String(v[0]).trim().toUpperCase(), email: String(v[1]).trim().toLowerCase(),
    estado: String(v[2] || 'ACTIVA').trim().toUpperCase(), pcs: String(v[3] || ''),
    revisado: v[5] || new Date(0), origen: String(v[7] || 'Manual')
  };
}

// ------------------------------------------------------------------ utilidades
function secreto_() {
  var props = PropertiesService.getScriptProperties();
  var s = props.getProperty('SECRETO');
  if (!s) { s = Utilities.getUuid() + Utilities.getUuid(); props.setProperty('SECRETO', s); }
  return s;
}
function token_(tx, hw) {
  var sig = Utilities.computeHmacSha256Signature(tx + '|' + hw, secreto_());
  return Utilities.base64EncodeWebSafe(sig).replace(/=+$/, '');
}
function prop_(k) { return PropertiesService.getScriptProperties().getProperty(k) || ''; }
function json_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
function texto_(s) { return ContentService.createTextOutput(s).setMimeType(ContentService.MimeType.TEXT); }

/** Ejecutalo una vez desde el editor (boton Ejecutar) para dar permisos y crear la planilla. */
function prepararTodo() {
  secreto_();
  var h = hoja_();
  Logger.log('Planilla lista: ' + h.getParent().getUrl());
  if (prop_('HOTMART_CLIENT_ID')) { tokenHotmart_(); Logger.log('Credenciales de Hotmart OK'); }
  Logger.log('App en Drive: ' + leerApp_().length + ' caracteres');
}
