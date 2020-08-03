require_relative 'widgetastic_patternfly'
include Widgetastic_patternfly
require_relative 'widgetastic_patternfly'
include Widgetastic_patternfly
require_relative 'cfme'
include Cfme
require_relative 'cfme/infrastructure/provider/virtualcenter'
include Cfme::Infrastructure::Provider::Virtualcenter
require_relative 'cfme/markers/env_markers/provider'
include Cfme::Markers::Env_markers::Provider
require_relative 'cfme/services/myservice'
include Cfme::Services::Myservice
require_relative 'cfme/tests/automate/custom_button'
include Cfme::Tests::Automate::Custom_button
require_relative 'cfme/tests/automate/custom_button'
include Cfme::Tests::Automate::Custom_button
require_relative 'cfme/tests/automate/custom_button'
include Cfme::Tests::Automate::Custom_button
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
require_relative 'cfme/utils/blockers'
include Cfme::Utils::Blockers
require_relative 'cfme/utils/log_validator'
include Cfme::Utils::Log_validator
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
pytestmark = [pytest.mark.tier(2), test_requirements.custom_button]
GENERIC_SSUI_UNCOLLECT = "Generic object custom button not supported by SSUI"
OBJECTS = ["SERVICE", "GENERIC"]
DISPLAY_NAV = {"Single entity" => ["Details"], "List" => ["All"], "Single and list" => ["All", "Details"]}
SUBMIT = ["Submit all", "One by one"]
TEXT_DISPLAY = {"group" => {"group_display" => false, "btn_display" => true}, "button" => {"group_display" => true, "btn_display" => false}}
def objects(appliance, add_generic_object_to_service)
  instance = add_generic_object_to_service
  obj_dest = {"GENERIC" => {"All" => [instance.my_service, "GenericObjectInstance"], "Details" => [instance, "MyServiceDetails"]}, "SERVICE" => {"All" => [instance.my_service, "All"], "Details" => [instance.my_service, "Details"]}}
  yield obj_dest
end
def button_group(appliance, request)
  appliance.context.use(ViaUI) {
    collection = appliance.collections.button_groups
    button_gp = collection.create(text: fauxfactory.gen_alphanumeric(start: "grp_"), hover: fauxfactory.gen_alphanumeric(15, start: "grp_hvr_"), type: collection.getattr(request.param))
    yield [button_gp, request.param]
    button_gp.delete_if_exists()
  }
end
def serv_button_group(appliance, request)
  appliance.context.use(ViaUI) {
    collection = appliance.collections.button_groups
    button_gp = collection.create(text: fauxfactory.gen_numeric_string(start: "grp_"), hover: fauxfactory.gen_alphanumeric(15, start: "grp_hvr_"), display: TEXT_DISPLAY[request.param]["group_display"], type: collection.getattr("SERVICE"))
    button = button_gp.buttons.create(text: fauxfactory.gen_numeric_string(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), display: TEXT_DISPLAY[request.param]["btn_display"], display_for: "Single and list", system: "Request", request: "InspectMe")
    yield [button, button_gp]
    button.delete_if_exists()
    button_gp.delete_if_exists()
  }
end
def service_button_group(appliance)
  appliance.context.use(ViaUI) {
    collection = appliance.collections.button_groups
    button_gp = collection.create(text: fauxfactory.gen_alphanumeric(start: "group_"), hover: fauxfactory.gen_alphanumeric(start: "hover_"), type: collection.getattr("SERVICE"))
    yield button_gp
    button_gp.delete_if_exists()
  }
end
def vis_enb_button_service(request, appliance, service_button_group)
  # Create custom button on service type object with enablement/visibility expression
  exp = {request.param => {"tag" => "My Company Tags : Department", "value" => "Engineering"}}
  appliance.context.use(ViaUI) {
    button = service_button_group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(start: "hover_"), display_for: "Single entity", system: "Request", request: "InspectMe", None: exp)
    yield [service_button_group, button, request.param]
    button.delete_if_exists()
  }
