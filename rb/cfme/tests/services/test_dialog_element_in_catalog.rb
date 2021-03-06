require_relative 'cfme'
include Cfme
require_relative 'cfme/automate/dialogs/dialog_element'
include Cfme::Automate::Dialogs::Dialog_element
require_relative 'cfme/automate/dialogs/service_dialogs'
include Cfme::Automate::Dialogs::Service_dialogs
require_relative 'cfme/fixtures/automate'
include Cfme::Fixtures::Automate
require_relative 'cfme/infrastructure/provider/rhevm'
include Cfme::Infrastructure::Provider::Rhevm
require_relative 'cfme/markers/env_markers/provider'
include Cfme::Markers::Env_markers::Provider
require_relative 'cfme/services/service_catalogs'
include Cfme::Services::Service_catalogs
require_relative 'cfme/utils/appliance'
include Cfme::Utils::Appliance
require_relative 'cfme/utils/appliance'
include Cfme::Utils::Appliance
require_relative 'cfme/utils/appliance/implementations/ssui'
include Cfme::Utils::Appliance::Implementations::Ssui
alias ssui_nav navigate_to
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
require_relative 'cfme/utils/conf'
include Cfme::Utils::Conf
require_relative 'cfme/utils/ftp'
include Cfme::Utils::Ftp
require_relative 'cfme/utils/log_validator'
include Cfme::Utils::Log_validator
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
pytestmark = [test_requirements.dialog, pytest.mark.tier(2)]
WIDGETS = {"Text Box" => ["input", fauxfactory.gen_alpha()], "Check Box" => ["checkbox", true], "Text Area" => ["input", fauxfactory.gen_alpha()], "Radio Button" => ["radiogroup", nil], "Dropdown" => ["dropdown", "One"], "Tag Control" => ["dropdown", "Production Linux Team"], "Timepicker" => ["input", ""]}
def service_dialog(appliance, widget_name)
  service_dialog = appliance.collections.service_dialogs
  element_data = {"element_information" => {"ele_label" => fauxfactory.gen_alphanumeric(start: "label_"), "ele_name" => fauxfactory.gen_alphanumeric(start: "name_"), "ele_desc" => fauxfactory.gen_alphanumeric(start: "desc_"), "choose_type" => widget_name}, "options" => {"field_required" => true}}
  if widget_name == "Tag Control"
    element_data["options"]["field_category"] = "Owner"
  end
  sd = service_dialog.create(label: fauxfactory.gen_alphanumeric(start: "dialog_"), description: "my dialog")
  tab = sd.tabs.create(tab_label: fauxfactory.gen_alphanumeric(start: "tab_"), tab_desc: "my tab desc")
  box = tab.boxes.create(box_label: fauxfactory.gen_alphanumeric(start: "box_"), box_desc: "my box desc")
  box.elements.create(element_data: [element_data])
  yield([sd, element_data])
  sd.delete_if_exists()
end
def catalog_item_local(appliance, service_dialog, catalog)
  sd,element_data = service_dialog
  item_name = fauxfactory.gen_alphanumeric(15, start: "cat_item_")
  catalog_item = appliance.collections.catalog_items.create(appliance.collections.catalog_items.GENERIC, name: item_name, description: "my catalog", display_in: true, catalog: catalog, dialog: sd)
  yield(catalog_item)
  catalog_item.delete_if_exists()
end
def custom_categories(appliance)
  category = appliance.collections.categories.create(name: "tier_no_production", description: "testing dialog", display_name: "tier_no_production")
  yield(category)
  category.delete_if_exists()
end
def test_required_dialog_elements(appliance, catalog_item_local, service_dialog, widget_name)
  # 
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/4h
  #       caseimportance: high
  #       startsin: 5.10
  #       testSteps:
  #           1. Create a dialog. Set required true to element
  #           2. Use the dialog in a catalog.
  #           3. Order catalog.
  #        expectedResults:
  #           1.
  #           2.
  #           3. Submit button should be disabled
  #   
  sd,element_data = service_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item_local.catalog, catalog_item_local.name)
  view = navigate_to(service_catalogs, "Order")
  ele_name = element_data["element_information"]["ele_name"]
  choose_type = element_data["element_information"]["choose_type"]
  wt,value = WIDGETS[widget_name]
  if !["Radio Button", "Timepicker"].include?(choose_type)
    raise unless view.submit_button.disabled
    view.fields(ele_name).getattr(wt).fill(value)
    wait_for(lambda{|| !view.submit_button.disabled}, delay: 0.2, timeout: 15)
  else
    if choose_type == "Timepicker"
      raise unless !view.submit_button.disabled
      view.fields(ele_name).getattr(wt).fill(value)
      raise unless view.submit_button.disabled
    else
      raise unless !view.submit_button.disabled
    end
  end
