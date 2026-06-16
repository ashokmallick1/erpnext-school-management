import frappe
import json

def get_state():
    state = {
        "Academic Year": frappe.get_all("Academic Year", pluck="name"),
        "Academic Term": frappe.get_all("Academic Term", pluck="name"),
        "Program": frappe.get_all("Program", pluck="name"),
        "Course": frappe.get_all("Course", pluck="name"),
        "Student": frappe.get_all("Student", pluck="name"),
        "Instructor": frappe.get_all("Instructor", pluck="name"),
        "Student Group": frappe.get_all("Student Group", pluck="name"),
        "Fee Category": frappe.get_all("Fee Category", pluck="name"),
        "Fee Structure": frappe.get_all("Fee Structure", pluck="name"),
        "Company": frappe.get_all("Company", pluck="name")
    }
    print("AUDIT_RESULT=" + json.dumps(state))