end
def test_custom_button_display_service_obj(request, appliance, context, display, objects, button_group)
  #  Test custom button display on a targeted page
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: critical
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.8
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Create custom button group with the Object type
  #           2. Create a custom button with specific display
  #           3. Navigate to object type page as per display selected [For service SSUI]
  #           4. Single entity: Details page of the entity
  #           5. List: All page of the entity
  #           6. Single and list: Both All and Details page of the entity
  #           7. Check for button group and button
  # 
  #   Bugzilla:
  #       1650066
  #   
  group,obj_type = button_group
  appliance.context.use(ViaUI) {
    button = group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(start: "btn_hvr_"), display_for: display, system: "Request", request: "InspectMe")
    request.addfinalizer(button.delete_if_exists)
  }
  appliance.context.use(context) {
    navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
    for destination in DISPLAY_NAV[display]
      obj = objects[obj_type][destination][0]
      dest_name = objects[obj_type][destination][1]
      view = navigate_to.(obj, dest_name)
      custom_button_group = Dropdown(view, group.text)
      raise unless custom_button_group.is_displayed
      raise unless custom_button_group.has_item(button.text)
    end
  }
end
def test_custom_button_automate_service_obj(request, appliance, context, submit, objects, button_group)
  #  Test custom button for automate and requests count as per submit
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: high
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Create custom button group with the Object type
  #           2. Create a custom button with specific submit option and Single and list display
  #           3. Navigate to object type pages (All and Details)
  #           4. Check for button group and button
  #           5. Select/execute button from group dropdown for selected entities
  #           6. Check for the proper flash message related to button execution
  #           7. Check automation log requests. Submitted as per selected submit option or not.
  #           8. Submit all: single request for all entities execution
  #           9. One by one: separate requests for all entities execution
  # 
  #   Bugzilla:
  #       1650066
  #   
  group,obj_type = button_group
  appliance.context.use(ViaUI) {
    button = group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), display_for: "Single and list", submit: submit, system: "Request", request: "InspectMe")
    request.addfinalizer(button.delete_if_exists)
  }
  appliance.context.use(context) {
    navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
    destinations = is_bool(context == ViaSSUI && BZ(1650066, forced_streams: ["5.11"]).blocks) ? ["Details"] : ["All", "Details"]
    for destination in destinations
      obj = objects[obj_type][destination][0]
      dest_name = objects[obj_type][destination][1]
      view = navigate_to.(obj, dest_name)
      custom_button_group = Dropdown(view, group.text)
      raise unless custom_button_group.has_item(button.text)
      if destination == "All"
        begin
          paginator = view.paginator
        rescue NoMethodError
          paginator = view.entities.paginator
        end
        entity_count = paginator.items_amount, paginator.items_per_page.min
        view.entities.paginator.check_all()
      else
        entity_count = 1
      end
      raise unless appliance.ssh_client.run_command("echo -n \"\" > /var/www/miq/vmdb/log/automation.log")
      custom_button_group.item_select(button.text)
      if context === ViaUI
        diff = (appliance.version < "5.10") ? "executed" : "launched"
        view.flash.assert_message()
      end
      expected_count = (submit == "Submit all") ? 1 : entity_count
      begin
        wait_for(log_request_check, [appliance, expected_count], timeout: 600, message: "Check for expected request count", delay: 20)
      rescue TimedOutError
        raise "Expected {count} requests not found in automation log".format(count: expected_count.to_s) unless false
      end
    end
  }
end
def test_custom_button_text_display(appliance, context, serv_button_group, gen_rest_service)
  #  Test custom button text display on option
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/6h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Appliance with Service
  #           2. Create custom button `Group` or `Button` without display option
  #           3. Check Group/Button text display or not on UI and SSUI.
  # 
  #   Bugzilla:
  #       1650066
  #       1659452
  #       1745492
  #   
  my_service = MyService(appliance, name: gen_rest_service.name)
  button,group = serv_button_group
  appliance.context.use(context) {
    navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
    destinations = is_bool(BZ(1650066, forced_streams: ["5.11"]).blocks && context === ViaSSUI) ? ["Details"] : ["All", "Details"]
    for destination in destinations
      view = navigate_to.(my_service, destination)
      custom_button_group = Dropdown(view, (context === ViaUI) ? group.hover : group.text)
      if group.display === true
        raise unless custom_button_group.to_a.include?("")
      else
        raise unless custom_button_group.read() == ""
      end
    end
  }
