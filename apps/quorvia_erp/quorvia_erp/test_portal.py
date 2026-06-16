import frappe
from frappe.utils import today, add_days

def run():
    frappe.flags.in_test = True
    
    # 1. Create a Test User (Parent)
    user_email = "parent@quorvia.test"
    if not frappe.db.exists("User", user_email):
        user = frappe.get_doc({
            "doctype": "User",
            "email": user_email,
            "first_name": "Test",
            "last_name": "Parent",
            "send_welcome_email": 0,
            "roles": [{"role": "Parent"}, {"role": "Student Portal User"}]
        }).insert(ignore_permissions=True)
        # Set password
        frappe.utils.password.update_password(user_email, "Quorvia@123")
    
    # 2. Create Guardian
    if not frappe.db.exists("Guardian", "Guard-001"):
        guardian = frappe.get_doc({
            "doctype": "Guardian",
            "guardian_name": "Test Parent",
            "email_address": user_email,
            "mobile_number": "1234567890"
        }).insert(ignore_permissions=True)
    else:
        guardian = frappe.get_doc("Guardian", "Guard-001")
        
    # 3. Create Student
    if not frappe.db.exists("Student", "EDU-STU-2026-00001"):
        student = frappe.get_doc({
            "doctype": "Student",
            "first_name": "John",
            "last_name": "Doe",
            "student_email_id": "john@quorvia.test",
            "joining_date": today(),
            "guardians": [{
                "guardian": guardian.name,
                "relation": "Father"
            }]
        }).insert(ignore_permissions=True)
    else:
        student = frappe.get_doc("Student", "EDU-STU-2026-00001")
        
    # 4. Create Student Attendance
    for i in range(5):
        date = add_days(today(), -i)
        if not frappe.db.exists("Student Attendance", {"student": student.name, "date": date}):
            frappe.get_doc({
                "doctype": "Student Attendance",
                "student": student.name,
                "date": date,
                "status": "Present"
            }).insert(ignore_permissions=True)
            
    # 5. Create Assessment Result
    if not frappe.db.exists("Assessment Result", {"student": student.name}):
        # Mocking an assessment result might require Assessment Plan and Student Group.
        # So we just mock a Sales Invoice for Fees instead to avoid deep setup.
        pass
        
    # 6. Create Sales Invoice (Fees)
    if not frappe.db.exists("Sales Invoice", {"student": student.name}):
        # We need an item and customer
        if not frappe.db.exists("Customer", "Test Parent"):
            frappe.get_doc({
                "doctype": "Customer",
                "customer_name": "Test Parent",
                "customer_group": "All Customer Groups",
                "territory": "All Territories"
            }).insert(ignore_permissions=True)
            
        if not frappe.db.exists("Item", "Tuition Fee"):
            frappe.get_doc({
                "doctype": "Item",
                "item_code": "Tuition Fee",
                "item_name": "Tuition Fee",
                "item_group": "All Item Groups",
                "is_stock_item": 0
            }).insert(ignore_permissions=True)
            
        inv = frappe.get_doc({
            "doctype": "Sales Invoice",
            "customer": "Test Parent",
            "student": student.name,
            "items": [{
                "item_code": "Tuition Fee",
                "qty": 1,
                "rate": 5000
            }],
            "set_posting_time": 1
        }).insert(ignore_permissions=True)
        inv.submit()

    frappe.db.commit()
    print("Test data generation complete.")

if __name__ == '__main__':
    frappe.init(site='school.localhost')
    frappe.connect()
    run()
