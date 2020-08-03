require_relative 'widgetastic_patternfly'
include Widgetastic_patternfly
require_relative 'cfme'
include Cfme
require_relative 'cfme/cloud/provider/azure'
include Cfme::Cloud::Provider::Azure
require_relative 'cfme/cloud/provider/ec2'
include Cfme::Cloud::Provider::Ec2
require_relative 'cfme/control/explorer/policies'
include Cfme::Control::Explorer::Policies
require_relative 'cfme/infrastructure/provider/rhevm'
include Cfme::Infrastructure::Provider::Rhevm
require_relative 'cfme/infrastructure/provider/virtualcenter'
include Cfme::Infrastructure::Provider::Virtualcenter
require_relative 'cfme/markers/env_markers/provider'
include Cfme::Markers::Env_markers::Provider
require_relative 'cfme/services/myservice'
include Cfme::Services::Myservice
require_relative 'cfme/services/service_catalogs'
include Cfme::Services::Service_catalogs
require_relative 'cfme/utils'
include Cfme::Utils
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
require_relative 'cfme/utils/blockers'
include Cfme::Utils::Blockers
require_relative 'cfme/utils/log'
include Cfme::Utils::Log
require_relative 'cfme/utils/log_validator'
include Cfme::Utils::Log_validator
require_relative 'cfme/utils/update'
include Cfme::Utils::Update
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
pytestmark = [pytest.mark.long_running, pytest.mark.meta(blockers: [BZ(1677548, forced_streams: ["5.11"])]), test_requirements.ansible]
SERVICE_CATALOG_VALUES = [["default", nil, "localhost"], ["blank", "", "localhost"], ["unavailable_host", "unavailable_host", "unavailable_host"]]
CREDENTIALS = [["Amazon", "", "list_ec2_instances.yml"], ["VMware", "vcenter_host", "gather_all_vms_from_vmware.yml"], ["Red Hat Virtualization", "host", "get_vms_facts_rhv.yaml"], ["Azure", "", "get_resourcegroup_facts_azure.yml"]]
def local_ansible_catalog_item(appliance, ansible_repository)
  # override global ansible_catalog_item for function scope
  #       as these tests modify the catalog item
  #   
  collection = appliance.collections.catalog_items
  cat_item = collection.create(collection.ANSIBLE_PLAYBOOK, fauxfactory.gen_alphanumeric(), fauxfactory.gen_alphanumeric(), display_in_catalog: true, provisioning: {"repository" => ansible_repository.name, "playbook" => "dump_all_variables.yml", "machine_credential" => "CFME Default Credential", "create_new" => true, "provisioning_dialog_name" => fauxfactory.gen_alphanumeric(), "extra_vars" => [["some_var", "some_value"]]}, retirement: {"repository" => ansible_repository.name, "playbook" => "dump_all_variables.yml", "machine_credential" => "CFME Default Credential", "extra_vars" => [["some_var", "some_value"]]})
  yield cat_item
  cat_item.delete_if_exists()
end
def dialog_with_catalog_item(appliance, request, ansible_repository, ansible_catalog)
  _dialog_with_catalog_item = lambda do |ele_name|
    service_dialog = appliance.collections.service_dialogs
    dialog = fauxfactory.gen_alphanumeric(12, start: "dialog_")
    element_data = {"element_information" => {"ele_label" => fauxfactory.gen_alphanumeric(15, start: "ele_label_"), "ele_name" => is_bool(ele_name) ? ele_name : fauxfactory.gen_alphanumeric(15, start: "ele_name_"), "ele_desc" => fauxfactory.gen_alphanumeric(15, start: "ele_desc_"), "choose_type" => "Text Box"}}
    sd = service_dialog.create(label: dialog, description: "my dialog")
    tab = sd.tabs.create(tab_label: fauxfactory.gen_alphanumeric(start: "tab_"), tab_desc: "my tab desc")
    box = tab.boxes.create(box_label: fauxfactory.gen_alphanumeric(start: "box_"), box_desc: "my box desc")
    box.elements.create(element_data: [element_data])
    cat_item = appliance.collections.catalog_items.create(appliance.collections.catalog_items.ANSIBLE_PLAYBOOK, fauxfactory.gen_alphanumeric(15, start: "ansi_cat_item_"), fauxfactory.gen_alphanumeric(15, start: "item_desc_"), display_in_catalog: true, provisioning: {"repository" => ansible_repository.name, "playbook" => "dump_all_variables.yml", "machine_credential" => "CFME Default Credential", "use_exisiting" => true, "provisioning_dialog_id" => sd.label})
    catalog = appliance.collections.catalogs.create(fauxfactory.gen_alphanumeric(start: "ansi_cat_"), description: fauxfactory.gen_alphanumeric(start: "cat_dis_"), items: [cat_item.name])
    _finalize = lambda do
      if is_bool(catalog.exists)
        catalog.delete()
        cat_item.catalog = nil
      end
      cat_item.delete_if_exists()
      sd.delete_if_exists()
    end
    return [cat_item, catalog]
  end
  return _dialog_with_catalog_item
