import frappe

def create_student_groups():
    programs = frappe.get_all("Program", pluck="name")
    academic_term = "2026-2027 (Term 1 2026-2027)"
    academic_year = "2026-2027"

    for p in programs:
        group_name = f"{p} - Section A"
        if not frappe.db.exists("Student Group", {"student_group_name": group_name}):
            doc = frappe.new_doc("Student Group")
            doc.student_group_name = group_name
            doc.program = p
            doc.academic_term = academic_term
            doc.academic_year = academic_year
            doc.group_based_on = "Batch"
            doc.insert(ignore_permissions=True)
    frappe.db.commit()

def create_instructors():
    company = frappe.get_doc("Company", "My School")
    abbr = company.abbr
    instructors = [
        {"instructor_name": "John Doe", "department": "Science"},
        {"instructor_name": "Jane Smith", "department": "Mathematics"},
        {"instructor_name": "Alice Johnson", "department": "English"},
        {"instructor_name": "Bob Williams", "department": "Computer Science"}
    ]
    for ins in instructors:
        dept_name = f"{ins['department']} - {abbr}"
        if not frappe.db.exists("Department", dept_name):
            doc = frappe.new_doc("Department")
            doc.department_name = ins["department"]
            doc.company = company.name
            if frappe.db.exists("Department", f"All Departments - {abbr}"):
                doc.parent_department = f"All Departments - {abbr}"
            doc.insert(ignore_permissions=True)
            
        if not frappe.db.exists("Instructor", {"instructor_name": ins["instructor_name"]}):
            doc = frappe.new_doc("Instructor")
            doc.instructor_name = ins["instructor_name"]
            doc.department = dept_name
            doc.insert(ignore_permissions=True)
    frappe.db.commit()

def create_assessment_criteria():
    criteria = ["Mid Term", "Finals", "Assignments", "Attendance"]
    for c in criteria:
        if not frappe.db.exists("Assessment Criteria", c):
            doc = frappe.new_doc("Assessment Criteria")
            doc.assessment_criteria = c
            doc.insert(ignore_permissions=True)
    frappe.db.commit()

def run_setup():
    create_student_groups()
    create_instructors()
    create_assessment_criteria()
    print("PHASE3_COMPLETE")
