require_relative 'textwrap'
include Textwrap
require_relative 'widgetastic_patternfly'
include Widgetastic_patternfly
require_relative 'cfme'
include Cfme
require_relative 'cfme/infrastructure/provider/virtualcenter'
include Cfme::Infrastructure::Provider::Virtualcenter
require_relative 'cfme/markers/env_markers/provider'
include Cfme::Markers::Env_markers::Provider
require_relative 'cfme/tests/automate/custom_button'
include Cfme::Tests::Automate::Custom_button
require_relative 'cfme/utils/appliance'
include Cfme::Utils::Appliance
require_relative 'cfme/utils/appliance'
include Cfme::Utils::Appliance
require_relative 'cfme/utils/appliance/implementations/ssui'
include Cfme::Utils::Appliance::Implementations::Ssui
alias ssui_nav navigate_to
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
alias ui_nav navigate_to
require_relative 'cfme/utils/log_validator'
include Cfme::Utils::Log_validator
pytestmark = [pytest.mark.tier(2), test_requirements.custom_button, pytest.mark.provider([VMwareProvider], selector: ONE, required_fields: [["provisioning", "template"]], scope: "module"), pytest.mark.usefixtures("setup_provider_modscope")]
def button_group(appliance)
  collection = appliance.collections.button_groups
  button_gp = collection.create(text: fauxfactory.gen_alphanumeric(start: "grp_"), hover: fauxfactory.gen_alphanumeric(15, start: "grp_hvr_"), type: collection.getattr("VM_INSTANCE"))
  yield button_gp
  button_gp.delete_if_exists()
end
def setup_dynamic_dialog(appliance, custom_instance)
  code = dedent("
        @vm = $evm.root['vm']
        dialog_hash = {}
        dialog_hash[@vm.id] = @vm.name
        $evm.object['default_value'] = dialog_hash.first[0]
        $evm.object['values'] = dialog_hash
        ")
  instance = custom_instance.(ruby_code: code)
  service_dialog = appliance.collections.service_dialogs
  dialog = fauxfactory.gen_alphanumeric(12, start: "dialog_")
  ele_name = fauxfactory.gen_alphanumeric(start: "ele_")
  element_data = {"element_information" => {"ele_label" => fauxfactory.gen_alphanumeric(15, start: "ele_label_"), "ele_name" => ele_name, "ele_desc" => fauxfactory.gen_alphanumeric(15, start: "ele_desc_"), "dynamic_chkbox" => true, "choose_type" => "Dropdown"}, "options" => {"entry_point" => instance.tree_path, "field_required" => true}}
  sd = service_dialog.create(label: dialog, description: "my dialog")
  tab = sd.tabs.create(tab_label: fauxfactory.gen_alphanumeric(start: "tab_"), tab_desc: "my tab desc")
  box = tab.boxes.create(box_label: fauxfactory.gen_alphanumeric(start: "box_"), box_desc: "my box desc")
  box.elements.create(element_data: [element_data])
  yield [sd, ele_name]
  sd.delete_if_exists()
end
def test_custom_button_display_service_vm(request, appliance, service_vm, button_group)
  #  Test custom button display on UI and SSUI vm resource detail page
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/2h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       setup:
  #           1. Order VM from service
  #       testSteps:
  #           1. Add custom button group for VM/Instance object from automation
  #           2. Add custom button in above group
  #           3. Navigate to VM Details page from service (UI and SSUI)
  #       expectedResults:
  #           1.
  #           2.
  #           3. Check for button group and button displayed or not
  # 
  #   Bugzilla:
  #       1427430
  #       1450473
  #   
  service,_ = service_vm
  appliance.context.use(ViaUI) {
    button = button_group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), system: "Request", request: "InspectMe")
    request.addfinalizer(button.delete_if_exists)
  }
  for context in [ViaUI, ViaSSUI]
    appliance.context.use(context) {
      nav_to = (context === ViaSSUI) ? ssui_nav : ui_nav
      view = nav_to.(service, "VMDetails")
      custom_button_group = Dropdown(view, button_group.text)
      raise unless custom_button_group.is_displayed
      raise unless custom_button_group.has_item(button.text)
    }
  end