end
def ansible_linked_vm_action(appliance, local_ansible_catalog_item, create_vm)
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"playbook" => "add_single_vm_to_service.yml"}
  }
  action_values = {"run_ansible_playbook" => {"playbook_catalog_item" => local_ansible_catalog_item.name, "inventory" => {"specific_hosts" => true, "hosts" => create_vm.ip_address}}}
  action = appliance.collections.actions.create(fauxfactory.gen_alphanumeric(15, start: "action_"), action_type: "Run Ansible Playbook", action_values: action_values)
  yield action
  action.delete_if_exists()
end
def ansible_policy_linked_vm(appliance, create_vm, ansible_linked_vm_action)
  policy = appliance.collections.policies.create(VMControlPolicy, fauxfactory.gen_alpha(15, start: "policy_"), scope: )
  policy.assign_actions_to_event("Tag Complete", [ansible_linked_vm_action.description])
  policy_profile = appliance.collections.policy_profiles.create(fauxfactory.gen_alpha(15, start: "profile_"), policies: [policy])
  create_vm.assign_policy_profiles(policy_profile.description)
  yield
  policy_profile.delete_if_exists()
  policy.delete_if_exists()
end
def provider_credentials(appliance, provider, credential)
  cred_type,hostname,playbook = credential
  creds = provider.get_credentials_from_config(provider.data["credentials"])
  credentials = {}
  if cred_type == "Amazon"
    credentials["access_key"] = creds.principal
    credentials["secret_key"] = creds.secret
  else
    if cred_type == "Azure"
      azure_creds = conf.credentials[provider.data["credentials"]]
      credentials["username"] = azure_creds.ui_username
      credentials["password"] = azure_creds.ui_password
      credentials["subscription_id"] = azure_creds.subscription_id
      credentials["tenant_id"] = azure_creds.tenant_id
      credentials["client_secret"] = azure_creds.password
      credentials["client_id"] = azure_creds.username
    else
      credentials["username"] = creds.principal
      credentials["password"] = creds.secret
      credentials[hostname] = 
    end
  end
  credential = appliance.collections.ansible_credentials.create(, cred_type, None: credentials)
  yield credential
  credential.delete_if_exists()
end
def ansible_credential(appliance)
  credential = appliance.collections.ansible_credentials.create(fauxfactory.gen_alpha(start: "cred_"), "Machine", username: fauxfactory.gen_alpha(start: "usr_"), password: fauxfactory.gen_alpha(start: "pwd_"))
  yield credential
  credential.delete_if_exists()
end
def custom_service_button(appliance, local_ansible_catalog_item)
  buttongroup = appliance.collections.button_groups.create(text: fauxfactory.gen_alphanumeric(start: "grp_"), hover: fauxfactory.gen_alphanumeric(15, start: "grp_hvr_"), type: appliance.collections.button_groups.SERVICE)
  button = buttongroup.buttons.create(text: fauxfactory.gen_alphanumeric(start: "btn_"), hover: fauxfactory.gen_alphanumeric(15, start: "btn_hvr_"), dialog: local_ansible_catalog_item.provisioning["provisioning_dialog_name"], system: "Request", request: "Order_Ansible_Playbook")
  yield button
  button.delete_if_exists()
  buttongroup.delete_if_exists()
end
def test_service_ansible_playbook_available(appliance)
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: high
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  view = navigate_to(appliance.collections.catalog_items, "Choose Type")
  raise unless view.select_item_type.all_options.map{|option| option.text}.include?("Ansible Playbook")
