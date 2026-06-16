import frappe

def run():
    frappe.flags.in_test = True

    # 1. Update System Settings (Passwords and Sessions)
    settings = frappe.get_single("System Settings")
    settings.minimum_password_score = "2" # Requires some complexity
    settings.session_expiry = "12:00" # 12 hours
    settings.session_expiry_mobile = "24:00" # 24 hours
    settings.force_user_to_reset_password = 1
    settings.allow_login_using_mobile_number = 0
    settings.allow_login_using_user_name = 1
    settings.save(ignore_permissions=True)
    print("Locked down System Settings (Passwords and Sessions).")

    # 2. Enforce Global Two-Factor Authentication
    # Frappe v15 has a "Two Factor Auth" section in System Settings
    settings.enable_two_factor_auth = 1
    settings.bypass_2fa_for_retricted_ip_users = 0
    settings.two_factor_method = "OTP App" # Recommended over SMS
    settings.save(ignore_permissions=True)
    print("Enabled global Two-Factor Authentication via OTP App.")

    # 3. Check Role Permissions
    # Ensure Student and Parent roles cannot access System Settings
    for role in ["Student", "Parent"]:
        if frappe.db.exists("Custom Role", {"name": "System Settings", "role": role}):
            print(f"WARNING: Role {role} has unexpected access to System Settings!")
    
    frappe.db.commit()
    print("Security Audit & Hardening completed successfully.")

if __name__ == '__main__':
    run()