end
def vis_enb_button(request, appliance, button_group)
  # Create custom button with enablement/visibility expression
  group,_ = button_group
  exp = {request.param => {"tag" => "My Company Tags : Department", "value" => "Engineering"}}
  appliance.context.use(ViaUI) {
    button = group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), display_for: "Single entity", system: "Request", request: "InspectMe", None: exp)
  }
  yield [button, request.param]
  button.delete_if_exists()
end
def test_custom_button_expression_service_obj(appliance, context, objects, button_group, vis_enb_button)
  #  Test custom button as per expression enablement/visibility.
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       casecomponent: CustomButton
  #       startsin: 5.9
  #       testSteps:
  #           1. Create custom button group with the Object type
  #           2. Create a custom button with expression (Tag)
  #               a. Enablement Expression
  #               b. Visibility Expression
  #           3. Navigate to object Detail page
  #           4. Check: button should not enable/visible without tag
  #           5. Check: button should enable/visible with tag
  # 
  #   Bugzilla:
  #       1509959
  #       1513498
  #   
  group,obj_type = button_group
  button,expression = vis_enb_button
  obj = objects[obj_type]["Details"][0]
  dest_name = objects[obj_type]["Details"][1]
  navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
  tag_cat = appliance.collections.categories.instantiate(name: "department", display_name: "Department")
  tag = tag_cat.collections.tags.instantiate(name: "engineering", display_name: "Engineering")
  appliance.context.use(ViaUI) {
    if obj.get_tags().include?(tag)
      obj.remove_tag(tag)
    end
  }
  appliance.context.use(context) {
    view = navigate_to.(obj, dest_name, wait_for_view: 15)
    custom_button_group = (context === ViaSSUI) ? CustomButtonSSUIDropdwon(view, group.text) : Dropdown(view, group.text)
    if expression == "enablement"
      if is_bool(appliance.version < "5.10" || context === ViaSSUI)
        raise unless !custom_button_group.item_enabled(button.text)
      else
        raise unless !custom_button_group.is_enabled
      end
    else
      if expression == "visibility"
        raise unless !custom_button_group.is_displayed
      end
    end
  }
  appliance.context.use(ViaUI) {
    obj.add_tag(tag)
  }
  appliance.context.use(context) {
    view = navigate_to.(obj, dest_name)
    custom_button_group = (context === ViaSSUI) ? CustomButtonSSUIDropdwon(view, group.text) : Dropdown(view, group.text)
    if expression == "enablement"
      raise unless custom_button_group.item_enabled(button.text)
    else
      if expression == "visibility"
        raise unless custom_button_group.to_a.include?(button.text)
      end
    end
  }
end
def test_custom_button_role_access_service(context, request, appliance, user_self_service_role, gen_rest_service, service_button_group)
  # Test custom button for role access of SSUI
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Create role by copying EvmRole-user_self_service
  #           2. Create Group and respective user for role
  #           3. Create custom button group
  #           4. Create custom button with role
  #           5. Check use able to access custom button or not
  #   
  usr,role = user_self_service_role
  service = MyService(appliance, name: gen_rest_service.name)
  appliance.context.use(ViaUI) {
    btn = service_button_group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(start: "hvr_"), system: "Request", request: "InspectMe", roles: [role.name])
    request.addfinalizer(btn.delete_if_exists)
  }
  for user in [usr, appliance.user]
    user {
      appliance.context.use(context) {
        logged_in_page = appliance.server.login(user)
        if context === ViaSSUI
          navigate_to = ssui_nav
          group_class = CustomButtonSSUIDropdwon
        else
          navigate_to = ui_nav
          group_class = Dropdown
        end
        view = navigate_to.(service, "Details")
        cb_group = group_class.(view, service_button_group.text)
        if user == usr
          raise unless cb_group.is_displayed
          raise unless cb_group.has_item(btn.text)
        else
          raise unless (context === ViaUI) ? !cb_group.is_displayed : cb_group.is_displayed
          if context === ViaSSUI
            raise unless !cb_group.has_item(btn.text)
          end
        end
        logged_in_page.logout()
      }
    }
  end
