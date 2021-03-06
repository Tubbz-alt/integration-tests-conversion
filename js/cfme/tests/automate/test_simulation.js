require_relative("cfme");
include(Cfme);
require_relative("cfme/automate/simulation");
include(Cfme.Automate.Simulation);
require_relative("cfme/base/ui");
include(Cfme.Base.Ui);
require_relative("cfme/control/explorer/actions");
include(Cfme.Control.Explorer.Actions);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/blockers");
include(Cfme.Utils.Blockers);
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);
let pytestmark = [test_requirements.automate, pytest.mark.tier(2)];

function test_object_attributes(appliance) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/16h
  // 
  //   Bugzilla:
  //       1719322
  //   
  let view = navigate_to(appliance.server, "AutomateSimulation");

  for (let object_type in view.target_type.all_options[_.range(1, 0)]) {
    view.reset_button.click();

    if (is_bool(BZ(1719322, {forced_streams: ["5.10", "5.11"]}).blocks && [
      "Group",
      "EVM Group",
      "Tenant"
    ].include(object_type.text))) {
      continue
    } else {
      view.target_type.select_by_visible_text(object_type.text);
      if (view.target_object.all_options.size <= 0) throw new ()
    }
  }
};

function copy_class(domain) {
  domain.parent.instantiate({name: "ManageIQ"}).namespaces.instantiate({name: "System"}).classes.instantiate({name: "Request"}).copy_to(domain.name);
  let klass = domain.namespaces.instantiate({name: "System"}).classes.instantiate({name: "Request"});
  return klass
};

function test_assert_failed_substitution(copy_class) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/4h
  //       caseposneg: negative
  //       tags: automate
  // 
  //   Bugzilla:
  //       1335669
  //   
  let instance = copy_class.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {guard: {value: "${/#this_value_does_not_exist}"}}
  });

  pytest.raises(
    RuntimeError,
    {match: "Automation Error: Attribute this_value_does_not_exist not found"},

    () => (
      simulate({
        appliance: copy_class.appliance,

        attributes_values: {
          namespace: copy_class.namespace.name,
          class: copy_class.name,
          instance: instance.name
        },

        message: "create",
        request: "Call_Instance",
        execute_methods: true
      })
    )
  )
};

function test_automate_simulation_result_has_hash_data(custom_instance) {
  // 
  //   The UI should display the result objects if the Simulation Result has
  //   hash data.
  // 
  //   Bugzilla:
  //       1445089
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/6h
  //       tags: automate
  //       testSteps:
  //           1. Create a Instance under /System/Request called ListUser, update it so that it points
  //              to a ListUser Method
  //           2. Create ListUser Method under /System/Request, paste the Attached Method
  //           3. Run Simulation
  //       expectedResults:
  //           1.
  //           2.
  //           3. The UI should display the result objects
  //   
  let instance = custom_instance.call({ruby_code: user_list_hash_data});

  (LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [".*User List.*:id=>1, :name=>\"Fred\".*"]}
  )).waiting({timeout: 120}, () => (
    simulate({
      appliance: instance.appliance,

      attributes_values: {
        namespace: instance.klass.namespace.name,
        class: instance.klass.name,
        instance: instance.name
      },

      message: "create",
      request: "Call_Instance",
      execute_methods: true
    })
  ));

  let view = instance.create_view(AutomateSimulationView);

  if ((view.result_tree.click_path(
    `ManageIQ/SYSTEM / PROCESS / ${instance.klass.name}`,
    `ManageIQ/System / ${instance.klass.name} / Call_Instance`,
    `${instance.domain.name}/System / ${instance.klass.name} / ${instance.name}`,
    "values",
    "Hash",
    "Key"
  )).text != "Key") throw new ()
};

function test_simulation_copy_button(appliance) {
  // 
  //   Bugzilla:
  //       1630800
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       caseposneg: positive
  //       startsin: 5.10
  //       casecomponent: Automate
  //       testSteps:
  //           1. Go to Automation > Automate > Simulation
  //           2. Fill in any required fields to enable submit button and click on 'Submit'
  //           4. Change any field - for example 'Object Attribute'
  //           5. Select Copy button
  //       expectedResults:
  //           1. Copy button should be disabled
  //           2. Copy button should be enabled
  //           3.
  //           4.
  //           5. Copy button should be disabled until form is submitted
  //   
  let view = navigate_to(appliance.server, "AutomateSimulation");
  if (!!view.copy.is_enabled) throw new ();

  view.fill({
    instance: "Request",
    message: "Hello",
    request: "InspectMe",
    execute_methods: true,
    target_type: "EVM User",
    target_object: "Administrator"
  });

  view.submit_button.click();
  if (!view.copy.is_enabled) throw new ();
  view.target_type.select_by_visible_text("Provider");
  if (!!view.copy.is_enabled) throw new ()
};

function test_attribute_value_message(custom_instance) {
  // 
  //   Bugzilla:
  //       1753523
  //       1740761
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       caseposneg: positive
  //       casecomponent: Automate
  //       setup:
  //           1. Create domain, namespace, class and instance pointing to method
  //       testSteps:
  //           1. Navigate to automate > automation > simulation page
  //           2. Fill values for attribute/value pairs of namespace, class, instance and add message
  //              attribute with any value and click on submit.
  //           3. See automation.log
  //       expectedResults:
  //           1.
  //           2.
  //           3. Custom message attribute should be considered with instance in logs
  //   
  let instance = custom_instance.call({ruby_code: null});
  let msg = fauxfactory.gen_alphanumeric();

  (LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [`.*${instance.name}#${msg}.*`]}
  )).waiting({timeout: 120}, () => (
    simulate({
      appliance: instance.appliance,

      attributes_values: {
        namespace: instance.klass.namespace.name,
        class: instance.klass.name,
        instance: instance.name,
        message: msg
      },

      message: "create",
      request: "call_instance_with_message",
      execute_methods: true
    })
  ))
};

function test_action_invoke_custom_automation(request, appliance) {
  // 
  //   Bugzilla:
  //       1672007
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       caseposneg: positive
  //       casecomponent: Automate
  //       testSteps:
  //           1. Navigate to Control > explorer > actions
  //           2. Select 'add a new action' from configuration dropdown
  //           3. Add description and select 'Action Type' - Invoke custom automation
  //           4. Fill attribute value pairs and click on add
  //           5. Edit the created action and add new attribute value pair
  //           6. Remove that newly added attribute value pair before clicking on save and then click
  //              on save
  //       expectedResults:
  //           1.
  //           2.
  //           3.
  //           4.
  //           5. Save button should enabled
  //           6. Action should be saved successfully
  //   
  let attr_val = (2).times.map(_ => (
    (1).upto(6 - 1).map(num => [`attribute_${num}`, fauxfactory.gen_alpha()]).to_h
  ));

  let automation_action = appliance.collections.actions.create(
    fauxfactory.gen_alphanumeric(),
    "Invoke a Custom Automation",
    {}
  );

  request.addfinalizer(automation_action.delete_if_exists);
  let view = navigate_to(automation_action, "Edit");
  view.attribute_value_pair.fill(attr_val[1]);
  if (!view.save_button.is_enabled) throw new ();
  view.attribute_value_pair.clear();
  view.save_button.click();

  view = automation_action.create_view(
    ActionDetailsView,
    {wait: "10s"}
  );

  view.flash.assert_success_message(`Action \"${automation_action.description}\" was saved`)
}
