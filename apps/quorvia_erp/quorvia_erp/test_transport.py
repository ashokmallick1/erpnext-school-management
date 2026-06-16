import frappe

def run():
    frappe.flags.in_test = True
    
    # Create Vehicle
    if not frappe.db.exists("Vehicle", {"license_plate": "QRV-BUS-01"}):
        vehicle = frappe.get_doc({
            "doctype": "Vehicle",
            "vehicle_name": "School Bus 01",
            "license_plate": "QRV-BUS-01",
            "make": "Volvo",
            "model": "B11R",
            "last_odometer": 0,
            "uom": "Km"
        }).insert(ignore_permissions=True)
    else:
        vehicle = frappe.get_doc("Vehicle", {"license_plate": "QRV-BUS-01"})
        
    # Create Route
    if not frappe.db.exists("Transport Route", {"route_name": "North City Loop"}):
        route = frappe.get_doc({
            "doctype": "Transport Route",
            "route_name": "North City Loop",
            "vehicle": vehicle.name,
            "stops": [
                {"stop_name": "Oak Street", "pickup_time": "07:00:00", "drop_time": "15:30:00", "monthly_fee": 50},
                {"stop_name": "Pine Avenue", "pickup_time": "07:15:00", "drop_time": "15:45:00", "monthly_fee": 45},
                {"stop_name": "Maple Drive", "pickup_time": "07:30:00", "drop_time": "16:00:00", "monthly_fee": 40}
            ]
        }).insert(ignore_permissions=True)
    else:
        route = frappe.get_doc("Transport Route", {"route_name": "North City Loop"})
        
    # Create Subscription for test student (if exists)
    student = frappe.get_all("Student", limit=1)
    if student:
        student_id = student[0].name
        if not frappe.db.exists("Transport Subscription", {"student": student_id}):
            frappe.get_doc({
                "doctype": "Transport Subscription",
                "student": student_id,
                "route": route.name,
                "monthly_fee": route.stops[0].monthly_fee
            }).insert(ignore_permissions=True)
            
    frappe.db.commit()
    print("Transport test data generated.")

if __name__ == '__main__':
    run()