end
def test_custom_button_dialog_service_archived(request, appliance, provider, setup_provider, service_vm, button_group, dialog)
  #  From Service OPS check if archive vms\"s dialog invocation via custom button. ref: BZ1439883
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/8h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Create a button at the service level with InspectMe method
  #           2. Create a service that contains 1 VM
  #           3. Remove this VM from the provider, resulting in a VM state of \'Archived\'
  #           4. Go to the service and try to execute the button
  # 
  #   Bugzilla:
  #       1439883
  #   
  service,vm = service_vm
  group,obj_type = button_group
  appliance.context.use(ViaUI) {
    button = group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(start: "hover_"), dialog: dialog, system: "Request", request: "InspectMe")
  }
  request.addfinalizer(button.delete_if_exists)
  for with_vm in [true, false]
    if is_bool(!with_vm)
      vm.mgmt.delete()
      vm.wait_for_vm_state_change(desired_state: "archived", timeout: 720, from_details: false, from_any_provider: true)
    end
    for context in [ViaUI, ViaSSUI]
      appliance.context.use(context) {
        navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
        view = navigate_to.(service, "Details")
        custom_button_group = Dropdown(view, group.text)
        custom_button_group.item_select(button.text)
        _dialog_view = (context === ViaUI) ? TextInputDialogView : TextInputDialogSSUIView
        dialog_view = view.browser.create_view(_dialog_view, wait: "10s")
        request_pattern = "Attributes - Begin"
        log = LogValidator("/var/www/miq/vmdb/log/automation.log", matched_patterns: [request_pattern])
        log.start_monitoring()
        dialog_view.submit.click()
        if context === ViaUI
          view.flash.assert_message("Order Request was Submitted")
        end
        begin
          wait_for(lambda{|| log.matches[request_pattern] == 1}, timeout: 180, message: "wait for expected match count", delay: 5)
        rescue TimedOutError
          pytest.fail()
        end
      }
    end
  end
end
def test_custom_button_dialog_service_obj(appliance, dialog, request, context, objects, button_group)
  #  Test custom button with dialog and InspectMe method
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.9
  #       casecomponent: CustomButton
  #       tags: custom_button
  #       testSteps:
  #           1. Create custom button group with the Object type
  #           2. Create a custom button with service dialog
  #           3. Navigate to object Details page
  #           4. Check for button group and button
  #           5. Select/execute button from group dropdown for selected entities
  #           6. Fill dialog and submit
  #           7. Check for the proper flash message related to button execution
  # 
  #   Bugzilla:
  #       1574774
  #   
  group,obj_type = button_group
  appliance.context.use(ViaUI) {
    button = group.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), dialog: dialog, system: "Request", request: "InspectMe")
    request.addfinalizer(button.delete_if_exists)
  }
  appliance.context.use(context) {
    navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
    obj = objects[obj_type]["Details"][0]
    dest_name = objects[obj_type]["Details"][1]
    view = navigate_to.(obj, dest_name)
    custom_button_group = Dropdown(view, group.text)
    raise unless custom_button_group.has_item(button.text)
    raise unless appliance.ssh_client.run_command("echo -n \"\" > /var/www/miq/vmdb/log/automation.log")
    custom_button_group.item_select(button.text)
    _dialog_view = (context === ViaUI) ? TextInputDialogView : TextInputDialogSSUIView
    dialog_view = view.browser.create_view(_dialog_view, wait: "10s")
    raise unless dialog_view.service_name.fill("Custom Button Execute")
    dialog_view.submit.click()
    if context === ViaUI
      view.flash.assert_message("Order Request was Submitted")
    end
    begin
      wait_for(log_request_check, [appliance, 1], timeout: 600, message: "Check for expected request count", delay: 20)
    rescue TimedOutError
      raise "Expected {count} requests not found in automation log".format(count: 1.to_s) unless false
    end
  }
