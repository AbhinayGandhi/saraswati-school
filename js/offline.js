/* Offline support for attendance: keeps a copy of rosters on this phone and queues attendance saved without internet.
   Queued rows are sent when the connection returns. Row Level Security still decides on the server whether each row is allowed. */
const Offline = {
  K: "ses_c_", Q: "ses_att_q", F: "ses_att_fail",
  isNet(e) { const m = String((e && (e.message || e.details)) || e || ""); return navigator.onLine === false || /failed to fetch|networkerror|network request failed|load failed|fetch failed|timeout/i.test(m); },
  get(k) { try { return JSON.parse(localStorage.getItem(Offline.K + k)); } catch (e) { return null; } },
  set(k, v) { try { localStorage.setItem(Offline.K + k, JSON.stringify(v)); } catch (e) { } },
  clear() { try { Object.keys(localStorage).filter(k => k.indexOf(Offline.K) === 0).forEach(k => localStorage.removeItem(k)); } catch (e) { } },
  queue() { try { const q = JSON.parse(localStorage.getItem(Offline.Q)); return Array.isArray(q) ? q : []; } catch (e) { return []; } },
  _save(q) { try { localStorage.setItem(Offline.Q, JSON.stringify(q)); } catch (e) { } },
  pending() { return Offline.queue().length; },
  // Newest write for the same student and date wins.
  add(rows) { const m = new Map(Offline.queue().map(r => [r.enrollment_id + "|" + r.att_date, r])); const t = Date.now(); rows.forEach(r => m.set(r.enrollment_id + "|" + r.att_date, { enrollment_id: r.enrollment_id, att_date: r.att_date, status: r.status, t })); Offline._save([...m.values()]); },
  queuedFor(date) { const o = {}; Offline.queue().filter(r => r.att_date === date).forEach(r => o[r.enrollment_id] = r.status); return o; },
  failed() { try { return JSON.parse(localStorage.getItem(Offline.F)) || []; } catch (e) { return []; } },
  _busy: false,
  // Sends the queue. Network trouble keeps rows queued; rows the server refuses (holiday, no permission) are moved to the "failed" list.
  async sync() {
    if (Offline._busy || !Offline.pending() || navigator.onLine === false) return { sent: 0, failed: 0, left: Offline.pending() };
    Offline._busy = true; let sent = 0, failed = [];
    try {
      const q = Offline.queue(), keyOf = r => r.enrollment_id + "|" + r.att_date, rest = new Map(q.map(r => [keyOf(r), r]));
      for (let i = 0; i < q.length; i += 100) {
        const chunk = q.slice(i, i + 100), body = chunk.map(r => ({ enrollment_id: r.enrollment_id, att_date: r.att_date, status: r.status }));
        let { error } = await db.from("attendance").upsert(body, { onConflict: "enrollment_id,att_date" });
        if (error && Offline.isNet(error)) break;
        if (error) { // find the refused rows one by one
          for (const r of chunk) {
            const res = await db.from("attendance").upsert([{ enrollment_id: r.enrollment_id, att_date: r.att_date, status: r.status }], { onConflict: "enrollment_id,att_date" });
            if (!res.error) { sent++; rest.delete(keyOf(r)); } else if (Offline.isNet(res.error)) { Offline._save([...rest.values()]); return { sent, failed: failed.length, left: rest.size }; }
            else { failed.push({ ...r, why: String(res.error.message || "refused").slice(0, 120) }); rest.delete(keyOf(r)); }
          }
        } else { sent += chunk.length; chunk.forEach(r => rest.delete(keyOf(r))); }
        Offline._save([...rest.values()]);
      }
      if (failed.length) { try { localStorage.setItem(Offline.F, JSON.stringify([...Offline.failed(), ...failed].slice(-200))); } catch (e) { } }
      return { sent, failed: failed.length, left: rest.size };
    } finally { Offline._busy = false; }
  },
  // Status strip: shows offline state, number waiting, and a Sync now button. onSynced runs after rows were sent.
  banner(el, onSynced) {
    const draw = () => {
      const n = Offline.pending(), off = navigator.onLine === false, bad = Offline.failed().length; el.innerHTML = "";
      if (!off && !n && !bad) return;
      const d = document.createElement("div"); d.className = "state" + (bad ? " error" : ""); d.setAttribute("role", "status");
      let t = off ? "You are offline. Attendance you save is kept on this phone and sent automatically when the internet returns." : "";
      if (n) t += (t ? " " : "") + n + " attendance record" + (n > 1 ? "s" : "") + " waiting to be sent.";
      if (bad) t += (t ? " " : "") + bad + " record" + (bad > 1 ? "s were" : " was") + " refused by the server (for example a holiday) and not saved.";
      d.append(t + " ");
      if (n && !off) { const b = document.createElement("button"); b.type = "button"; b.className = "btn ghost"; b.textContent = "Sync now"; b.onclick = go; d.appendChild(b); }
      if (bad) { const b = document.createElement("button"); b.type = "button"; b.className = "btn ghost"; b.textContent = "Dismiss"; b.onclick = () => { try { localStorage.removeItem(Offline.F); } catch (e) { } draw(); }; d.appendChild(b); }
      el.appendChild(d);
    };
    const go = async () => { const r = await Offline.sync(); draw(); if (r.sent) { if (window.U) U.toast("Sent " + r.sent + " attendance record" + (r.sent > 1 ? "s" : "") + "."); if (onSynced) onSynced(r); } };
    window.addEventListener("online", go); window.addEventListener("offline", draw); draw(); if (Offline.pending() && navigator.onLine !== false) go();
    return { draw, go };
  }
};
