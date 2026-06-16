import frappe
from frappe.utils import today

def run():
    frappe.flags.in_test = True
    
    # Create Hostel Block
    if not frappe.db.exists("Hostel Block", {"block_name": "North Wing"}):
        block = frappe.get_doc({
            "doctype": "Hostel Block",
            "block_name": "North Wing",
            "gender_policy": "Boys"
        }).insert(ignore_permissions=True)
    else:
        block = frappe.get_doc("Hostel Block", {"block_name": "North Wing"})
        
    # Create Hostel Room
    if not frappe.db.exists("Hostel Room", {"room_number": "101A"}):
        room = frappe.get_doc({
            "doctype": "Hostel Room",
            "room_number": "101A",
            "hostel_block": block.name,
            "floor": "1",
            "capacity": 2,
            "monthly_fee": 200
        }).insert(ignore_permissions=True)
    else:
        room = frappe.get_doc("Hostel Room", {"room_number": "101A"})
        
    # Create Allocation for test student (if exists)
    student = frappe.get_all("Student", limit=1)
    if student:
        student_id = student[0].name
        if not frappe.db.exists("Hostel Allocation", {"student": student_id}):
            frappe.get_doc({
                "doctype": "Hostel Allocation",
                "student": student_id,
                "room": room.name,
                "allocation_date": today(),
                "status": "Active"
            }).insert(ignore_permissions=True)
            
    frappe.db.commit()
    print("Hostel test data generated.")

if __name__ == '__main__':
    run()
