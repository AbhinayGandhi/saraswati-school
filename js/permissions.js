// Frontend checks are for convenience only. Real enforcement is Row Level Security in schema.sql.
const ADMIN_ROLES = ["super_admin", "school_admin", "principal"];
const NAV = [
  { href: "dashboard.html", label: "Dashboard", roles: "*" },
  { href: "academic-years.html", label: "Academic years", roles: ADMIN_ROLES },
  { href: "classes.html", label: "Classes and divisions", roles: ADMIN_ROLES },
  { href: "subjects.html", label: "Subjects", roles: ADMIN_ROLES },
  { href: "teachers.html", label: "Teachers", roles: ADMIN_ROLES },
  { href: "staff.html", label: "Staff", roles: ADMIN_ROLES },
  { href: "attendance.html", label: "Attendance", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "calendar.html", label: "School calendar", roles: ADMIN_ROLES },
  { href: "assign-subjects.html", label: "Subject teachers", roles: ADMIN_ROLES },
  { href: "exams.html", label: "Exams", roles: ADMIN_ROLES },
  { href: "marks.html", label: "Marks entry", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "results.html", label: "Results", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "timetable.html", label: "Timetable", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "homework.html", label: "Homework", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "notices.html", label: "Notices", roles: "*" },
  { href: "notifications.html", label: "Notifications", roles: "*" },
  { href: "events.html", label: "Events", roles: "*" },
  { href: "activities.html", label: "Activities", roles: [...ADMIN_ROLES, "teacher", "class_teacher"] },
  { href: "achievements.html", label: "Achievements", roles: [...ADMIN_ROLES, "reception", "teacher", "class_teacher"] },
  { href: "gallery.html", label: "Gallery", roles: "*" },
  { href: "students.html", label: "Students", roles: [...ADMIN_ROLES, "teacher", "class_teacher", "reception"] },
  { href: "fees.html", label: "Fees and payments", roles: [...ADMIN_ROLES, "accountant"] },
  { href: "fee-types.html", label: "Fee types", roles: ADMIN_ROLES },
  { href: "fee-structure.html", label: "Fee structure", roles: [...ADMIN_ROLES, "accountant"] },
  { href: "fee-check.html", label: "Fee check", roles: [...ADMIN_ROLES, "accountant"] },
  { href: "fee-reports.html", label: "Fee reports", roles: [...ADMIN_ROLES, "accountant"] },
  { href: "users.html", label: "Users and roles", roles: ["super_admin", "school_admin"] },
  { href: "audit-logs.html", label: "Audit logs", roles: ["super_admin", "school_admin"] }
];
const Perm = {
  isAdmin: r => ADMIN_ROLES.includes(r),
  can: (role, roles) => roles === "*" || roles.includes(role),
  navFor: role => NAV.filter(n => Perm.can(role, n.roles))
};