end
def test_service_ansible_playbook_crud(appliance, ansible_repository)
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: critical
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  cat_item = appliance.collections.catalog_items.create(appliance.collections.catalog_items.ANSIBLE_PLAYBOOK, fauxfactory.gen_alphanumeric(15, "cat_item"), fauxfactory.gen_alphanumeric(15, "item_disc_"), provisioning: {"repository" => ansible_repository.name, "playbook" => "dump_all_variables.yml", "machine_credential" => "CFME Default Credential", "create_new" => true, "provisioning_dialog_name" => fauxfactory.gen_alphanumeric(12, start: "dialog_")})
  raise unless cat_item.exists
  update(cat_item) {
    new_name = fauxfactory.gen_alphanumeric(15, start: "edited_")
    cat_item.name = new_name
    cat_item.provisioning = {"playbook" => "copy_file_example.yml"}
  }
  view = navigate_to(cat_item, "Details")
  raise unless view.entities.title.text.include?(new_name)
  raise unless view.entities.provisioning.info.get_text_of("Playbook") == "copy_file_example.yml"
  cat_item.delete()
  raise unless !cat_item.exists
end
def test_service_ansible_playbook_tagging(ansible_catalog_item)
  #  Tests ansible_playbook tag addition, check added tag and removal
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: high
  #       initialEstimate: 1/2h
  #       tags: ansible_embed
  #       testSteps:
  #           1. Login as a admin
  #           2. Add tag for ansible_playbook
  #           3. Check added tag
  #           4. Remove the given tag
  #   
  added_tag = ansible_catalog_item.add_tag()
  raise "Assigned tag was not found" unless ansible_catalog_item.get_tags().include?(added_tag)
  ansible_catalog_item.remove_tag(added_tag)
  raise unless !ansible_catalog_item.get_tags().include?(added_tag)
end
def test_service_ansible_playbook_negative(appliance)
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       caseposneg: negative
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  collection = appliance.collections.catalog_items
  cat_item = collection.instantiate(collection.ANSIBLE_PLAYBOOK, "", "", {})
  view = navigate_to(cat_item, "Add")
  view.fill({"name" => fauxfactory.gen_alphanumeric(), "description" => fauxfactory.gen_alphanumeric()})
  raise unless !view.add.active
  view.browser.refresh()
end
def test_service_ansible_playbook_bundle(appliance, ansible_catalog_item)
  # Ansible playbooks are not designed to be part of a cloudforms service bundle.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       caseposneg: negative
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  view = navigate_to(appliance.collections.catalog_bundles, "Add")
  options = view.resources.select_resource.all_options
  raise unless !options.map{|o| o.text}.include?(ansible_catalog_item.name)
  view.browser.refresh()
end
def test_service_ansible_playbook_provision_in_requests(appliance, ansible_catalog_item, ansible_service, ansible_service_request, request)
  # Tests if ansible playbook service provisioning is shown in service requests.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  ansible_service.order()
  ansible_service_request.wait_for_request()
  cat_item_name = ansible_catalog_item.name
  request_descr = "Provisioning Service [{0}] from [{0}]".format(cat_item_name)
  service_request = appliance.collections.requests.instantiate(description: request_descr)
  service_id = appliance.rest_api.collections.service_requests.get(description: request_descr)
  _finalize = lambda do
    service = MyService(appliance, cat_item_name)
    if is_bool(service_request.exists())
      service_request.wait_for_request()
      appliance.rest_api.collections.service_requests.action.delete(id: service_id.id)
    end
    if is_bool(service.exists)
      service.delete()
    end
  end
  raise unless service_request.exists()
end
def test_service_ansible_playbook_confirm(appliance, soft_assert)
  # Tests after selecting playbook additional widgets appear and are pre-populated where
  #   possible.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  collection = appliance.collections.catalog_items
  cat_item = collection.instantiate(collection.ANSIBLE_PLAYBOOK, "", "", {})
  view = navigate_to(cat_item, "Add")
  raise unless view.provisioning.is_displayed
  raise unless view.retirement.is_displayed
  soft_assert.(view.provisioning.repository.is_displayed)
  soft_assert.(view.provisioning.verbosity.is_displayed)
  soft_assert.(view.provisioning.verbosity.selected_option == "0 (Normal)")
  soft_assert.(view.provisioning.localhost.is_displayed)
  soft_assert.(view.provisioning.specify_host_values.is_displayed)
  soft_assert.(view.provisioning.logging_output.is_displayed)
  soft_assert.(view.retirement.localhost.is_displayed)
  soft_assert.(view.retirement.specify_host_values.is_displayed)
  soft_assert.(view.retirement.logging_output.is_displayed)
  soft_assert.(view.retirement.remove_resources.selected_option == "Yes")
  soft_assert.(view.retirement.repository.is_displayed)
  soft_assert.(view.retirement.verbosity.is_displayed)
  soft_assert.(view.retirement.remove_resources.is_displayed)
  soft_assert.(view.retirement.verbosity.selected_option == "0 (Normal)")