end
def unassigned_btn_setup(request, appliance, provider, gen_rest_service)
  if request.param == "Service"
    obj = MyService(appliance, name: gen_rest_service.name)
    destinations = [ViaUI, ViaSSUI]
  else
    obj = provider
    destinations = [ViaUI]
  end
  gp = appliance.collections.button_groups.instantiate(text: "[Unassigned Buttons]", hover: "Unassigned buttons", type: request.param)
  yield [obj, gp, destinations]
end
def test_custom_button_unassigned_behavior_objs(appliance, setup_provider, unassigned_btn_setup, request)
  #  Test unassigned custom button behavior
  # 
  #   Note: Service unassigned custom button should display on SSUI but not OPS UI.
  #   For other than service objects also follows same behaviour i.e. not display on OPS UI.
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/6h
  #       caseimportance: medium
  #       caseposneg: positive
  #       testtype: functional
  #       startsin: 5.8
  #       casecomponent: CustomButton
  #       testSteps:
  #           1. Create unassigned custom button on service and one other custom button object.
  #           2. Check destinations OPS UI should not display unassigned button but SSUI should.
  # 
  #   Bugzilla:
  #       1653195
  #   
  obj,gp,destinations = unassigned_btn_setup
  appliance.context.use(ViaUI) {
    button = gp.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), system: "Request", request: "InspectMe")
    raise unless button.exists
    request.addfinalizer(button.delete_if_exists)
  }
  for dest in destinations
    navigate_to = (dest === ViaSSUI) ? ssui_nav : ui_nav
    appliance.context.use(dest) {
      view = navigate_to.(obj, "Details")
      btn = Button(view, button.text)
      raise unless (dest === ViaSSUI) ? btn.is_displayed : !btn.is_displayed
    }
  end
end
def test_custom_button_expression_ansible_service(appliance, context, vis_enb_button_service, order_ansible_service_in_ops_ui)
  #  Test custom button on ansible service as per expression enablement/visibility.
  # 
  #   Polarion:
  #       assignee: ndhandre
  #       initialEstimate: 1/4h
  #       caseimportance: medium
  #       casecomponent: CustomButton
  #       startsin: 5.9
  #       testSteps:
  #           1. Create custom button group on Service object type
  #           2. Create a custom button with expression (Tag)
  #               a. Enablement Expression
  #               b. Visibility Expression
  #           3. Navigate to object Detail page
  #           4. Check: button should not enable/visible without tag
  #           5. Check: button should enable/visible with tag
  # 
  #   Bugzilla:
  #       1628727
  #       1509959
  #       1513498
  #       1755229
  #   
  group,button,expression = vis_enb_button_service
  service = MyService(appliance, order_ansible_service_in_ops_ui)
  navigate_to = (context === ViaSSUI) ? ssui_nav : ui_nav
  tag_cat = appliance.collections.categories.instantiate(name: "department", display_name: "Department")
  engineering_tag = tag_cat.collections.tags.instantiate(name: "engineering", display_name: "Engineering")
  for tag in [false, true]
    appliance.context.use(ViaUI) {
      current_tag_status = service.get_tags().include?(engineering_tag)
      if tag != current_tag_status
        if is_bool(tag)
          service.add_tag(engineering_tag)
        else
          service.remove_tag(engineering_tag)
        end
      end
    }
    appliance.context.use(context) {
      view = navigate_to.(service, "Details", wait_for_view: 15)
      custom_button_group = (context === ViaSSUI) ? CustomButtonSSUIDropdwon(view, group.text) : Dropdown(view, group.text)
      if is_bool(tag)
        if expression == "enablement"
          raise unless custom_button_group.item_enabled(button.text)
        else
          raise unless custom_button_group.to_a.include?(button.text)
        end
      else
        if expression == "enablement"
          if context === ViaSSUI
            raise unless !custom_button_group.item_enabled(button.text)
          else
            raise unless !custom_button_group.is_enabled
          end
        else
          raise unless !custom_button_group.is_displayed
        end
      end
    }
  end
end
