(function (global) {
  "use strict";

  var PREFIX = "kutea26_mem_v1";
  var CHART_PREFS_KEY = PREFIX + ":chart_prefs";
  var MAX_BARS_DEFAULT = 12500;
  var MAX_RECENT_OUTCOMES = 240;

  function getStorage() {
    try {
      return global.localStorage || null;
    } catch (_) {
      return null;
    }
  }

  function normPart(v) {
    return String(v || "").trim();
  }

  function candleKey(symbol, tf) {
    return PREFIX + ":candles:" + normPart(symbol) + "|" + normPart(tf).toUpperCase();
  }

  function learningKey(symbol, tf) {
    return PREFIX + ":learn:" + normPart(symbol) + "|" + normPart(tf).toUpperCase();
  }

  function readJson(key, fallbackValue) {
    var s = getStorage();
    if (!s) return fallbackValue;
    try {
      var raw = s.getItem(key);
      if (!raw) return fallbackValue;
      return JSON.parse(raw);
    } catch (_) {
      return fallbackValue;
    }
  }

  function writeJson(key, value) {
    var s = getStorage();
    if (!s) return false;
    try {
      s.setItem(key, JSON.stringify(value));
      return true;
    } catch (_) {
      return false;
    }
  }

  function sanitizeCandle(row) {
    if (!row || typeof row !== "object") return null;
    var t = Math.trunc(Number(row.time));
    var o = Number(row.open);
    var h = Number(row.high);
    var l = Number(row.low);
    var c = Number(row.close);
    var v = Number(row.volume != null ? row.volume : (row.tick_volume != null ? row.tick_volume : 0));
    if (!Number.isFinite(t) || t <= 0) return null;
    if (!Number.isFinite(o) || !Number.isFinite(h) || !Number.isFinite(l) || !Number.isFinite(c)) return null;
    var hi = Math.max(h, l, o, c);
    var lo = Math.min(h, l, o, c);
    return {
      time: t,
      open: o,
      high: hi,
      low: lo,
      close: c,
      volume: Number.isFinite(v) ? v : 0
    };
  }

  function sanitizeCandles(rows) {
    if (!Array.isArray(rows)) return [];
    var out = [];
    for (var i = 0; i < rows.length; i += 1) {
      var c = sanitizeCandle(rows[i]);
      if (c) out.push(c);
    }
    out.sort(function (a, b) { return a.time - b.time; });
    return out;
  }

  function trimTail(rows, maxBars) {
    var limit = Math.max(100, Math.trunc(Number(maxBars) || MAX_BARS_DEFAULT));
    if (rows.length <= limit) return rows;
    return rows.slice(rows.length - limit);
  }

  function mergeCandles(existingRows, incomingRows, maxBars) {
    var a = sanitizeCandles(existingRows);
    var b = sanitizeCandles(incomingRows);
    if (!a.length) return trimTail(b, maxBars);
    if (!b.length) return trimTail(a, maxBars);
    var byTime = Object.create(null);
    for (var i = 0; i < a.length; i += 1) byTime[String(a[i].time)] = a[i];
    for (var j = 0; j < b.length; j += 1) byTime[String(b[j].time)] = b[j];
    var merged = Object.keys(byTime).map(function (k) { return byTime[k]; });
    merged.sort(function (x, y) { return x.time - y.time; });
    return trimTail(merged, maxBars);
  }

  function getCandlePayload(symbol, tf) {
    var raw = readJson(candleKey(symbol, tf), null);
    if (!raw || typeof raw !== "object") {
      return { symbol: normPart(symbol), tf: normPart(tf).toUpperCase(), bars: [], updated_at: 0 };
    }
    return {
      symbol: normPart(raw.symbol || symbol),
      tf: normPart(raw.tf || tf).toUpperCase(),
      bars: sanitizeCandles(raw.bars),
      updated_at: Number(raw.updated_at || 0)
    };
  }

  function upsertCandles(symbol, tf, incomingRows, maxBars) {
    var oldPayload = getCandlePayload(symbol, tf);
    var merged = mergeCandles(oldPayload.bars, incomingRows, maxBars || MAX_BARS_DEFAULT);
    var payload = {
      symbol: normPart(symbol),
      tf: normPart(tf).toUpperCase(),
      bars: merged,
      updated_at: Date.now()
    };
    writeJson(candleKey(symbol, tf), payload);
    return payload;
  }

  function saveChartPrefs(prefs) {
    if (!prefs || typeof prefs !== "object") return false;
    var allowed = Array.isArray(prefs.allowedSymbols) ? prefs.allowedSymbols : [];
    var cleanedAllowed = allowed.map(normPart).filter(Boolean).slice(0, 6);
    var payload = {
      selectedSymbol: normPart(prefs.selectedSymbol),
      chartTf: normPart(prefs.chartTf).toUpperCase() || "M1",
      chartVisibleCount: Math.max(40, Math.trunc(Number(prefs.chartVisibleCount) || 150)),
      chartPanBars: Math.max(0, Math.trunc(Number(prefs.chartPanBars) || 0)),
      chartYZoom: Number.isFinite(Number(prefs.chartYZoom)) ? Number(prefs.chartYZoom) : 1,
      chartYShift: Number.isFinite(Number(prefs.chartYShift)) ? Number(prefs.chartYShift) : 0,
      chartFreeMove: !!prefs.chartFreeMove,
      allowedSymbols: cleanedAllowed,
      updated_at: Date.now()
    };
    return writeJson(CHART_PREFS_KEY, payload);
  }

  function loadChartPrefs() {
    var raw = readJson(CHART_PREFS_KEY, null);
    if (!raw || typeof raw !== "object") return null;
    return {
      selectedSymbol: normPart(raw.selectedSymbol),
      chartTf: normPart(raw.chartTf).toUpperCase() || "M1",
      chartVisibleCount: Math.max(40, Math.trunc(Number(raw.chartVisibleCount) || 150)),
      chartPanBars: Math.max(0, Math.trunc(Number(raw.chartPanBars) || 0)),
      chartYZoom: Number.isFinite(Number(raw.chartYZoom)) ? Number(raw.chartYZoom) : 1,
      chartYShift: Number.isFinite(Number(raw.chartYShift)) ? Number(raw.chartYShift) : 0,
      chartFreeMove: !!raw.chartFreeMove,
      allowedSymbols: Array.isArray(raw.allowedSymbols) ? raw.allowedSymbols.map(normPart).filter(Boolean).slice(0, 6) : [],
      updated_at: Number(raw.updated_at || 0)
    };
  }

  function defaultLearning(symbol, tf, horizonBars, flatThresholdPct) {
    return {
      symbol: normPart(symbol),
      tf: normPart(tf).toUpperCase(),
      horizon_bars: horizonBars,
      flat_threshold_pct: flatThresholdPct,
      samples: 0,
      up_count: 0,
      down_count: 0,
      flat_count: 0,
      avg_move_pct: 0,
      avg_abs_move_pct: 0,
      last_eval_time: 0,
      recent_outcomes: [],
      bias: "neutral",
      updated_at: 0
    };
  }

  function firstIndexGreaterThan(candles, unixTs) {
    var lo = 0;
    var hi = candles.length;
    while (lo < hi) {
      var mid = (lo + hi) >> 1;
      if (candles[mid].time <= unixTs) lo = mid + 1;
      else hi = mid;
    }
    return lo;
  }

  function updateBias(stats) {
    var total = Math.max(1, Number(stats.samples || 0));
    var upRate = Number(stats.up_count || 0) / total;
    var downRate = Number(stats.down_count || 0) / total;
    var edge = upRate - downRate;
    if (edge >= 0.06) stats.bias = "bullish";
    else if (edge <= -0.06) stats.bias = "bearish";
    else stats.bias = "neutral";
  }

  function ingestLearning(symbol, tf, candleRows, opts) {
    var options = opts || {};
    var horizonBars = Math.max(2, Math.min(300, Math.trunc(Number(options.horizonBars) || 12)));
    var flatThresholdPct = Math.max(0, Math.min(0.05, Number(options.flatThresholdPct) || 0.0002));
    var candles = sanitizeCandles(candleRows);
    if (candles.length < horizonBars + 2) {
      return getLearningSummary(symbol, tf, horizonBars, flatThresholdPct);
    }

    var key = learningKey(symbol, tf);
    var raw = readJson(key, null);
    var stats = (raw && typeof raw === "object") ? raw : defaultLearning(symbol, tf, horizonBars, flatThresholdPct);
    if (Math.trunc(Number(stats.horizon_bars || 0)) !== horizonBars || Number(stats.flat_threshold_pct || 0) !== flatThresholdPct) {
      stats = defaultLearning(symbol, tf, horizonBars, flatThresholdPct);
    }

    var startIdx = 0;
    var lastEval = Math.trunc(Number(stats.last_eval_time || 0));
    if (lastEval > 0) startIdx = firstIndexGreaterThan(candles, lastEval);
    var maxBase = candles.length - horizonBars - 1;
    if (maxBase < 0 || startIdx > maxBase) {
      stats.updated_at = Date.now();
      writeJson(key, stats);
      return stats;
    }

    for (var i = startIdx; i <= maxBase; i += 1) {
      var base = candles[i];
      var future = candles[i + horizonBars];
      var baseClose = Number(base.close);
      var futureClose = Number(future.close);
      if (!Number.isFinite(baseClose) || !Number.isFinite(futureClose) || baseClose === 0) continue;
      var movePct = (futureClose - baseClose) / Math.abs(baseClose);
      var absMove = Math.abs(movePct);
      var direction = "flat";
      if (movePct > flatThresholdPct) direction = "up";
      else if (movePct < -flatThresholdPct) direction = "down";

      stats.samples = Math.max(0, Number(stats.samples || 0)) + 1;
      if (direction === "up") stats.up_count = Math.max(0, Number(stats.up_count || 0)) + 1;
      else if (direction === "down") stats.down_count = Math.max(0, Number(stats.down_count || 0)) + 1;
      else stats.flat_count = Math.max(0, Number(stats.flat_count || 0)) + 1;

      stats.avg_move_pct = Number(stats.avg_move_pct || 0) + (movePct - Number(stats.avg_move_pct || 0)) / stats.samples;
      stats.avg_abs_move_pct = Number(stats.avg_abs_move_pct || 0) + (absMove - Number(stats.avg_abs_move_pct || 0)) / stats.samples;
      stats.last_eval_time = Math.max(0, Math.trunc(Number(base.time || 0)));

      var recent = Array.isArray(stats.recent_outcomes) ? stats.recent_outcomes : [];
      recent.push({
        time: stats.last_eval_time,
        direction: direction,
        move_pct: Number(movePct.toFixed(6))
      });
      if (recent.length > MAX_RECENT_OUTCOMES) {
        recent = recent.slice(recent.length - MAX_RECENT_OUTCOMES);
      }
      stats.recent_outcomes = recent;
    }

    updateBias(stats);
    stats.updated_at = Date.now();
    writeJson(key, stats);
    return stats;
  }

  function getLearningSummary(symbol, tf, horizonBars, flatThresholdPct) {
    var key = learningKey(symbol, tf);
    var raw = readJson(key, null);
    if (!raw || typeof raw !== "object") return defaultLearning(symbol, tf, horizonBars || 12, flatThresholdPct || 0.0002);
    updateBias(raw);
    return raw;
  }

  function clearNamespace() {
    var s = getStorage();
    if (!s) return 0;
    var keysToRemove = [];
    for (var i = 0; i < s.length; i += 1) {
      var k = s.key(i);
      if (typeof k === "string" && k.indexOf(PREFIX + ":") === 0) keysToRemove.push(k);
    }
    for (var j = 0; j < keysToRemove.length; j += 1) s.removeItem(keysToRemove[j]);
    return keysToRemove.length;
  }

  global.KutEA26Memory = Object.freeze({
    VERSION: 1,
    PREFIX: PREFIX,
    MAX_BARS: MAX_BARS_DEFAULT,
    MAX_RECENT_OUTCOMES: MAX_RECENT_OUTCOMES,
    getCandles: getCandlePayload,
    upsertCandles: upsertCandles,
    loadChartPrefs: loadChartPrefs,
    saveChartPrefs: saveChartPrefs,
    ingestLearning: ingestLearning,
    getLearningSummary: getLearningSummary,
    clearNamespace: clearNamespace
  });
})(window);