end
def test_service_ansible_retirement_remove_resources(request, appliance, ansible_repository)
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: critical
  #       initialEstimate: 1/4h
  #       tags: ansible_embed
  #       setup:
  #           1. Go to User-Dropdown right upper corner --> Configuration
  #           2. Under Server roles --> Enable Embedded Ansible role.
  #           3. Wait for 15-20mins to start ansible server role.
  #       testSteps:
  #           1. Open creation screen of Ansible Playbook catalog item.
  #           2. Fill required fields.
  #           3. Open Retirement tab.
  #           4. Fill \"Remove resources?\" field with \"No\" value.
  #           5. Press \"Save\" button.
  #       expectedResults:
  #           1. Catalog should be created without any failure.
  #           2. Check required fields with exact details.
  #           3. Retirement tab should be open with default items.
  #           4. Check \"Remove resources?\" value updated with value \"No\".
  #           5. \"Remove resources\" should have correct value.
  #   
  cat_item = appliance.collections.catalog_items.create(appliance.collections.catalog_items.ANSIBLE_PLAYBOOK, fauxfactory.gen_alphanumeric(15, start: "cat_item_"), fauxfactory.gen_alphanumeric(15, start: "item_desc_"), provisioning: {"repository" => ansible_repository.name, "playbook" => "dump_all_variables.yml", "machine_credential" => "CFME Default Credential", "create_new" => true, "provisioning_dialog_name" => fauxfactory.gen_alphanumeric()}, retirement: {"remove_resources" => "No"})
  request.addfinalizer(cat_item.delete_if_exists)
  view = navigate_to(cat_item, "Details")
  raise unless view.entities.retirement.info.get_text_of("Remove Resources") == "No"
  cat_item.delete()
  raise unless !cat_item.exists
end
def test_service_ansible_playbook_order_retire(appliance, ansible_catalog_item, ansible_service_catalog, ansible_service_request, ansible_service, host_type, order_value, result, action, request)
  # Test ordering and retiring ansible playbook service against default host, blank field and
  #   unavailable host.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       initialEstimate: 1/4h
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       tags: ansible_embed
  #   
  ansible_service_catalog.ansible_dialog_values = {"hosts" => order_value}
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request()
  cat_item_name = ansible_catalog_item.name
  request_descr = "Provisioning Service [{0}] from [{0}]".format(cat_item_name)
  service_request = appliance.collections.requests.instantiate(description: request_descr)
  service_id = appliance.rest_api.collections.service_requests.get(description: request_descr)
  _finalize = lambda do
    service = MyService(appliance, cat_item_name)
    if is_bool(service_request.exists())
      service_request.wait_for_request()
      appliance.rest_api.collections.service_requests.action.delete(id: service_id.id)
    end
    if is_bool(service.exists)
      service.delete()
    end
  end
  if action == "retirement"
    ansible_service.retire()
  end
  view = navigate_to(ansible_service, "Details")
  raise unless result == view.provisioning.details.get_text_of("Hosts")
end
def test_service_ansible_playbook_plays_table(ansible_service_request, ansible_service, soft_assert)
  # Plays table in provisioned and retired service should contain at least one row.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: low
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  ansible_service.order()
  ansible_service_request.wait_for_request()
  view = navigate_to(ansible_service, "Details")
  soft_assert.(view.provisioning.plays.row_count > 1, "Plays table in provisioning tab is empty")
  ansible_service.retire()
  soft_assert.(view.provisioning.plays.row_count > 1, "Plays table in retirement tab is empty")