end
def test_validate_not_required_dialog_element(appliance, file_name, generic_catalog_item_with_imported_dialog)
  # 
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/4h
  #       caseimportance: high
  #       startsin: 5.10
  #       testSteps:
  #           1. Create a dialog with a field which needs to 'Validate' but is not 'Required'
  #           2. Execute the dialog as a Catalog Service
  #           3. Try submitting the dialog only with the 'Required' Fields
  #       expectedResults:
  #           1.
  #           2.
  #           3. It should be able to submit the form with only 'Required' fields
  # 
  #   Bugzilla:
  #       1692736
  #   
  catalog_item,sd,_ = generic_catalog_item_with_imported_dialog
  service_catalog = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalog, "Order")
  required = view.fields("required").input
  validated = view.fields("validate").input
  clean_inputs = lambda do
    required.fill("")
    validated.fill("")
  end
  clean_inputs.call()
  raise unless required.warning == "This field is required"
  raise unless view.submit_button.disabled
  required.fill(fauxfactory.gen_alphanumeric())
  raise unless wait_for(lambda{|| !required.warning}, timeout: 15)
  raise unless !view.submit_button.disabled
  clean_inputs.call()
  required.fill(fauxfactory.gen_alphanumeric())
  validated.fill(fauxfactory.gen_alpha())
  msg = "Entered text should match the format: ^(?:[1-9]|(?:[1-9][0-9])|(?:[1-9][0-9][0-9])|(?:900))$"
  raise unless validated.warning == msg
  raise unless view.submit_button.disabled
  validated.fill("123")
  raise unless wait_for(lambda{|| !validated.warning}, timeout: 15)
  raise unless !view.submit_button.disabled
end
def test_dynamic_dialog_fields_ansible_tower_templates()
  # 
  # 
  #   Bugzilla:
  #       1696474
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/2h
  #       testSteps:
  #           1. Add dynamic dialog with \"text area\" field
  #           2. Add service catalog with above created dialog
  #           3. Navigate to order page of service
  #           4. Order the service
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Populated \"text area\" fields should pass correct value to ansible tower templates
  #   
  # pass
end
def test_dialog_editor_modify_field(dialog)
  # 
  #   Bugzilla:
  #       1707961
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.11
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       testSteps:
  #           1. Add dialog
  #           2. Edit a dialog
  #           3. Edit and save as many fields as many times as you like
  #           4. Exit without saving the dialog
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. The UI should confirm that you want to exit without saving your dialog
  #   
  view = navigate_to(dialog, "Edit", force: true)
  view.description.fill(fauxfactory.gen_alpha())
  view.cancel_button.click(handle_alert: true)
  view = navigate_to(dialog, "Edit")
  raise unless view.description.read() == dialog.description
  view.cancel_button.click(handle_alert: false)
end
def test_specific_dates_and_time_in_timepicker()
  # 
  # 
  #   Bugzilla:
  #       1706848
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       testSteps:
  #           1. Create a dialog with timepicker
  #           2. Select specific dates and time, Save
  #           3. Edit the dialog
  #       expectedResults:
  #           1.
  #           2.
  #           3. Able to set specific dates and time in timepicker
  #   
  # pass