end
def test_custom_button_with_dynamic_dialog_vm(appliance, provider, request, service_vm, setup_dynamic_dialog)
  #  Test custom button combination with dynamic dialog for VM entity.
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/2h
  #       caseimportance: high
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       testSteps:
  #           1. Create new domain and copy 'Request' class from ManageIQ domain
  #           2. Create class method under new domain with following ruby method
  #           ```ruby
  #             @vm = $evm.root['vm']
  #             dialog_hash = {}
  #             dialog_hash[@vm.id] = @vm.name
  #             $evm.object['default_value'] = dialog_hash.first[0]
  #             $evm.object['values'] = dialog_hash
  #           ```
  #           3. Create Instance Pointing class method
  #           4. Create Dropdown type Service Dialog (dynamic) with entry point as above method
  #           5. Create Custom button with Service Dialog on VM/Instance Object
  #           6. Execute button on VM with OPS UI and SSUI.
  #       expectedResults:
  #           1.
  #           2.
  #           3.
  #           4. Check service dialog created or not
  #           5.
  #           6. Check dialog should take vm/instance name automatically as per method.
  #              Check automation log for button execution.
  # 
  #   Bugzilla:
  #       1687061
  #       1722817
  #       1729594
  #   
  dialog,ele_name = setup_dynamic_dialog
  collection = appliance.collections.button_groups
  button_gp = collection.create(text: fauxfactory.gen_alphanumeric(start: "grp_"), hover: fauxfactory.gen_alphanumeric(15, start: "grp_hvr_"), type: collection.getattr("VM_INSTANCE"))
  request.addfinalizer(button_gp.delete_if_exists)
  button = button_gp.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), dialog: dialog.label, system: "Request", request: "InspectMe")
  request.addfinalizer(button.delete_if_exists)
  service,_ = service_vm
  for context in [ViaUI, ViaSSUI]
    appliance.context.use(context) {
      nav_to = (context === ViaSSUI) ? ssui_nav : ui_nav
      view = nav_to.(service, "VMDetails")
      custom_button_group = Dropdown(view, button_gp.text)
      raise unless custom_button_group.is_displayed
      custom_button_group.item_select(button.text)
      view = view.browser.create_view(DropdownDialogView)
      serv = view.service_name(ele_name)
      serv.dropdown.wait_displayed()
      raise unless serv.dropdown.selected_option == service.vm_name
      log = LogValidator("/var/www/miq/vmdb/log/automation.log", matched_patterns: ["Attributes - Begin", ])
      log.start_monitoring()
      submit = (context === ViaUI) ? "submit" : "submit_request"
      view.getattr(submit).click()
      raise unless log.validate(wait: "120s")
    }
  end
end
def test_custom_button_automate_service_vm(request, appliance, service_vm, button_group)
  #  Test custom button execution on SSUI vm resource detail page
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/2h
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  # 
  #   Bugzilla:
  #       1427430
  #       1450473
  #       1454910
  #   
  service,_ = service_vm
  appliance.context.use(ViaUI) {
    button = button_group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), system: "Request", request: "InspectMe")
    request.addfinalizer(button.delete_if_exists)
  }
  for context in [ViaUI, ViaSSUI]
    appliance.context.use(context) {
      nav_to = (context === ViaSSUI) ? ssui_nav : ui_nav
      view = nav_to.(service, "VMDetails")
      log = LogValidator("/var/www/miq/vmdb/log/automation.log", matched_patterns: ["Attributes - Begin"])
      log.start_monitoring()
      custom_button_group = Dropdown(view, button_group.text)
      custom_button_group.item_select(button.text)
      raise unless log.validate(wait: "120s")
    }
  end
end