end
def test_service_ansible_playbook_order_credentials(local_ansible_catalog_item, ansible_credential, ansible_service_catalog)
  # Test if credentials avaialable in the dropdown in ordering ansible playbook service
  #   screen.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"machine_credential" => ansible_credential.name}
  }
  view = navigate_to(ansible_service_catalog, "Order")
  options = view.fields("credential").visible_widget.all_options.map{|o| o.text}
  raise unless Set.new(options).include?(ansible_credential.name)
end
def test_service_ansible_playbook_pass_extra_vars(ansible_service_catalog, ansible_service_request, ansible_service, action)
  # Test if extra vars passed into ansible during ansible playbook service provision and
  #   retirement.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/4h
  #       tags: ansible_embed
  #   
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request()
  if action == "retirement"
    ansible_service.retire()
  end
  view = navigate_to(ansible_service, "Details")
  if action == "provisioning"
    view.provisioning_tab.click()
  end
  stdout = view.getattr(action).standart_output
  stdout.wait_displayed()
  pre = stdout.text
  json_str = pre.split_p("--------------------------------")
  result_dict = json.loads(json_str[5].gsub("\", \"", "").gsub("\\\"", "\"").gsub("\\, \"", "\",").split_p("\" ] } PLAY")[0])
  raise unless result_dict["some_var"] == "some_value"
end
def test_service_ansible_execution_ttl(request, ansible_service_catalog, local_ansible_catalog_item, ansible_service, ansible_service_request)
  # Test if long running processes allowed to finish. There is a code that guarantees to have 100
  #   retries with a minimum of 1 minute per retry. So we need to run ansible playbook service more
  #   than 100 minutes and set max ttl greater than ansible playbook running time.
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 2h
  #       tags: ansible_embed
  # 
  #   Bugzilla:
  #       1519275
  #       1515841
  #   
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"playbook" => "long_running_playbook.yml", "max_ttl" => 200}
  }
  _revert = lambda do
    update(method(:local_ansible_catalog_item)) {
      local_ansible_catalog_item.provisioning = {"playbook" => "dump_all_variables.yml", "max_ttl" => ""}
    }
  end
  request.addfinalizer(method(:_revert))
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request(method: "ui", num_sec: 200 * 60, delay: 120)
  view = navigate_to(ansible_service, "Details")
  raise unless view.provisioning.results.get_text_of("Status") == "successful"
end
def test_custom_button_ansible_credential_list(custom_service_button, ansible_service_catalog, ansible_service, ansible_service_request, appliance)
  # Test if credential list matches when the Ansible Playbook Service Dialog is invoked from a
  #   Button versus a Service Order Screen.
  # 
  #   Bugzilla:
  #       1448918
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Automate
  #       caseimportance: medium
  #       initialEstimate: 1/3h
  #       tags: ansible_embed
  #   
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request()
  view = navigate_to(ansible_service, "Details")
  view.toolbar.custom_button(custom_service_button.group.text).item_select(custom_service_button.text)
  credentials_dropdown = BootstrapSelect(appliance.browser.widgetastic, locator: ".//select[@id='credential']/..")
  wait_for(lambda{|| credentials_dropdown.is_displayed}, timeout: 30)
  all_options = credentials_dropdown.all_options.map{|option| option.text}
  raise unless ["<Default>", "CFME Default Credential"] == all_options
end
def test_ansible_group_id_in_payload(ansible_service_catalog, ansible_service_request, ansible_service)
  # Test if group id is presented in manageiq payload.
  # 
  #   Bugzilla:
  #       1480019
  # 
  #   In order to get manageiq payload the service's standard output should be parsed.
  # 
  #   Bugzilla:
  #       1480019
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request()
  view = navigate_to(ansible_service, "Details")
  stdout = view.provisioning.standart_output
  wait_for(lambda{|| stdout.is_displayed}, timeout: 10)
  pre = stdout.text
  json_str = pre.split_p("--------------------------------")
  result_dict = json.loads(json_str[5].gsub("\", \"", "").gsub("\\\"", "\"").gsub("\\, \"", "\",").split_p("\" ] } PLAY")[0])
  raise unless result_dict["manageiq"].include?("group")