end
def test_dynamic_field_on_refresh_button(appliance, import_datastore, import_data, file_name, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1706693
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       testSteps:
  #           1. Import Datastore and dialog
  #           2. Add service catalog with above created dialog
  #           3. Navigate to order page of service
  #           4. In service Order page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. dynamic field shouldn't be blank
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  label_element_map = {"var_1 - copied" => "var_2", "var_2 - copied" => "var_3", "merged" => "var_2_var_3"}
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  for (label, ele_name) in label_element_map.to_a()
    before_refresh = view.fields(ele_name).input.read()
    view.fields(ele_name).input.fill(fauxfactory.gen_alphanumeric())
    view.fields(label).refresh.click()
    raise unless view.fields(ele_name).input.read() == before_refresh
  end
end
def test_clicking_created_catalog_item_in_the_list(appliance, generic_catalog_item)
  # 
  #   Bugzilla:
  #       1702343
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Go to Services > Catalogs > Catalog Items accordion
  #           2. Configuration > Add a New Catalog Item, choose some Catalog Item type
  #           3. Fill in the required info and click on Add button
  #           4. After successfully saving the Catalog Item, click on the same Catalog Item in list
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Catalog Item's summary screen should appear
  #   
  (LogValidator("/var/www/miq/vmdb/log/evm.log", failure_patterns: [".*ERROR.*"])).waiting(timeout: 120) {
    view = navigate_to(appliance.collections.catalog_items, "All")
    for cat_item in view.table
      if cat_item[2].text == generic_catalog_item.name
        cat_item[2].click()
        break
      end
    end
    raise unless view.title.text == "Service Catalog Item \"#{generic_catalog_item.name}\""
  }
end
def test_provider_field_should_display_in_vm_details_page_in_ssui(appliance, provider, setup_provider, service_vm)
  # 
  # 
  #   Bugzilla:
  #       1686076
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Create a catalog item of vmware or RHEV.
  #           2. Navigate to order page of service
  #           3. Order Service
  #           4. Go to Service UI. Click on VM
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Vm details page should display which provider it belongs to
  #   
  service,vm = service_vm
  appliance.context.use(ViaSSUI) {
    view = ssui_nav(service, "VMDetails")
    raise unless view.provider_info.read().include?(provider.name)
    raise unless view.vm_info.read().include?(vm.name)
  }
end
def test_service_dialog_date_datetime_picker_dynamic_dialog()
  # 
  # 
  #   Bugzilla:
  #       1685266
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Import Datastore
  #           2. Create a dialog with a Date Picker/DateTmie picker
  #           3. Make the dialog field dynamic
  #           4. Create a service and add your dialog
  #           5. Navigate to order page of service
  #           6. In service Order page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5.
  #           6. Date should be today
  #   
  # pass
end
def test_service_dd_dialog_load_values_on_init(appliance, import_datastore, import_data, file_name, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1684567
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.11
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Import the attached yaml dialog export and automate domains.
  #           2. Add the dialog to a service or custom button.
  #           3. Navigate to order page of service
  #           4. In service Order page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. The dialog elements should not be populated as the method
  #             should not have run as \"load_values_on_init: false\" is set in the element definition.
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  raise unless !view.fields("text_box").read()
end
def test_service_catalog_orchestration_global_region()
  # 
  # 
  #   Bugzilla:
  #       1656351
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Create a service catalog with type orchestration template (heat or Aws)
  #           2. Navigate to order page of service
  #           3. Order the above service from global region
  #       expectedResults:
  #           1.
  #           2.
  #           3. From global region, the ordering of catalog should be successful
  # 
  #   
  # pass
end
def test_copy_save_service_dialog_with_the_same_name()
  # 
  # 
  #   Bugzilla:
  #       1713100
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Copy service dialog \"Test Dialog\" save as \"Copy of Test Dialog\"
  #           2. Copy service dialog \"Test Dialog\" attempt to save as \"Copy of Test Dialog\"
  #       expectedResults:
  #           1.
  #           2. Tabs shouldn\'t be copied and shouldn\'t show multiple times.
  # 
  #   
  # pass
end
def test_request_details_page_tagcontrol_field(request, appliance, import_dialog, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1696697
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Add service dialog with tagcontrol field
  #           2. Add catalog item with above dialog
  #           3. Navigate to order page of service
  #           4. Order the service
  #           5. Go to service request details page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5. No error when go to on service request details page
  # 
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  view.fields(ele_label).dropdown.fill("One")
  view.submit_button.click()
  request_description = "Provisioning Service [{name}] from [{name}]".format(name: catalog_item.name)
  service_request = appliance.collections.requests.instantiate(description: request_description, partial_check: true)
  request.addfinalizer(lambda{|| service_request.remove_request(method: "rest")})
  details_view = navigate_to(service_request, "Details")
  raise unless details_view.is_displayed
end
def test_dynamic_dialogs(appliance, import_datastore, generic_catalog_item_with_imported_dialog)
  # 
  # 
  #   Bugzilla:
  #       1696474
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Import DataStore and Dynamic Dialog
  #           2. Add catalog item with above dialog
  #           3. Navigate to order page of service
  #           4. In service Order page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. All dynamic dialog functionality should work
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  data_value = fauxfactory.gen_alphanumeric()
  view.fields(ele_label).fill(data_value)
  wait_for(lambda{|| view.fields("limit").read() == data_value && view.fields("param_vm_name").read() == data_value}, timeout: 7)
  view.fields("dialog_hostname_master_appliance").read() == appliance.hostname
  raise unless view.fields("param_database").checkbox.read()
end
def test_dynamic_dialogs_on_service_request(import_datastore, generic_catalog_item_with_imported_dialog)
  # 
  # 
  #   Bugzilla:
  #       1706600
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Import DataStore and Dynamic Dialog
  #           2. Add catalog item with above dialog
  #           3. Navigate to order page of service
  #           3. Order the service
  #           4. Click refresh until Service finishes. (Services/Requests)
  #           5. Double Click on your request
  #           6. Page down and Under 'Dialog Options' Notice the 'Text Area' field
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5.
  #           6. Dialog Fields should populate in the System Request
  #   
  catalog_item = generic_catalog_item_with_imported_dialog[0]
  request = ServiceCatalogs(catalog_item.appliance, catalog: catalog_item.catalog, name: catalog_item.name).order()
  view = navigate_to(request, "Details")
  raise unless view.details.request_details.read()["Text Box"] == "data text displays yada yada yada"
end
def test_access_child_services_from_the_my_service()
  # 
  # 
  #   Bugzilla:
  #       1693264
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       testSteps:
  #           1. create a catalog item
  #           2. attache the child service to above service
  #           3. Navigate to My Service
  #           4. Go to service details page
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Access the child service from parent section
  #   
  # pass
end
def test_catalog_load_values_on_init(appliance, request)
  # 
  # 
  #   Bugzilla:
  #       1684575
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.11
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       testSteps:
  #           1. create a service dialog with option dynamic to True
  #           2. In service dialog element option page
  #       expectedResults:
  #           1.
  #           2. Load_values_on_init button should always be enabled
  #   
  element_data = {"element_information" => {"ele_label" => fauxfactory.gen_alphanumeric(start: "label_"), "ele_name" => fauxfactory.gen_alphanumeric(start: "name_"), "ele_desc" => fauxfactory.gen_alphanumeric(start: "desc_"), "choose_type" => "Text Box", "dynamic_chkbox" => true}, "options" => {"field_required" => true}}
  service_dialog = appliance.collections.service_dialogs
  sd = service_dialog.create(label: fauxfactory.gen_alphanumeric(15, start: "label_"), description: "my dialog")
  tab = sd.tabs.create(tab_label: fauxfactory.gen_alphanumeric(start: "tab_"), tab_desc: "my tab desc")
  box = tab.boxes.create(box_label: fauxfactory.gen_alphanumeric(start: "box_"), box_desc: "my box desc")
  box.elements.create(element_data: [element_data])
  request.addfinalizer(sd.delete_if_exists)
  view = appliance.browser.create_view(EditElementView)
  view.element.edit_element(element_data["element_information"]["ele_label"])
  raise unless view.element_information.dynamic_chkbox.is_enabled
  view.options.click()
  raise unless view.options.load_values_on_init.is_enabled
end
def test_datepicker_field_set_to_required()
  # 
  # 
  #   Bugzilla:
  #       1677724
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Create dialog and add a Datepicker field to it. Set required
  #           2. Add the service dialog to Services
  #           3. Navigate to order page of service
  #           4. In service Order page
  #           5. Empty the datepicker field
  #           6. Order the service
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5
  #           6. It should show the required message
  #   
  # pass
end
def test_service_bundle_vms()
  # 
  # 
  #   Bugzilla:
  #       1654165
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Create Bundle, containing 2 service items, each of which will provision a single VM
  #           2. Navigate to order page of service
  #           3. Order the Service bundle.
  #       expectedResults:
  #           1.
  #           2. View the Service. Both VMs should displayed, instead of the 1 VM.
  #   
  # pass
end
def test_service_dialog_expression_method(appliance, setup_provider, create_vm, import_datastore, import_data, file_name, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1558926
  # 
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       testSteps:
  #           1. Import datastore and import dialog
  #           2. Add catalog item with above dialog
  #           3. Navigate to order page of service
  #           4. In service order page
  #           5. Add values in expression field
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5. Expression method should work
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog: catalog_item.catalog, name: catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  raise unless view.fields("dropdown_list_1").dropdown.all_options.map{|opt| opt.text}.include?(create_vm.name)
end
def test_service_dynamic_dialog_tagcontrol(appliance, import_datastore, import_data, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1729379
  #       1749650
  # 
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       startsin: 5.10
  #       testSteps:
  #           1. Import datastore and import dialog
  #           2. Add catalog item with above dialog
  #           3. Navigate to order page of service
  #           4. In service order page
  #           5. Choose a value from the tag control drop down
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4.
  #           5. Tag control drop down should show correct values
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  view.fields("tag_control_1").dropdown.fill("London")
  wait_for(lambda{|| view.fields("tag_control_1").read() == "London" && view.fields("text_box_1").read() == "Tag: 'London'"}, timeout: 7)
  view.fields("tag_control_1").dropdown.fill("New York")
  wait_for(lambda{|| view.fields("tag_control_1").read() == "New York" && view.fields("text_box_1").read() == "Tag: 'New York'"}, timeout: 7)
end
def test_datepicker_in_service_request()
  # 
  #   Bugzilla:
  #       1744413
  # 
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/6h
  #       startsin: 5.10
  #       testSteps:
  #           1. Create Dialog with Date picker
  #           2. Create Service with the dialog and order the service
  #           3. Mention a date for the date picker
  #           4. Navigate to Services -> Requests -> [your_service] -> Dialog Options
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Date picker should show correct selected dates
  #   
  # pass
end
def test_multi_dropdown_dialog_value(appliance, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1740823
  # 
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       startsin: 5.10
  #   testSteps:
  #           1. Create a multi select dropdown with values \"One, Two, Three\"
  #           2. Add catalog item
  #           3. Go to service order page
  #           4. Check the values in dropdown
  #           5. Check the \"<None>\" in multi drop down list
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. \"One, Two, Three\" should be present in list
  #           5. \"<None>\" should not be displayed in the list
  #   
  catalog_item,sd,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  options_list = view.fields(ele_label).multi_drop.all_options.map{|option| option.text}
  raise unless ["One", "Two", "Three"].map{|opt| options_list.include?(opt)}.is_all?
  raise unless !options_list.include?("<None>")
end
def test_dialog_dropdown_int_required(appliance, generic_catalog_item_with_imported_dialog)
  # 
  #   Bugzilla:
  #       1740899
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       startsin: 5.10
  #       testSteps:
  #           1. Create a dialog dropdown that is required with a value type of integer
  #           2. Order a catalog item that uses that dialog
  #           3. Make a selection for the dropdown
  #       expectedResults:
  #           1.
  #           2.
  #           3. The field should validate successfully
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  view = navigate_to(service_catalogs, "Order")
  view.fields(ele_label).dropdown.fill("2")
  wait_for(lambda{|| !view.submit_button.disabled}, timeout: 7)
end
def test_dialog_default_value_integer(appliance, generic_catalog_item_with_imported_dialog, file_name)
  # 
  #   Bugzilla:
  #       1554780
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/4h
  #       testtype: functional
  #       startsin: 5.10
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  fs = FTPClientWrapper(cfme_data.ftpserver.entities.dialogs)
  file_path = fs.download(file_name)
  open(file_path) {|stream|
    dialog_data = yaml.load(stream, Loader: yaml.BaseLoader)
    default_drop = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][0]["default_value"]
    default_radio = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][1]["default_value"]
  }
  view = navigate_to(service_catalogs, "Order")
  raise unless view.fields("dropdown").read() == default_drop && view.fields("radio").read() == default_radio
end
def test_dialog_default_value_selection(appliance, custom_categories, import_datastore, import_data, generic_catalog_item_with_imported_dialog, file_name)
  # 
  #   Bugzilla:
  #       1579405
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/4h
  #       testtype: functional
  #       startsin: 5.10
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  fs = FTPClientWrapper(cfme_data.ftpserver.entities.dialogs)
  file_path = fs.download(file_name)
  open(file_path) {|stream|
    dialog_data = yaml.load(stream, Loader: yaml.BaseLoader)
    environment = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][0]["default_value"]
    vm_size = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][1]["default_value"]
    network = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][2]["default_value"]
    additional_disks = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][3]["default_value"]
  }
  view = navigate_to(service_catalogs, "Order")
  raise unless view.fields("environment").read() == environment && view.fields("instance").read() == vm_size && view.fields("network").read() == network && view.fields("number_disk").read() == additional_disks
