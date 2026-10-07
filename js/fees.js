const Fee = {
  inr: n => new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(n || 0)),
  today: () => new Date().toLocaleDateString("en-CA"),
  status(f) { if (f.status === "paid" || f.status === "waived") return f.status; return f.due_date < Fee.today() ? "overdue" : f.status; },
  label: s => String(s).replace("_", " "),
  addMonths(d, n) { const [y, m, day] = d.split("-").map(Number); return new Date(Date.UTC(y, m - 1 + n, day)).toISOString().slice(0, 10); },
  name: s => [s.first_name, s.last_name].filter(Boolean).join(" "),
  MANAGE: ["super_admin", "school_admin", "accountant"], APPROVE: ["super_admin", "school_admin", "principal"],
  err(e) { const m = String(e?.message || ""); if (m.includes("exceeds balance")) return "The amount is more than the balance due.";
    if (m.includes("concession exceeds")) return "The concession is more than the unpaid amount."; if (e?.code === "23505") return "A payment with this reference already exists."; return "Could not save. Please check the details and try again."; }
};
