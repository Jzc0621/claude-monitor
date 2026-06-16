// Context Gauge — Canvas Renderer
(function () {
  "use strict";

  // ── Utils ──────────────────────────────────────────────────────────
  function hexRgb(h) {
    var m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(h);
    return m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : [255, 255, 255];
  }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function lerpRgb(a, b, t) {
    return [Math.round(lerp(a[0], b[0], t)), Math.round(lerp(a[1], b[1], t)), Math.round(lerp(a[2], b[2], t))];
  }
  function rgba(r, g, b, a) { return "rgba(" + r + "," + g + "," + b + "," + a + ")"; }
  function easeOut(t) { return 1 - Math.pow(1 - t, 3); }

  // ── Color stops ────────────────────────────────────────────────────
  var COLOR_SAFE    = hexRgb("#58A6FF"); // blue,   > 60%
  var COLOR_WARNING = hexRgb("#F0883E"); // orange, 30-60%
  var COLOR_DANGER  = hexRgb("#F85149"); // red,    < 30%
  var COLOR_COMPACT = hexRgb("#9944FF"); // purple, compacting

  function gaugeColor(remaining) {
    if (remaining > 60) return lerpRgb(COLOR_WARNING, COLOR_SAFE, (remaining - 60) / 40);
    if (remaining > 30) return lerpRgb(COLOR_DANGER, COLOR_WARNING, (remaining - 30) / 30);
    return COLOR_DANGER;
  }

  // ── Public interface ───────────────────────────────────────────────
  window.__gaugeRemaining = 100;  // percentage remaining
  window.__gaugeStatus    = "idle"; // idle | normal | critical | compacting | stopped

  var canvas = document.getElementById("gauge");
  var ctx = canvas.getContext("2d");

  // ── Render state ───────────────────────────────────────────────────
  var time = 0, lastT = null, rafId = null;
  var displayedRemaining = 100; // smooth target
  var animTarget = 100;
  var lifecycle = "entering", entryStart = null, ENTRY_DURATION = 800;

  // ── Resize ─────────────────────────────────────────────────────────
  function resize() {
    var dpr = window.devicePixelRatio || 1;
    var w = window.innerWidth;
    var h = window.innerHeight;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  resize();
  window.addEventListener("resize", resize);

  // ── Draw background ghost ring ─────────────────────────────────────
  function drawBgRing(cx, cy, R) {
    ctx.strokeStyle = "rgba(255,255,255,0.04)";
    ctx.lineWidth = Math.max(R * 0.10, 1.5);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2, false);
    ctx.stroke();
  }

  // ── Draw progress arc with 3-layer glow ────────────────────────────
  function drawArc(cx, cy, R, startAngle, sweepAngle, colorRgb, alphaMul) {
    if (sweepAngle < 0.005 || alphaMul < 0.005) return;
    var endAngle = startAngle + sweepAngle;

    // Outer halo
    ctx.strokeStyle = rgba(colorRgb[0], colorRgb[1], colorRgb[2], alphaMul * 0.35);
    ctx.lineWidth = Math.max(R * 0.32, 2.5);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(cx, cy, R, startAngle, endAngle, false);
    ctx.stroke();

    // Mid layer
    ctx.strokeStyle = rgba(colorRgb[0], colorRgb[1], colorRgb[2], alphaMul * 0.7);
    ctx.lineWidth = Math.max(R * 0.18, 1.5);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(cx, cy, R, startAngle, endAngle, false);
    ctx.stroke();

    // Core line
    ctx.strokeStyle = rgba(colorRgb[0], colorRgb[1], colorRgb[2], alphaMul);
    ctx.lineWidth = Math.max(R * 0.10, 1);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(cx, cy, R, startAngle, endAngle, false);
    ctx.stroke();
  }

  // ── Draw center text ───────────────────────────────────────────────
  function drawText(cx, cy, remaining, alpha, state) {
    if (alpha < 0.01) return;
    var pct = Math.round(remaining);
    var colorRgb = state === "compacting" ? COLOR_COMPACT : gaugeColor(remaining);

    ctx.fillStyle = rgba(colorRgb[0], colorRgb[1], colorRgb[2], alpha);
    ctx.font = "600 20px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(pct + "%", cx, cy);
  }

  // ── Schedule frame ─────────────────────────────────────────────────
  function scheduleFrame() {
    if (rafId !== null) return;
    rafId = requestAnimationFrame(frame);
  }

  // ── Main render loop ───────────────────────────────────────────────
  function frame(ts) {
    rafId = null;
    if (!lastT) lastT = ts;
    var dt = (ts - lastT) / 1000;
    if (dt <= 0) dt = 0.016;
    else if (dt > 0.1) dt = 0.1;
    lastT = ts;
    time += dt;

    var w = window.innerWidth;
    var h = window.innerHeight;
    var cx = Math.floor(w / 2);
    var cy = Math.floor(h / 2);
    var baseR = Math.min(w, h) * 0.42;

    // ── Entry animation ─────────────────────────────────────────────
    var entryScale = 1, entryAlpha = 1;
    if (lifecycle === "entering") {
      if (!entryStart) entryStart = ts;
      var raw = Math.min((ts - entryStart) / ENTRY_DURATION, 1);
      entryScale = 0.3 + 0.7 * easeOut(raw);
      entryAlpha = easeOut(raw);
      if (raw >= 1) { lifecycle = "active"; }
    }

    var RR = baseR * entryScale;

    // ── Smooth percentage transition ────────────────────────────────
    animTarget = window.__gaugeRemaining;
    displayedRemaining = lerp(displayedRemaining, animTarget, 0.08);
    if (Math.abs(displayedRemaining - animTarget) < 0.3) {
      displayedRemaining = animTarget;
    }

    var used = 100 - displayedRemaining;
    var sweepAngle = (used / 100) * Math.PI * 2;
    var startAngle = -Math.PI / 2; // top (12 o'clock)

    var state = window.__gaugeStatus;
    var colorRgb = state === "compacting" ? COLOR_COMPACT : gaugeColor(displayedRemaining);

    // ── Critical breathing ──────────────────────────────────────────
    var breathAlpha = 1;
    if (state === "critical" || displayedRemaining < 30) {
      breathAlpha = 0.6 + 0.4 * Math.sin(time * Math.PI * 2 / 2.0);
      breathAlpha = Math.max(0.5, breathAlpha);
    }
    if (state === "compacting") {
      breathAlpha = 0.55 + 0.45 * Math.sin(time * Math.PI * 2 / 1.2);
    }

    // ── Slow rotation offset ────────────────────────────────────────
    var rotSpeed = state === "compacting" ? 2.0 : 0.15; // rad/s
    var rotation = time * rotSpeed;

    ctx.clearRect(0, 0, w, h);

    drawBgRing(cx, cy, RR);
    drawArc(cx, cy, RR, startAngle + rotation, sweepAngle, colorRgb, entryAlpha * breathAlpha);
    drawText(cx, cy + 1, displayedRemaining, entryAlpha, state);

    scheduleFrame();
  }

  scheduleFrame();
})();