end
def test_embed_tower_exec_play_against(appliance, request, local_ansible_catalog_item, ansible_service, ansible_service_catalog, credential, provider_credentials)
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/4h
  #       tags: ansible_embed
  #   
  playbook = credential[2]
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"playbook" => playbook, "cloud_type" => provider_credentials.credential_type, "cloud_credential" => provider_credentials.name}
  }
  _revert = lambda do
    update(method(:local_ansible_catalog_item)) {
      local_ansible_catalog_item.provisioning = {"playbook" => "dump_all_variables.yml", "cloud_type" => "<Choose>"}
    }
    service = MyService(appliance, local_ansible_catalog_item.name)
    if is_bool(service_request.exists())
      service_request.wait_for_request()
      appliance.rest_api.collections.service_requests.action.delete(id: service_id.id)
    end
    if is_bool(service.exists)
      service.delete()
    end
  end
  service_request = ansible_service_catalog.order()
  service_request.wait_for_request(num_sec: 300, delay: 20)
  request_descr = 
  service_request = appliance.collections.requests.instantiate(description: request_descr)
  service_id = appliance.rest_api.collections.service_requests.get(description: request_descr)
  view = navigate_to(ansible_service, "Details")
  raise unless view.provisioning.results.get_text_of("Status") == "successful"
end
def test_service_ansible_verbosity(appliance, request, local_ansible_catalog_item, ansible_service_catalog, ansible_service_request, ansible_service, verbosity)
  # Check if the different Verbosity levels can be applied to service and
  #   monitor the std out
  #   Bugzilla:
  #       1460788
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       tags: ansible_embed
  #   
  pattern = "\"verbosity\"=>{}".format(verbosity[0])
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"verbosity" => verbosity}
    local_ansible_catalog_item.retirement = {"verbosity" => verbosity}
  }
  log = LogValidator("/var/www/miq/vmdb/log/evm.log", matched_patterns: [pattern])
  log.start_monitoring()
  _revert = lambda do
    service = MyService(appliance, local_ansible_catalog_item.name)
    if is_bool(ansible_service_request.exists())
      ansible_service_request.wait_for_request()
      appliance.rest_api.collections.service_requests.action.delete(id: service_request.id)
    end
    if is_bool(service.exists)
      service.delete()
    end
  end
  ansible_service_catalog.order()
  ansible_service_request.wait_for_request()
  request_descr = 
  service_request = appliance.rest_api.collections.service_requests.get(description: request_descr)
  raise unless log.validate(wait: "60s")
  logger.info()
  view = navigate_to(ansible_service, "Details")
  raise unless verbosity[0] == view.provisioning.details.get_text_of("Verbosity")
  raise unless verbosity[0] == view.retirement.details.get_text_of("Verbosity")
end
def test_ansible_service_linked_vm(appliance, create_vm, ansible_policy_linked_vm, ansible_service_request, ansible_service, request)
  # Check Whether service has associated VM attached to it.
  # 
  #   Bugzilla:
  #       1448918
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       initialEstimate: 1/3h
  #       tags: ansible_embed
  #   
  create_vm.add_tag()
  wait_for(ansible_service_request.exists, num_sec: 600)
  ansible_service_request.wait_for_request()
  view = navigate_to(ansible_service, "Details")
  raise unless view.entities.vms.all_entity_names.include?(create_vm.name)
end
def test_ansible_service_order_vault_credentials(appliance, request, ansible_catalog_item, ansible_service_catalog, ansible_service_request_funcscope, ansible_service_funcscope)
  # 
  #   Add vault password and test in the playbook that encrypted yml can be
  #   decrypted.
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       initialEstimate: 1/2h
  #       tags: ansible_embed
  #   
  creds = conf.credentials["vault_creds"]["password"]
  creds_dict = {"vault_password" => creds}
  vault_creds = appliance.collections.ansible_credentials.create(, "Vault", None: creds_dict)
  update(ansible_catalog_item) {
    ansible_catalog_item.provisioning = {"playbook" => "dump_secret_variable_from_vault.yml", "vault_credential" => vault_creds.name}
  }
  _revert = lambda do
    update(ansible_catalog_item) {
      ansible_catalog_item.provisioning = {"playbook" => "dump_all_variables.yml", "vault_credential" => "<Choose>"}
    }
    vault_creds.delete_if_exists()
  end
  ansible_service_catalog.order()
  ansible_service_request_funcscope.wait_for_request()
  view = navigate_to(ansible_service_funcscope, "Details")
  raise unless view.provisioning.credentials.get_text_of("Vault") == vault_creds.name
  status = (appliance.version < "5.11") ? "successful" : "Finished"
  raise unless view.provisioning.results.get_text_of("Status") == status
