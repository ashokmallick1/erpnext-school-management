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

    # 1. Vehicle
    create_doctype(
        name="Vehicle",
        module=module,
        naming_rule="Expression",
        autoname="format:TRN-VEH-{YYYY}-{####}",
        fields=[
            {"fieldname": "vehicle_name", "fieldtype": "Data", "label": "Vehicle Name", "reqd": 1, "in_list_view": 1},
            {"fieldname": "license_plate", "fieldtype": "Data", "label": "License Plate", "reqd": 1, "unique": 1, "in_list_view": 1},
            {"fieldname": "capacity", "fieldtype": "Int", "label": "Capacity", "reqd": 1},
            {"fieldname": "driver_name", "fieldtype": "Data", "label": "Driver Name"},
            {"fieldname": "driver_phone", "fieldtype": "Data", "label": "Driver Phone"}
        ]
    )

    # 2. Transport Stop (Child Table)
    create_doctype(
        name="Transport Stop",
        module=module,
        istable=1,
        naming_rule="Random",
        fields=[
            {"fieldname": "stop_name", "fieldtype": "Data", "label": "Stop Name", "reqd": 1, "in_list_view": 1},
            {"fieldname": "pickup_time", "fieldtype": "Time", "label": "Pickup Time", "in_list_view": 1},
            {"fieldname": "drop_time", "fieldtype": "Time", "label": "Drop Time", "in_list_view": 1},
            {"fieldname": "monthly_fee", "fieldtype": "Currency", "label": "Monthly Fee", "reqd": 1, "in_list_view": 1}
        ]
    )

    # 3. Transport Route
    create_doctype(
        name="Transport Route",
        module=module,
        naming_rule="Expression",
        autoname="format:TRN-RTE-{YYYY}-{####}",
        fields=[
            {"fieldname": "route_name", "fieldtype": "Data", "label": "Route Name", "reqd": 1, "in_list_view": 1},
            {"fieldname": "vehicle", "fieldtype": "Link", "options": "Vehicle", "label": "Vehicle", "reqd": 1, "in_list_view": 1},
            {"fieldname": "stops", "fieldtype": "Table", "options": "Transport Stop", "label": "Stops", "reqd": 1}
        ]
    )

    # 4. Transport Subscription
    create_doctype(
        name="Transport Subscription",
        module=module,
        naming_rule="Expression",
        autoname="format:TRN-SUB-{YYYY}-{####}",
        is_submittable=1,
        fields=[
            {"fieldname": "student", "fieldtype": "Link", "options": "Student", "label": "Student", "reqd": 1, "in_list_view": 1},
            {"fieldname": "route", "fieldtype": "Link", "options": "Transport Route", "label": "Route", "reqd": 1, "in_list_view": 1},
            {"fieldname": "monthly_fee", "fieldtype": "Currency", "label": "Monthly Fee", "reqd": 1, "in_list_view": 1}
        ]
    )

    frappe.db.commit()
    print("Transport Module DocTypes setup successfully.")

if __name__ == '__main__':
    run()
