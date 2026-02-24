(function () {
  "use strict";

  const DEFAULT_DURATION_MS = 4000;
  const DEDUPE_WINDOW_MS = 3000;
  let container = null;
  let stylesInjected = false;
  let toastCounter = 0;
  const recent = new Map();

  function pruneRecent(nowMs) {
    for (const [key, ts] of recent.entries()) {
      if (nowMs - ts > DEDUPE_WINDOW_MS) recent.delete(key);
    }
  }

  function ensureStyles() {
    if (stylesInjected) return;
    const style = document.createElement("style");
    style.id = "kutea26-alert-style";
    style.textContent = [
      ".kutea26-alert-root{position:fixed;top:14px;right:14px;z-index:2200;display:flex;flex-direction:column;gap:8px;max-width:min(420px,92vw);pointer-events:none;}",
      ".kutea26-alert{pointer-events:auto;border:1px solid #7d3a46;background:linear-gradient(180deg,#351923,#29151d);color:#ffe7eb;border-radius:10px;padding:10px 12px;box-shadow:0 14px 28px rgba(0,0,0,.34);font-family:'Segoe UI',Tahoma,sans-serif;font-size:13px;line-height:1.35;opacity:0;transform:translateY(-6px);transition:opacity .18s ease,transform .18s ease;}",
      ".kutea26-alert.show{opacity:1;transform:translateY(0);}",
      ".kutea26-alert .title{font-weight:700;color:#ffd2d8;margin-bottom:3px;}",
      ".kutea26-alert .msg{word-break:break-word;}",
      ".kutea26-alert .meta{margin-top:5px;font-size:11px;color:#f7b9c2;opacity:.9;}",
      ".kutea26-alert.info{border-color:#2e4f7d;background:linear-gradient(180deg,#152b4b,#10213b);color:#e7f0ff;}",
      ".kutea26-alert.info .title{color:#cfe2ff;}",
      ".kutea26-alert.info .meta{color:#98b9e8;}",
    ].join("");
    document.head.appendChild(style);
    stylesInjected = true;
  }

  function ensureContainer() {
    if (container && document.body.contains(container)) return container;
    container = document.createElement("div");
    container.className = "kutea26-alert-root";
    document.body.appendChild(container);
    return container;
  }

  function removeToast(node) {
    if (!node || !node.parentNode) return;
    node.classList.remove("show");
    setTimeout(() => {
      if (node.parentNode) node.parentNode.removeChild(node);
    }, 180);
  }

  function pushToast(opts) {
    if (typeof document === "undefined" || !document.body) return;
    ensureStyles();
    const root = ensureContainer();
    const type = String(opts.type || "blocked").toLowerCase();
    const title = String(opts.title || "Alert");
    const msg = String(opts.message || "").trim();
    const meta = String(opts.meta || "").trim();
    if (!msg) return;

    const nowMs = Date.now();
    const fingerprint = `${type}|${title}|${msg}`;
    pruneRecent(nowMs);
    if (recent.has(fingerprint)) return;
    recent.set(fingerprint, nowMs);

    const node = document.createElement("div");
    node.className = `kutea26-alert ${type === "info" ? "info" : ""}`;
    node.dataset.id = String(++toastCounter);
    node.innerHTML = `<div class="title">${title}</div><div class="msg">${msg}</div>${meta ? `<div class="meta">${meta}</div>` : ""}`;
    root.appendChild(node);
    requestAnimationFrame(() => node.classList.add("show"));

    while (root.childElementCount > 5) {
      root.removeChild(root.firstElementChild);
    }

    const durationMs = Math.max(1200, Number(opts.durationMs || DEFAULT_DURATION_MS));
    setTimeout(() => removeToast(node), durationMs);
  }

  function normalizeReasonText(text) {
    const raw = String(text || "").trim();
    if (!raw) return "";
    return raw.replace(/\s+/g, " ").trim();
  }

  function extractBlockedReason(message) {
    const msg = String(message || "").trim();
    if (!msg) return "";
    const m = msg.toLowerCase();
    if (m.includes("blocked entry:")) {
      const idxReason = m.indexOf("reason=");
      if (idxReason >= 0) return normalizeReasonText(msg.slice(idxReason + 7));
      const idx = m.indexOf("blocked entry:");
      return normalizeReasonText(msg.slice(idx + "blocked entry:".length));
    }
    if (m.includes("trigger wait")) {
      const idx = msg.indexOf(":");
      return normalizeReasonText(idx >= 0 ? msg.slice(idx + 1) : msg);
    }
    if (m.includes("entry blocked")) {
      const idx = msg.indexOf(":");
      return normalizeReasonText(idx >= 0 ? msg.slice(idx + 1) : msg);
    }
    if (m.includes("phase2 arm blocked") || m.includes("phase4 arm blocked")) {
      const idx = msg.indexOf(":");
      return normalizeReasonText(idx >= 0 ? msg.slice(idx + 1) : msg);
    }
    if (m.includes("order blocked")) {
      const idx = msg.indexOf(":");
      return normalizeReasonText(idx >= 0 ? msg.slice(idx + 1) : msg);
    }
    return "";
  }

  function handleLog(message) {
    const raw = String(message || "");
    const reason = extractBlockedReason(raw);
    if (!reason) return;
    pushToast({
      type: "blocked",
      title: "Order Blocked",
      message: reason,
      meta: "Auto-hide in 4s",
      durationMs: DEFAULT_DURATION_MS,
    });
  }

  function init() {
    ensureStyles();
    ensureContainer();
  }

  window.KutEA26Alerts = {
    init,
    handleLog,
    show(message, title = "Alert", type = "info", durationMs = DEFAULT_DURATION_MS) {
      pushToast({ title, type, message, durationMs });
    },
    showBlocked(reason, rawMessage = "") {
      const msg = normalizeReasonText(reason) || extractBlockedReason(rawMessage);
      if (!msg) return;
      pushToast({
        type: "blocked",
        title: "Order Blocked",
        message: msg,
        meta: "Auto-hide in 4s",
        durationMs: DEFAULT_DURATION_MS,
      });
    },
  };
})();

