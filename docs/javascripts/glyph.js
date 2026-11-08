/*
 * Copyright 2026 BitWise Media Group Ltd
 * SPDX-License-Identifier: MIT
 *
 * Glyph docs: the app mockups and the motion around them.
 *
 * Pages hold placeholders, `<div data-gl-mock="now"></div>`, and this file
 * draws the app into them as HTML (styled by stylesheets/extra.css), so every
 * page shares one picture of each screen. It also runs a simulated sensor for
 * the "live" mockups (a new reading every few seconds), steps the sensor
 * lifecycle figure, reveals figures as they scroll in, and makes the Settings
 * mockup's switches and unit picker work.
 *
 * Zensical's instant navigation swaps pages without a reload, so everything
 * hangs off `document$` and the timers are cleared on each page.
 *
 * Mockups: now, history, sensor (data-phase: streaming | warming | none |
 * lost), settings, duo, fold, lock-alert, lock-live, island, widgets, scan,
 * lifecycle, pipeline. Add data-live="false" to freeze a live one.
 */
(function () {
    "use strict";

    var root = document.documentElement;
    root.classList.add("gl-js");
    var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var timers = [];
    var observers = [];

    /* ---------- icons (SF Symbols look-alikes, 24-unit grid) ---------- */
    function svg(body, extra) {
        return (
            '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"' +
            (extra || "") +
            ">" +
            body +
            "</svg>"
        );
    }
    var ICON = {
        now: svg('<path d="M12 3c3.5 4.4 6 7.8 6 11a6 6 0 0 1-12 0c0-3.2 2.5-6.6 6-11Z" fill="currentColor"/>'),
        history: svg('<path d="M3 3v18h18"/><path d="m7 15 4-5 3 3 5-6"/>'),
        sensor: svg(
            '<circle cx="12" cy="12" r="7" fill="currentColor" stroke="none"/><path d="M4 6a11 11 0 0 0 0 12M20 6a11 11 0 0 1 0 12"/>',
        ),
        settings: svg(
            '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/>',
        ),
        arrow: '<svg class="gl-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12h15M13 5l7 7-7 7"/></svg>',
        check: svg('<circle cx="12" cy="12" r="10" fill="currentColor" stroke="none"/><path d="m7.5 12.5 3 3 6-6.5" stroke="#fff"/>'),
        hourglass: svg('<path d="M6 2h12M6 22h12M7 2c0 6 10 6 10 10S7 16 7 22M17 2c0 6-10 6-10 10s10 4 10 10"/>'),
        nosignal: svg('<path d="M2 2l20 20M8.5 16.4a5 5 0 0 1 7 0M5 12.9a10 10 0 0 1 4.2-2.5M19 12.9a10 10 0 0 0-2.3-1.7M12 20h.01"/>'),
        radio: svg('<circle cx="12" cy="12" r="2"/><path d="M16.2 7.8a6 6 0 0 1 0 8.4M7.8 16.2a6 6 0 0 1 0-8.4M19.1 4.9a10 10 0 0 1 0 14.2M4.9 19.1a10 10 0 0 1 0-14.2"/>'),
        nfc: svg('<path d="M6 8.5a5 5 0 0 1 0 7M10 6a9 9 0 0 1 0 12M14 3.5a13 13 0 0 1 0 17"/>'),
        trash: svg('<path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/>'),
        clock: svg('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
        pm: svg('<path d="M12 4v10M7 9h10M7 19h10"/>'),
        bell: svg('<path d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0"/>'),
    };

    function el(html) {
        var t = document.createElement("template");
        t.innerHTML = html.trim();
        return t.content.firstElementChild;
    }
    function esc(s) {
        return String(s).replace(/[&<>"]/g, function (c) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
        });
    }

    /* ---------- glucose: units, levels, a deterministic day ---------- */
    var MGDL = 18.0182;
    var TARGET = { lo: 3.9, hi: 10.0 }; // mmol/L (70–180 mg/dL)
    var ALERT = { low: 3.9, high: 13.9 }; // the low and high alert defaults
    function level(v) {
        if (v < 3.0) return "urgentLow";
        if (v < TARGET.lo) return "low";
        if (v > TARGET.hi) return "high";
        return "inRange";
    }
    function cls(v) {
        var l = level(v);
        return l === "inRange" ? "in" : l === "high" ? "hi" : "lo";
    }
    // Clock times in the mockups, as minutes after 9:41 (the status bar's time).
    function clock(delta) {
        var t = (((9 * 60 + 41 + delta) % 1440) + 1440) % 1440;
        return String(Math.floor(t / 60)).padStart(2, "0") + ":" + String(t % 60).padStart(2, "0");
    }
    function f1(v) {
        return (Math.round(v * 10) / 10).toFixed(1);
    }
    function rng(seed) {
        return function () {
            seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
            return seed / 4294967296;
        };
    }
    // A plausible day in mmol/L, one value per `step` minutes: a slow swing,
    // a breakfast and a lunch bump, and a little noise.
    function day(n, step, seed, offset) {
        var r = rng(seed || 7);
        var out = [];
        for (var i = 0; i < n; i++) {
            var t = (i + (offset || 0)) * step;
            var hour = (t / 60) % 24;
            var meal = bump(hour, 8.2, 1.1, 3.4) + bump(hour, 13.1, 1.3, 2.7) + bump(hour, 19.4, 1.5, 2.2);
            out.push(5.6 + 0.7 * Math.sin(t / 290) + meal + (r() - 0.5) * 0.35);
        }
        return out;
    }
    function bump(h, at, width, height) {
        var d = (h - at) / width;
        return d > -1.2 ? height * Math.exp(-d * d) : 0;
    }
    function trend(rate) {
        // mg/dL per minute → arrow angle (and how many arrows)
        var a = Math.abs(rate);
        var up = rate > 0;
        if (a < 1) return { deg: 0, label: "steady" };
        if (a < 2) return { deg: up ? -45 : 45, label: up ? "rising slightly" : "falling slightly" };
        return { deg: up ? -90 : 90, label: up ? "rising" : "falling" };
    }

    /* ---------- chart geometry: viewBox 300×150, 2–14 mmol/L ---------- */
    var W = 300,
        H = 150,
        LO = 2,
        HI = 14;
    function y(v) {
        return (H - ((Math.min(HI, Math.max(LO, v)) - LO) / (HI - LO)) * H).toFixed(1);
    }
    function linePath(vals) {
        var n = vals.length;
        return vals
            .map(function (v, i) {
                return (i ? "L" : "M") + ((i / (n - 1)) * W).toFixed(1) + " " + y(v);
            })
            .join("");
    }
    function chart(vals, o) {
        o = o || {};
        var last = vals[vals.length - 1];
        return (
            '<div class="gl-chart' +
            (o.tall ? " gl-chart--tall" : "") +
            '"><svg viewBox="0 0 ' +
            W +
            " " +
            H +
            '" preserveAspectRatio="none">' +
            '<rect class="band" x="0" width="' +
            W +
            '" y="' +
            y(TARGET.hi) +
            '" height="' +
            (y(TARGET.lo) - y(TARGET.hi)).toFixed(1) +
            '"/>' +
            '<line class="rule rule--high" x1="0" x2="' +
            W +
            '" y1="' +
            y(ALERT.high) +
            '" y2="' +
            y(ALERT.high) +
            '"/>' +
            '<line class="rule rule--low" x1="0" x2="' +
            W +
            '" y1="' +
            y(ALERT.low) +
            '" y2="' +
            y(ALERT.low) +
            '"/>' +
            '<path class="line' +
            (o.draw ? " line--draw" : "") +
            '" d="' +
            linePath(vals) +
            '"' +
            (o.draw ? ' pathLength="1"' : "") +
            "/>" +
            (o.dot === false
                ? ""
                : '<circle class="now" r="3.2" cx="' + W + '" cy="' + y(last) + '" vector-effect="non-scaling-stroke"/>') +
            "</svg>" +
            (o.scrub ? '<div class="gl-scrub"><b>' + o.scrub + "</b></div>" : "") +
            (o.axis ? '<div class="axis">' + o.axis.map((a) => "<span>" + a + "</span>").join("") + "</div>" : "") +
            "</div>"
        );
    }
    function rangeBar(p) {
        // p: [veryLow, low, in, high, veryHigh] as percentages
        return (
            '<div class="gl-range gl-reveal">' +
            p
                .map(function (x, i) {
                    return '<i style="width:' + x + "%;animation-delay:" + i * 0.08 + 's"></i>';
                })
                .join("") +
            "</div>"
        );
    }

    /* ---------- the phone ---------- */
    var STATUS =
        '<div class="gl-status"><span>9:41</span><i>' +
        '<svg viewBox="0 0 34 12" width="2.6em" height="0.95em" fill="currentColor" aria-hidden="true">' +
        '<rect x="0" y="8" width="3" height="4" rx="1"/><rect x="4.5" y="6" width="3" height="6" rx="1"/>' +
        '<rect x="9" y="3.5" width="3" height="8.5" rx="1"/><rect x="13.5" y="1" width="3" height="11" rx="1"/>' +
        '<rect x="20.5" y="1" width="12" height="10" rx="3" fill="none" stroke="currentColor" stroke-width="1.2"/>' +
        '<rect x="22.3" y="2.8" width="7.5" height="6.4" rx="1.6"/></svg></i></div>';
    var TABS = [
        ["now", "Now"],
        ["history", "History"],
        ["sensor", "Sensor"],
        ["settings", "Settings"],
    ];
    function tabbar(on, vertical) {
        return (
            '<div class="gl-tabbar' +
            (vertical ? " gl-tabbar--v" : "") +
            '">' +
            TABS.map(function (t) {
                return '<span class="' + (t[0] === on ? "is-on" : "") + '">' + ICON[t[0]] + (vertical ? "" : t[1]) + "</span>";
            }).join("") +
            "</div>"
        );
    }
    function screen(o) {
        return (
            '<div class="gl-screen' +
            (o.cls ? " " + o.cls : "") +
            '">' +
            (o.island === false ? "" : '<div class="gl-island"></div>') +
            STATUS +
            (o.title ? '<div class="gl-navtitle' + (o.large ? " gl-navtitle--large" : "") + '">' + o.title + "</div>" : "") +
            '<div class="gl-body">' +
            (o.body || "") +
            "</div>" +
            (o.tab ? tabbar(o.tab, o.verticalTabs) : "") +
            (o.home === false ? "" : '<div class="gl-homebar"></div>') +
            "</div>"
        );
    }
    function phone(inner, label, small) {
        return (
            '<div class="gl-device' +
            (small ? " gl-device--sm" : "") +
            '" role="img" aria-label="' +
            esc(label) +
            '">' +
            inner +
            "</div>"
        );
    }

    /* ---------- the Now screen ---------- */
    var NOW_SERIES = day(36, 5, 11, 80); // the three hours to 9:41, with breakfast in them
    function valueCard(v, rate, o) {
        o = o || {};
        var t = trend(rate);
        return (
            '<div class="gl-ui-card">' +
            '<div class="gl-value" data-level="' +
            level(v) +
            '"><span data-v>' +
            f1(v) +
            "</span>" +
            ICON.arrow.replace("<svg ", '<svg style="transform:rotate(' + t.deg + 'deg)" ') +
            "<small>mmol/L</small></div>" +
            '<div class="gl-ui-meta"><span>± <span data-delta>' +
            (rate >= 0 ? "+" : "−") +
            f1(Math.abs((rate * 5) / MGDL)) +
            "</span> mmol/L</span><span data-age>" +
            (o.age || "Just now") +
            "</span></div>" +
            (o.warn ? '<div class="gl-ui-warn">' + o.warn + "</div>" : "") +
            "</div>"
        );
    }
    function nowPrimary(vals) {
        var v = vals[vals.length - 1];
        var rate = ((v - vals[vals.length - 2]) * MGDL) / 5;
        return (
            valueCard(v, rate) +
            '<div class="gl-ui-card"><h5>Last 3 hours</h5>' +
            chart(vals, { draw: true, axis: [clock(-180), clock(-120), clock(-60), clock(0)] }) +
            '<div style="height:1em"></div></div>'
        );
    }
    function todayCard() {
        return (
            '<div class="gl-ui-card"><h5>Today</h5><div class="gl-big" data-tir>84%</div>' +
            '<div class="gl-ui-sub">in range 3.9–10.0 mmol/L</div>' +
            rangeBar([0, 3, 84, 11, 2]) +
            "</div>"
        );
    }
    function sensorLifeCard() {
        return (
            '<div class="gl-ui-card"><h5>Sensor</h5><div class="gl-big">9.4 <small>days left</small></div>' +
            '<div class="gl-progress" style="--p:39%"><i></i></div><div class="gl-ui-sub">Ends Wed 14:20</div></div>'
        );
    }
    function recentCard(vals, count) {
        var rows = "";
        for (var i = 0; i < count; i++) {
            var v = vals[vals.length - 1 - i];
            rows += '<div><span class="k">' + clock(-i * 5) + '</span><span class="v ' + cls(v) + '">' + f1(v) + "</span></div>";
        }
        return '<div class="gl-ui-card"><h5>Recent readings</h5><div class="gl-rows" data-rows>' + rows + "</div></div>";
    }
    function nowPhone() {
        return phone(
            screen({
                title: "Now",
                tab: "now",
                body: nowPrimary(NOW_SERIES) + todayCard() + sensorLifeCard(),
            }),
            "The Now tab: the current reading with its trend arrow, a three-hour chart and today's time in range",
        );
    }

    /* ---------- the unfolded Duo ---------- */
    function duo() {
        return (
            '<div class="gl-device gl-device--duo" role="img" aria-label="Glyph on the unfolded iPhone Duo: the current reading and chart in one pane, today and recent readings in the other">' +
            screen({ title: "Now", body: nowPrimary(NOW_SERIES), home: false, island: false }) +
            '<div class="gl-hinge"></div>' +
            screen({
                body: todayCard() + recentCard(NOW_SERIES, 6),
                tab: "now",
                verticalTabs: true,
                home: false,
                island: false, // the inner display's camera is under the screen
            }) +
            "</div>"
        );
    }
    function fold() {
        return (
            '<div class="gl-fold" role="img" aria-label="The iPhone Duo unfolding: folded, one column with a tab bar; unfolded, two panes along the fold">' +
            '<div class="gl-fold__dev">' +
            '<div class="gl-half gl-half--left">' +
            screen({ title: "Now", body: nowPrimary(NOW_SERIES), home: false, island: false }) +
            "</div>" +
            '<div class="gl-half gl-half--right"><div class="gl-screen" style="width:var(--gl-dev-w)">' +
            '<div class="gl-fold__layer gl-fold__solo">' +
            screen({ title: "Now", tab: "now", body: nowPrimary(NOW_SERIES) + todayCard() }).replace(
                'class="gl-screen"',
                'class="gl-screen" style="border-radius:inherit;width:100%;height:100%"',
            ) +
            "</div>" +
            '<div class="gl-fold__layer gl-fold__duo">' +
            screen({ body: todayCard() + recentCard(NOW_SERIES, 6), tab: "now", verticalTabs: true, home: false, island: false }).replace(
                'class="gl-screen"',
                'class="gl-screen" style="border-radius:inherit;width:100%;height:100%"',
            ) +
            "</div></div></div></div></div>" +
            '<div class="gl-fold__badge" aria-hidden="true"><span>Folded · compact</span><span>Unfolded · regular</span></div>'
        );
    }

    /* ---------- History ---------- */
    function historyPhone() {
        var vals = day(72, 5, 23, 44); // six hours to 9:41
        return phone(
            screen({
                title: "History",
                tab: "history",
                body:
                    '<div class="gl-seg"><span>3 h</span><span class="is-on">6 h</span><span>12 h</span><span>24 h</span></div>' +
                    '<div class="gl-ui-card" style="padding-top:1.9em">' +
                    chart(vals, { tall: true, dot: false, scrub: "8.4 mmol/L · 08:35", axis: [clock(-360), clock(-240), clock(-120), clock(0)] }) +
                    '<div style="height:1em"></div></div>' +
                    '<div class="gl-ui-card"><h5>Last 14 days</h5><div class="gl-rows">' +
                    '<div><span class="k">Average</span><span class="v">7.2 mmol/L</span></div>' +
                    '<div><span class="k">GMI</span><span class="v">6.4 %</span></div>' +
                    '<div><span class="k">Time in range</span><span class="v in">78%</span></div>' +
                    '<div><span class="k">Variability (CV)</span><span class="v">31 %</span></div>' +
                    "</div>" +
                    rangeBar([1, 3, 78, 14, 4]) +
                    "</div>",
            }),
            "The History tab: a scrollable chart with a window picker and a scrub callout, over 14-day statistics",
        );
    }
    function agp() {
        // percentile bands over a day, for the History page
        var n = 48,
            med = day(n, 30, 5, 0),
            p = function (k) {
                return med.map(function (v, i) {
                    return v + k * (0.8 + 0.6 * Math.sin(i / 5) * Math.sin(i / 5));
                });
            },
            band = function (a, b) {
                var top = a.map(function (v, i) {
                    return ((i / (n - 1)) * W).toFixed(1) + " " + y(v);
                });
                var bot = b
                    .map(function (v, i) {
                        return ((i / (n - 1)) * W).toFixed(1) + " " + y(v);
                    })
                    .reverse();
                return "M" + top.join("L") + "L" + bot.join("L") + "Z";
            };
        return (
            '<div class="gl-ui-card" style="max-width:26rem;margin:0 auto;font-family:-apple-system,system-ui,sans-serif;font-size:13px;text-align:left;box-shadow:0 0 0 1px var(--gl-line)">' +
            "<h5>Daily pattern (14 days)</h5>" +
            '<div class="gl-chart"><svg viewBox="0 0 300 150" preserveAspectRatio="none">' +
            '<rect class="band" x="0" width="300" y="' +
            y(TARGET.hi) +
            '" height="' +
            (y(TARGET.lo) - y(TARGET.hi)).toFixed(1) +
            '"/>' +
            '<path class="p95" d="' +
            band(p(2.3), p(-1.6)) +
            '"/><path class="p75" d="' +
            band(p(1), p(-0.8)) +
            '"/><path class="line line--draw" pathLength="1" d="' +
            linePath(med) +
            '"/></svg><div class="axis"><span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>24:00</span></div></div>' +
            '<div style="height:1.2em"></div></div>'
        );
    }

    /* ---------- Sensor ---------- */
    var PHASES = {
        streaming: { label: "Streaming", icon: "check", color: "var(--gl-ios-green)", paired: true },
        warming: { label: "Warming up, 38 min left", icon: "hourglass", color: "var(--gl-ios-blue)", paired: true },
        none: { label: "No sensor", icon: "sensor", color: "var(--gl-ios-secondary)", paired: false },
        lost: { label: "Signal lost", icon: "nosignal", color: "var(--gl-ios-orange)", paired: true },
    };
    function sensorPhone(phase) {
        var p = PHASES[phase] || PHASES.streaming;
        var status =
            '<div class="gl-ui-card"><div class="gl-ui-status" style="color:' +
            p.color +
            '">' +
            ICON[p.icon] +
            p.label +
            "</div>" +
            '<div class="gl-ui-btns"><span class="gl-ui-btn">' +
            ICON.nfc +
            (p.paired ? "Re-pair" : "Scan Sensor") +
            "</span>" +
            (p.paired ? '<span class="gl-ui-btn gl-ui-btn--plain">' + ICON.trash + "Remove</span>" : "") +
            "</div></div>";
        var wear = p.paired
            ? '<div class="gl-ui-card"><h5>Wear</h5><div class="gl-ui-sub" style="color:var(--gl-ios-fg)">' +
              (phase === "warming" ? "Day 1 of 15" : "Day 7 of 15") +
              '</div><div class="gl-progress" style="--p:' +
              (phase === "warming" ? "1%" : "41%") +
              '"><i></i></div><div class="gl-ui-sub">Ends Wednesday 18 November 14:20</div></div>'
            : "";
        var before =
            '<div class="gl-ui-card"><h5>Before you scan</h5><div class="gl-ui-sub" style="color:var(--gl-ios-fg)">Only one app can receive a sensor\'s Bluetooth readings. In Settings ▸ Apps ▸ LibreLink, turn off Bluetooth.</div></div>';
        var bt =
            '<div class="gl-ui-card"><h5>Bluetooth</h5><div class="gl-rows">' +
            '<div><span class="k">Link</span><span class="v">' +
            (phase === "lost" ? "Disconnected" : phase === "none" ? "Idle" : "Connected") +
            "</span></div>" +
            '<div><span class="k">Signal</span><span class="v">' +
            (phase === "streaming" || phase === "warming" ? "−62 dBm" : "–") +
            "</span></div>" +
            '<div><span class="k">Frames received</span><span class="v">8,412</span></div></div></div>';
        return phone(
            screen({ title: "Sensor", tab: "sensor", body: status + wear + before + bt }),
            "The Sensor tab: " + p.label,
        );
    }

    /* ---------- Settings (interactive) ---------- */
    function row(k, v) {
        return '<div><span>' + k + '</span><span class="gl-rows-v">' + v + "</span></div>";
    }
    function sw(on, target) {
        return (
            '<span class="gl-switch' +
            (on ? " is-on" : "") +
            '" role="switch" tabindex="0" aria-checked="' +
            on +
            '" data-gl-toggle' +
            (target ? '="' + target + '"' : "") +
            "></span>"
        );
    }
    function glucose(mgdl) {
        return '<b data-mgdl="' + mgdl + '" style="font-weight:500">' + f1(mgdl / MGDL) + " mmol/L</b>";
    }
    function stepper(mgdl) {
        return glucose(mgdl) + ' <span class="gl-stepper"><i>−</i><i>+</i></span>';
    }
    function alertRule(id, name, on, mgdl, snooze, rate) {
        return (
            "<div><span>" +
            name +
            "</span>" +
            sw(on, id) +
            "</div>" +
            '<div class="gl-collapse' +
            (on ? " is-open" : "") +
            '" id="' +
            id +
            '" style="padding:0;border:0"><div class="gl-rows" style="padding:0">' +
            (rate
                ? row("Faster than", '<b style="font-weight:500">0.1 mmol/L/min</b> <span class="gl-stepper"><i>−</i><i>+</i></span>')
                : row(name === "High" ? "Above" : "Below", stepper(mgdl))) +
            row("Snooze for", '<span class="gl-chev">' + snooze + " ⌃</span>") +
            "</div></div>"
        );
    }
    var uid = 0;
    function settingsPhone() {
        var p = "gl-s" + ++uid + "-";
        return phone(
            screen({
                title: "Settings",
                large: true,
                tab: "settings",
                body:
                    '<div class="gl-form">' +
                    "<h6>Display</h6>" +
                    '<div class="gl-rows">' +
                    '<div data-gl-units style="cursor:pointer"><span>Units</span><span class="gl-chev" data-unit>mmol/L ⌃</span></div>' +
                    row("Target low", stepper(70)) +
                    row("Target high", stepper(180)) +
                    "</div>" +
                    "<h6>Alerts</h6>" +
                    '<div class="gl-rows">' +
                    alertRule(p + "ul", "Urgent low", true, 55, "15 min") +
                    alertRule(p + "lo", "Low", true, 70, "30 min") +
                    alertRule(p + "hi", "High", true, 250, "1 h") +
                    alertRule(p + "ff", "Falling fast", false, 0, "30 min", true) +
                    alertRule(p + "rf", "Rising fast", false, 0, "30 min", true) +
                    "<div><span>No data for 20 min</span>" +
                    sw(true) +
                    "</div>" +
                    "</div>" +
                    '<p class="gl-foot">Alerts are time-sensitive and break through Focus.</p>' +
                    "<h6>Sharing</h6>" +
                    '<div class="gl-rows"><div><span>Save to Health</span>' +
                    sw(true) +
                    "</div><div><span>Live Activity</span>" +
                    sw(true) +
                    "</div></div>" +
                    "</div>",
            }),
            "The Settings tab: units, target range, alerts and sharing. Tap the switches and the units row to try them.",
        );
    }

    /* ---------- Lock Screen: an alert, a Live Activity ---------- */
    function lockAlert() {
        return phone(
            '<div class="gl-screen gl-lock"><div class="gl-island"></div>' +
                STATUS +
                '<div class="gl-lock__date">Sunday 8 November</div><div class="gl-lock__time">9:41</div>' +
                '<div style="height:1.4em"></div>' +
                '<div class="gl-notif gl-notif--in">' +
                '<span class="gl-notif__tag">TIME SENSITIVE</span>' +
                MARK("n" + ++uid) +
                "<b>Low</b><small>now</small><p>3.6 mmol/L, −0.1 mmol/L/min</p></div>" +
                '<div class="gl-notif__action">Snooze</div>' +
                '<div class="gl-homebar" style="background:#fff"></div></div>',
            "A low alert arriving on the Lock Screen, with its Snooze action",
        );
    }
    function lockLive() {
        var vals = NOW_SERIES.slice(-12);
        return phone(
            '<div class="gl-screen gl-lock"><div class="gl-island"></div>' +
                STATUS +
                '<div class="gl-lock__date">Sunday 8 November</div><div class="gl-lock__time">9:41</div>' +
                '<div style="flex:1"></div>' +
                '<div class="gl-notif gl-notif--in-2" style="grid-template-columns:auto 1fr;margin-bottom:3.4em;background:rgba(20,20,20,.55);color:#fff">' +
                '<div class="gl-value" data-level="inRange" style="font-size:2.3em;grid-row:span 2"><span>' +
                f1(vals[vals.length - 1]) +
                "</span>" +
                ICON.arrow.replace("<svg ", '<svg style="transform:rotate(-45deg)" ') +
                "</div>" +
                '<small style="justify-self:end;opacity:.75">+0.2 mmol/L · 1 min ago</small>' +
                '<div class="gl-di__spark" style="grid-column:2"><svg viewBox="0 0 300 150" preserveAspectRatio="none" width="100%" height="100%"><path d="' +
                linePath(vals) +
                '"/></svg></div></div>' +
                '<div class="gl-homebar" style="background:#fff"></div></div>',
            "The Live Activity on the Lock Screen: the latest reading, its trend and the last hour",
        );
    }
    function island() {
        var vals = NOW_SERIES.slice(-12);
        return (
            '<div class="gl-di" role="img" aria-label="The Live Activity in the Dynamic Island, compact and expanded">' +
            '<div class="gl-di__pill">' +
            '<div class="gl-di__compact"><span>' +
            f1(vals[vals.length - 1]) +
            "</span>" +
            ICON.arrow.replace("<svg ", '<svg style="transform:rotate(-45deg)" ') +
            "</div>" +
            '<div class="gl-di__expanded"><div class="gl-di__row"><div class="gl-value" data-level="inRange"><span>' +
            f1(vals[vals.length - 1]) +
            "</span>" +
            ICON.arrow.replace("<svg ", '<svg style="transform:rotate(-45deg)" ') +
            "</div><small>+0.2 mmol/L<br>1 min ago</small></div>" +
            '<div class="gl-di__spark"><svg viewBox="0 0 300 150" preserveAspectRatio="none" width="100%" height="100%"><path d="' +
            linePath(vals) +
            '"/></svg></div></div>' +
            "</div></div>"
        );
    }
    function widgets() {
        var vals = NOW_SERIES.slice(-36);
        var v = f1(vals[vals.length - 1]);
        var arrow = ICON.arrow.replace("<svg ", '<svg style="transform:rotate(-45deg)" ');
        return (
            '<div class="gl-widgets">' +
            '<div class="gl-widget gl-widget--s" role="img" aria-label="Small widget">' +
            '<small>Glucose</small><div class="gl-value" data-level="inRange"><span>' +
            v +
            "</span>" +
            arrow +
            "</div><small>1 min ago</small>" +
            chart(vals.slice(-12), { dot: false }) +
            "</div>" +
            '<div class="gl-widget gl-widget--m" role="img" aria-label="Medium widget">' +
            '<div style="display:flex;flex-direction:column;justify-content:space-between"><small>Glucose</small><div class="gl-value" data-level="inRange"><span>' +
            v +
            "</span>" +
            arrow +
            "</div><small>+0.2 mmol/L · 1 min ago</small></div>" +
            chart(vals.slice(-12), { dot: true }) +
            "</div>" +
            '<div class="gl-acc" role="img" aria-label="Lock Screen widgets: circular, rectangular and inline">' +
            '<div class="gl-acc__inline">' +
            v +
            " ↗ mmol/L</div>" +
            '<div style="display:flex;gap:.6rem;align-items:center"><div class="gl-acc__circ">' +
            v +
            arrow +
            '</div><div class="gl-acc__rect"><b>' +
            v +
            "</b> ↗ 1 min ago</div></div></div>" +
            "</div>"
        );
    }

    /* ---------- NFC scan ---------- */
    function scan() {
        return (
            '<div class="gl-scan" role="img" aria-label="Hold the top of the iPhone to the sensor until it says Sensor paired">' +
            '<span class="gl-scan__label">NFC · top edge to sensor</span>' +
            '<div class="gl-scan__arm"></div>' +
            '<span class="gl-scan__ripple"></span><span class="gl-scan__ripple"></span><span class="gl-scan__ripple"></span>' +
            '<div class="gl-scan__sensor"></div>' +
            '<div class="gl-scan__phone"><div class="gl-scan__screen">' +
            '<div class="gl-scan__sheet"><span class="gl-scan__glyph">' +
            ICON.nfc +
            "</span>" +
            '<span class="gl-scan__msg gl-scan__msg--hold">Hold the top of your iPhone near the sensor.</span>' +
            '<span class="gl-scan__msg gl-scan__msg--done">Sensor paired.</span>' +
            "</div></div></div></div>"
        );
    }

    /* ---------- lifecycle + pipeline figures ---------- */
    var LIFE = [
        ["sensor", "Start", "LibreLink or a Libre reader starts the sensor"],
        ["nfc", "Scan", "Glyph pairs over NFC and back-fills the last 8 hours"],
        ["hourglass", "Warm up", "Up to 60 minutes from the sensor's start; no readings stored"],
        ["radio", "Stream", "A reading over Bluetooth about every minute"],
        ["clock", "End", "After 14½ days (Libre 2) or 15½ (Libre 2 Plus)"],
    ];
    function lifecycle() {
        return (
            '<div class="gl-life" style="--n:' +
            LIFE.length +
            '" role="list">' +
            LIFE.map(function (s) {
                return (
                    '<div class="gl-life__step" role="listitem"><span class="gl-life__dot">' +
                    ICON[s[0]] +
                    "</span><b>" +
                    s[1] +
                    "</b><span>" +
                    s[2] +
                    "</span></div>"
                );
            }).join("") +
            "</div>"
        );
    }
    var FLOW = [
        ["Dedupe", "against stored readings by (serial, sensor age)"],
        ["Store", "in SwiftData"],
        ["Alert", "evaluate every rule"],
        ["Health", "write blood glucose"],
        ["Live Activity", "update the Lock Screen and Dynamic Island"],
        ["Widgets", "refresh, at most every 5 min"],
    ];
    function pipeline() {
        return (
            '<div class="gl-flow" role="list"><span class="gl-flow__pulse"></span>' +
            FLOW.map(function (s, i) {
                return (
                    '<div role="listitem" style="--i:' + i + '"><em>' + (i + 1) + "</em><b>" + s[0] + "</b>" + s[1] + "</div>"
                );
            }).join("") +
            "</div>"
        );
    }

    /* the app icon, for notifications (same geometry as partials/glyph-mark.html) */
    var MARK_D = null;
    function MARK(id) {
        if (MARK_D === null) {
            var src = document.querySelector(".gl-mark__wave");
            MARK_D = src ? src.getAttribute("d") : "";
        }
        return (
            '<svg class="gl-mark" viewBox="0 0 1024 1024" aria-hidden="true"><defs><linearGradient id="' +
            id +
            '" x1="0" x2="1024" y1="0" y2="0" gradientUnits="userSpaceOnUse"><stop offset="0" style="stop-color:var(--gl-icon-wave-0)"/><stop offset="1" style="stop-color:var(--gl-icon-wave-1)"/></linearGradient></defs>' +
            '<rect class="gl-mark__bg" width="1024" height="1024"/><circle class="gl-mark__base" cx="512" cy="512" r="300"/><circle class="gl-mark__face" cx="512" cy="512" r="244"/>' +
            '<path d="' +
            MARK_D +
            '" fill="none" stroke="url(#' +
            id +
            ')" stroke-width="40" stroke-linecap="round"/><circle class="gl-mark__reading" cx="512" cy="512" r="42"/></svg>'
        );
    }

    var MOCKS = {
        now: nowPhone,
        duo: duo,
        fold: fold,
        history: historyPhone,
        agp: agp,
        sensor: sensorPhone,
        settings: settingsPhone,
        "lock-alert": lockAlert,
        "lock-live": lockLive,
        island: island,
        widgets: widgets,
        scan: scan,
        lifecycle: lifecycle,
        pipeline: pipeline,
    };

    /* ---------- behaviour ---------- */

    // The simulated sensor: every few seconds ("a minute") a new value joins
    // the series, and the value, arrow, delta, chart, recent rows and the
    // range share follow it.
    function live(host) {
        var vals = NOW_SERIES.slice();
        var r = rng(99);
        var drift = 0.03;
        var minute = 0;
        function tick() {
            var last = vals[vals.length - 1];
            // a gentle random walk that stays in a believable band
            drift += (r() - 0.5) * 0.06 - (last - 7) * 0.004;
            drift = Math.max(-0.22, Math.min(0.22, drift));
            var v = Math.max(3.2, Math.min(12.5, last + drift));
            vals.push(v);
            vals.shift();
            minute++;
            render(v, ((v - last) * MGDL) / 1);
        }
        function render(v, rate) {
            host.querySelectorAll(".gl-value").forEach(function (node) {
                if (!node.querySelector("[data-v]")) return;
                node.querySelector("[data-v]").textContent = f1(v);
                node.setAttribute("data-level", level(v));
                var a = node.querySelector(".gl-arrow");
                if (a) a.style.transform = "rotate(" + trend(rate).deg + "deg)";
                node.classList.remove("is-tick");
                void node.offsetWidth;
                node.classList.add("is-tick");
            });
            host.querySelectorAll("[data-delta]").forEach(function (d) {
                d.textContent = (rate >= 0 ? "+" : "−") + f1(Math.abs(rate) / MGDL);
            });
            host.querySelectorAll(".gl-chart .line").forEach(function (p) {
                p.classList.remove("line--draw");
                p.removeAttribute("pathLength");
                p.setAttribute("d", linePath(vals));
            });
            host.querySelectorAll(".gl-chart .now").forEach(function (c) {
                c.setAttribute("cy", y(v));
            });
            host.querySelectorAll("[data-rows]").forEach(function (list) {
                var rowEl = el(
                    '<div class="new"><span class="k">' +
                        clock(minute) +
                        '</span><span class="v ' +
                        cls(v) +
                        '">' +
                        f1(v) +
                        "</span></div>",
                );
                list.insertBefore(rowEl, list.firstChild);
                if (list.children.length > 6) list.removeChild(list.lastChild);
            });
        }
        if (!reduced) timers.push(window.setInterval(tick, 3500));
    }

    // The lifecycle figure walks one phase every 1.6 s, rests, then restarts.
    function stepLife(fig) {
        var steps = fig.querySelectorAll(".gl-life__step");
        var n = steps.length;
        var i = 0;
        function show() {
            fig.setAttribute("data-step", i);
            fig.style.setProperty("--p", n > 1 ? Math.min(i, n - 1) / (n - 1) : 1);
            steps.forEach(function (s, k) {
                s.classList.toggle("is-on", k <= i);
                s.classList.toggle("is-now", k === i);
            });
        }
        if (reduced) {
            i = n - 1;
            show();
            return;
        }
        show();
        timers.push(
            window.setInterval(function () {
                i = i >= n + 1 ? 0 : i + 1; // two beats of rest on the last step
                if (i <= n - 1 || i === 0) show();
            }, 1600),
        );
    }

    // Settings mockup: switches open their rule's rows; Units flips the
    // glucose values between mmol/L and mg/dL.
    function wireSettings(host) {
        host.addEventListener("click", function (e) {
            var s = e.target.closest("[data-gl-toggle]");
            if (s) {
                var on = !s.classList.contains("is-on");
                s.classList.toggle("is-on", on);
                s.setAttribute("aria-checked", on);
                var id = s.getAttribute("data-gl-toggle");
                var target = id && document.getElementById(id);
                if (target) target.classList.toggle("is-open", on);
                return;
            }
            var u = e.target.closest("[data-gl-units]");
            if (u) {
                var mg = host.getAttribute("data-unit") !== "mgdl";
                host.setAttribute("data-unit", mg ? "mgdl" : "mmol");
                u.querySelector("[data-unit]").textContent = (mg ? "mg/dL" : "mmol/L") + " ⌃";
                host.querySelectorAll("[data-mgdl]").forEach(function (b) {
                    var x = +b.getAttribute("data-mgdl");
                    b.textContent = mg ? Math.round(x) + " mg/dL" : f1(x / MGDL) + " mmol/L";
                });
            }
        });
        host.addEventListener("keydown", function (e) {
            if ((e.key === " " || e.key === "Enter") && e.target.matches("[data-gl-toggle]")) {
                e.preventDefault();
                e.target.click();
            }
        });
    }

    function reveal(scope) {
        var nodes = scope.querySelectorAll(".gl-reveal");
        if (!("IntersectionObserver" in window) || reduced) {
            nodes.forEach(function (n) {
                n.classList.add("is-in");
            });
            return;
        }
        var io = new IntersectionObserver(
            function (entries) {
                entries.forEach(function (e) {
                    if (e.isIntersecting) {
                        e.target.classList.add("is-in");
                        io.unobserve(e.target);
                    }
                });
            },
            { rootMargin: "0px 0px -8% 0px" },
        );
        nodes.forEach(function (n) {
            io.observe(n);
        });
        observers.push(io);
    }

    // Landing-page copy buttons (the rows reuse zensical's .md-code__button).
    document.addEventListener("click", function (e) {
        var btn = e.target.closest(".gl-copy .md-code__button");
        if (!btn) return;
        var code = btn.closest(".gl-copy").querySelector("code");
        if (!code || !navigator.clipboard) return;
        navigator.clipboard.writeText(code.textContent.trim()).then(function () {
            var dialog = document.querySelector("[data-md-component=dialog]");
            if (!dialog) return;
            (dialog.querySelector(".md-dialog__inner") || dialog).textContent = "Copied to clipboard";
            dialog.classList.add("md-dialog--active");
            window.clearTimeout(dialog.glTimer);
            dialog.glTimer = window.setTimeout(function () {
                dialog.classList.remove("md-dialog--active");
            }, 2000);
        });
    });

    function init() {
        timers.forEach(window.clearInterval);
        timers = [];
        observers.forEach(function (o) {
            o.disconnect();
        });
        observers = [];
        MARK_D = null;

        document.querySelectorAll("[data-gl-mock]").forEach(function (host) {
            var kind = host.getAttribute("data-gl-mock");
            var make = MOCKS[kind];
            if (!make) return;
            host.innerHTML = make(host.getAttribute("data-phase"));
            if ((kind === "now" || kind === "duo" || kind === "fold") && host.getAttribute("data-live") !== "false") live(host);
            if (kind === "settings") wireSettings(host);
            if (kind === "lifecycle") stepLife(host.querySelector(".gl-life"));
        });
        reveal(document);
    }

    if (window.document$ && typeof window.document$.subscribe === "function") {
        window.document$.subscribe(init);
    } else if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