end
def test_save_dynamic_multi_drop_down_dialog(appliance, import_datastore, import_dialog, import_data)
  # 
  #   Bugzilla:
  #       1559030
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       testtype: functional
  #       initialEstimate: 1/4h
  #       startsin: 5.10
  #   
  sd,ele_label = import_dialog
  navigate_to(sd, "Edit")
  view = appliance.browser.create_view(EditElementView)
  view.element.edit_element(ele_label)
  view.options.click()
  view.options.multi_select.fill("Yes")
  view.ele_save_button.click()
  view.save_button.click()
  view = sd.create_view(DetailsDialogView, wait: "60s")
  view.flash.assert_success_message("#{sd.label} was saved")
end
def test_dialog_not_required_default_value(appliance, generic_catalog_item_with_imported_dialog, file_name)
  # 
  #   Bugzilla:
  #       1783375
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #       startsin: 5.10
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  fs = FTPClientWrapper(cfme_data.ftpserver.entities.dialogs)
  file_path = fs.download(file_name)
  open(file_path) {|stream|
    dialog_data = yaml.load(stream, Loader: yaml.BaseLoader)
    default_drop = dialog_data[0]["dialog_tabs"][0]["dialog_groups"][0]["dialog_fields"][0]["default_value"]
  }
  view = navigate_to(service_catalogs, "Order")
  raise unless view.fields("dropdown_list_1").read() == default_drop
