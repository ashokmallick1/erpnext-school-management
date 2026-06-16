import frappe

def set_branding():
    # System Settings
    system_settings = frappe.get_doc("System Settings")
    system_settings.app_name = "Quorvia ?"
    system_settings.splash_image = "/assets/quorvia_erp/images/quorvia_logo.svg"
    system_settings.save(ignore_permissions=True)
    
    # Website Settings
    website_settings = frappe.get_doc("Website Settings")
    website_settings.app_name = "Quorvia ?"
    website_settings.app_logo = "/assets/quorvia_erp/images/quorvia_logo.svg"
    website_settings.favicon = "/assets/quorvia_erp/images/favicon.svg"
    website_settings.splash_image = "/assets/quorvia_erp/images/quorvia_logo.svg"
    website_settings.brand_html = '''
    <div style="display: flex; align-items: center; gap: 10px;">
        <img src="/assets/quorvia_erp/images/quorvia_logo.svg" style="height: 30px; width: 30px;" />
        <span style="font-weight: bold; font-size: 1.2rem; color: var(--primary-color);">Quorvia ?</span>
    </div>
    '''
    website_settings.footer_powered = "Powered by Quorvia"
    website_settings.save(ignore_permissions=True)
    
    frappe.db.commit()

set_branding()
