import frappe

def create_doctype(name, module, is_submittable=0, istable=0, naming_rule="Expression", autoname=None, fields=None):
    if frappe.db.exists("DocType", name):
        print(f"DocType {name} already exists.")
        return

    doc = frappe.get_doc({
        "doctype": "DocType",
        "name": name,
        "module": module,
        "custom": 1,
        "is_submittable": is_submittable,
        "istable": istable,
        "naming_rule": naming_rule,
        "autoname": autoname,
        "fields": fields or []
    })
    doc.insert(ignore_permissions=True)
    print(f"Created DocType: {name}")

def run():
    frappe.flags.in_test = True
    module = "Quorvia Erp"

    # 1. Hostel Block
    create_doctype(
        name="Hostel Block",
        module=module,
        naming_rule="Expression",
        autoname="format:HST-BLK-{YYYY}-{####}",
        fields=[
            {"fieldname": "block_name", "fieldtype": "Data", "label": "Block Name", "reqd": 1, "in_list_view": 1},
            {"fieldname": "gender_policy", "fieldtype": "Select", "options": "Boys\nGirls\nCo-ed", "label": "Gender Policy", "in_list_view": 1},
            {"fieldname": "warden", "fieldtype": "Link", "options": "Employee", "label": "Warden", "in_list_view": 1}
        ]
    )

    # 2. Hostel Room
    create_doctype(
        name="Hostel Room",
        module=module,
        naming_rule="Expression",
        autoname="format:HST-RM-{YYYY}-{####}",
        fields=[
            {"fieldname": "room_number", "fieldtype": "Data", "label": "Room Number", "reqd": 1, "in_list_view": 1},
            {"fieldname": "hostel_block", "fieldtype": "Link", "options": "Hostel Block", "label": "Hostel Block", "reqd": 1, "in_list_view": 1},
            {"fieldname": "floor", "fieldtype": "Data", "label": "Floor"},
            {"fieldname": "capacity", "fieldtype": "Int", "label": "Capacity", "reqd": 1, "in_list_view": 1},
            {"fieldname": "monthly_fee", "fieldtype": "Currency", "label": "Monthly Fee", "reqd": 1}
        ]
    )

    # 3. Hostel Allocation
    create_doctype(
        name="Hostel Allocation",
        module=module,
        naming_rule="Expression",
        autoname="format:HST-ALC-{YYYY}-{####}",
        is_submittable=1,
        fields=[
            {"fieldname": "student", "fieldtype": "Link", "options": "Student", "label": "Student", "reqd": 1, "in_list_view": 1},
            {"fieldname": "academic_year", "fieldtype": "Link", "options": "Academic Year", "label": "Academic Year"},
            {"fieldname": "room", "fieldtype": "Link", "options": "Hostel Room", "label": "Room", "reqd": 1, "in_list_view": 1},
            {"fieldname": "allocation_date", "fieldtype": "Date", "label": "Allocation Date", "reqd": 1},
            {"fieldname": "status", "fieldtype": "Select", "options": "Active\nVacated", "label": "Status", "default": "Active", "in_list_view": 1}
        ]
    )

    frappe.db.commit()
    print("Hostel Module DocTypes setup successfully.")

if __name__ == '__main__':
    run()