end
def test_dynamic_dialog_field_associations(appliance, import_datastore, import_dialog, import_data)
  #  Tests dynamic service dialog field associations
  #   Bugzilla:
  #       1559382
  #   Polarion:
  #       assignee: nansari
  #       casecomponent: Services
  #       testtype: functional
  #       initialEstimate: 1/4h
  #       startsin: 5.10
  #   
  sd,ele_label = import_dialog
  navigate_to(sd, "Edit")
  view = appliance.browser.create_view(EditElementView)
  view.element.edit_element(ele_label)
  view.options.click()
  view.options.refresh_fields_dropdown.fill("text-area")
  view.ele_save_button.click()
  view.save_button.click()
  view.flash.assert_message(["There was an error editing this dialog: Failed to update service dialog -text-box already exists in [\"text-box\", \"textarea\"]"])
end
def test_dynamic_dropdown_refresh_load(appliance, import_datastore, import_data, generic_catalog_item_with_imported_dialog, context)
  # 
  #   Bugzilla:
  #       1576873
  #   Polarion:
  #       assignee: nansari
  #       startsin: 5.10
  #       casecomponent: Services
  #       initialEstimate: 1/16h
  #   
  catalog_item,_,ele_label = generic_catalog_item_with_imported_dialog
  service_catalogs = ServiceCatalogs(appliance, catalog_item.catalog, catalog_item.name)
  appliance.context.use(context) {
    if context == ViaSSUI
      view = ssui_nav(service_catalogs, "Details")
    else
      view = navigate_to(service_catalogs, "Order")
    end
    (LogValidator("/var/www/miq/vmdb/log/automation.log", matched_patterns: ["We are in B"], failure_patterns: ["We are in A"])).waiting(timeout: 120) {
      view.fields(ele_label).dropdown.fill("b")
    }
  }
end