end
def test_ansible_service_ansible_galaxy_role(appliance, request, ansible_catalog_item, ansible_service_catalog, ansible_service_funcscope, ansible_service_request_funcscope)
  # Check Role is fetched from Ansible Galaxy by using roles/requirements.yml file
  #   from playbook.
  # 
  #   Bugzilla:
  #       1734904
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       initialEstimate: 1/3h
  #       tags: ansible_embed
  #   
  old_playbook_value = ansible_catalog_item.provisioning
  update(method(:local_ansible_catalog_item)) {
    local_ansible_catalog_item.provisioning = {"playbook" => "ansible_galaxy_role_users.yaml"}
  }
  _revert = lambda do
    update(method(:local_ansible_catalog_item)) {
      local_ansible_catalog_item.provisioning["playbook"] = old_playbook_value["playbook"]
    }
  end
  service_request = ansible_service_catalog.order()
  service_request.wait_for_request(num_sec: 300, delay: 20)
  view = navigate_to(ansible_service_funcscope, "Details")
  raise unless (appliance.version < "5.11") ? view.provisioning.results.get_text_of("Status") == "successful" : "Finished"
end
def test_ansible_service_with_operations_role_disabled(appliance, ansible_catalog_item, ansible_service_catalog, ansible_service_funcscope, ansible_service_request_funcscope)
  # If the embedded ansible role is *not* on the same server as the ems_operations role,
  #   then the run will never start.
  #   Bugzilla:
  #       1742839
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       initialEstimate: 1/3h
  #       tags: ansible_embed
  #   
  service_request = ansible_service_catalog.order()
  service_request.wait_for_request(num_sec: 300, delay: 20)
  raise unless ansible_service_funcscope.status == "Finished"
end
def test_ansible_service_cloud_credentials(appliance, request, local_ansible_catalog_item, ansible_service_catalog, credential, provider_credentials, ansible_service_funcscope, ansible_service_request_funcscope)
  # 
  #       When the service is viewed in my services it should also show that the Cloud Credentials
  #       were attached to the service.
  # 
  #   Bugzilla:
  #       1444092
  #       1515561
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       initialEstimate: 1/4h
  #       tags: ansible_embed
  #   
  old_playbook_value = local_ansible_catalog_item.provisioning
  playbook = credential[2]
  update(local_ansible_catalog_item) {
    local_ansible_catalog_item.provisioning = {"playbook" => playbook, "cloud_type" => provider_credentials.credential_type, "cloud_credential" => provider_credentials.name}
  }
  _revert = lambda do
    update(method(:local_ansible_catalog_item)) {
      local_ansible_catalog_item.provisioning["playbook"] = old_playbook_value["playbook"]
    }
  end
  service_request = ansible_service_catalog.order()
  service_request.wait_for_request(num_sec: 300, delay: 20)
  view = navigate_to(ansible_service_funcscope, "Details")
  raise unless view.provisioning.credentials.get_text_of("Cloud") == provider_credentials.name
end
def test_service_ansible_service_name(request, appliance, dialog_with_catalog_item)
  # 
  #   After creating the service using ansible playbook type add a new text
  #   field to service dialog named \"service_name\" and then use that service
  #   to order the service which will have a different name than the service
  #   catalog item.
  # 
  #   Bugzilla:
  #       1505929
  # 
  #   Polarion:
  #       assignee: gtalreja
  #       casecomponent: Ansible
  #       caseimportance: medium
  #       initialEstimate: 1/2h
  #       tags: ansible_embed
  #   
  ele_name = "service_name"
  ansible_cat_item,ansible_catalog = dialog_with_catalog_item.(ele_name)
  service_catalogs = ServiceCatalogs(appliance, ansible_catalog, ansible_cat_item.name)
  view = navigate_to(service_catalogs, "Order")
  service_name = fauxfactory.gen_alphanumeric(20, start: "diff_service_name")
  view.fields(ele_name).fill(service_name)
  time.sleep(5)
  view.submit_button.click()
  request_descr = 
  service_request = appliance.collections.requests.instantiate(description: request_descr)
  service_request.wait_for_request()
  _revert = lambda do
    if is_bool(service_request.exists)
      service_request.wait_for_request()
      service_request.remove_request()
    end
    if is_bool(service.exists)
      service.delete()
    end
  end
  service = MyService(appliance, service_name)
  raise unless service.exists
end
