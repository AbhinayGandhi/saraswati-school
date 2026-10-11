# Test checklist (about 45 minutes before launch)

Use real test accounts: create them on **Users and roles** and set them inactive afterwards.

| Role | Must be able to | Must NOT be able to |
|---|---|---|
| Parent | see own child's attendance, published results, fees, receipts, notices | see another child, unpublished marks, other parents' details, admin menus |
| Student | see own timetable, homework, results | see fees of others, staff data |
| Teacher | mark attendance for own divisions, enter marks for own subjects | open other divisions, fees, settings, audit logs |
| Class teacher | all of the teacher, plus own division's students | change settings, promote students |
| Accountant | take payments, concessions, fee reports | marks, attendance, settings |
| Reception | admissions, students (add/edit), link parents, front desk | fees, marks |
| Librarian | issue and return books, fines | students' marks or fees |
| Principal | view everything, reports | change settings or roles |
| School Admin / Super Admin | everything; only Super Admin can open Backup | -- |

Flow tests
1. Admission form (not signed in) creates an enquiry; convert it to a student.
2. Assign a total fee, pay in two parts, check balance and receipt number prefix.
3. Mark attendance; try a holiday and a weekly off day (must refuse); add a Special school day and mark again.
4. Create an exam, enter marks, submit, publish; check the parent sees it only after publishing.
5. Promote one student, repeat one, mark one alumni; check the old year still shows the old class.
6. Close the year; confirm old reports still work.
7. Change a setting; find it in Audit logs.
8. Print a report and a receipt on A4; export CSV and open it in Excel with Marathi text.
9. Phone check: open 5 pages on a phone; no sideways scrolling of the whole page.
