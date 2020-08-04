require_relative("widgetastic_patternfly");
include(Widgetastic_patternfly);
require_relative("cfme");
include(Cfme);
require_relative("cfme/automate/buttons");
include(Cfme.Automate.Buttons);
require_relative("cfme/automate/buttons");
include(Cfme.Automate.Buttons);
require_relative("cfme/automate/buttons");
include(Cfme.Automate.Buttons);
require_relative("cfme/automate/simulation");
include(Cfme.Automate.Simulation);
require_relative("cfme/base/ui");
include(Cfme.Base.Ui);
require_relative("cfme/infrastructure/provider/virtualcenter");
include(Cfme.Infrastructure.Provider.Virtualcenter);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/tests/automate/custom_button");
include(Cfme.Tests.Automate.Custom_button);
require_relative("cfme/tests/automate/custom_button");
include(Cfme.Tests.Automate.Custom_button);
require_relative("cfme/tests/automate/custom_button");
include(Cfme.Tests.Automate.Custom_button);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/blockers");
include(Cfme.Utils.Blockers);
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);
require_relative("cfme/utils/update");
include(Cfme.Utils.Update);
require_relative("cfme/utils/wait");
include(Cfme.Utils.Wait);
require_relative("cfme/utils/wait");
include(Cfme.Utils.Wait);

let pytestmark = [
  test_requirements.custom_button,
  pytest.mark.usefixtures("uses_infra_providers")
];

function button_group(appliance, obj_type) {
  let collection = appliance.collections.button_groups;

  let button_gp = collection.create({
    text: fauxfactory.gen_alphanumeric({start: "grp_"}),
    hover: fauxfactory.gen_alphanumeric({start: "hover_"}),
    type: collection.getattr(obj_type)
  });

  yield(button_gp);
  button_gp.delete_if_exists()
};

function test_button_group_crud(request, appliance, obj_type) {
  // Test crud operation for Button Group
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: critical
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Create a Button Group with random button text and hover, select type Service
  //           2. Assert that the button group exists
  //           3. Assert that the entered values correspond with what is displayed on the details page
  //           4. Change the hover text, ensure the text is changed on details page
  //           5. Delete the button group
  //           6. Assert that the button group no longer exists.
  //   
  let collection = appliance.collections.button_groups;

  let buttongroup = collection.create({
    text: fauxfactory.gen_alphanumeric({start: "grp_"}),
    hover: fauxfactory.gen_alphanumeric({start: "hov_"}),
    icon_color: "#ff0000",
    type: collection.getattr(obj_type, null)
  });

  request.addfinalizer(buttongroup.delete_if_exists);

  let view = buttongroup.create_view(
    ButtonGroupObjectTypeView,
    {wait: "10s"}
  );

  view.flash.assert_success_message(`Button Group \"${buttongroup.hover}\" was added`);
  if (!buttongroup.exists) throw new ();
  view = navigate_to(buttongroup, "Details");
  if (view.text.text != buttongroup.text) throw new ();
  if (view.hover.text != buttongroup.hover) throw new ();
  view = navigate_to(buttongroup, "Edit");
  view.cancel_button.click();
  view.flash.assert_success_message(`Edit of Button Group \"${buttongroup.text}\" was cancelled by the user`);
  if (!buttongroup.exists) throw new ();

  let updated_text = fauxfactory.gen_alphanumeric(
    15,
    {start: "edited_grp_"}
  );

  let updated_hover = fauxfactory.gen_alphanumeric(
    15,
    {start: "edited_hvr_"}
  );

  update(buttongroup, () => {
    buttongroup.text = updated_text;
    buttongroup.hover = updated_hover
  });

  buttongroup.create_view(ButtonGroupDetailView, {wait: "10s"});
  view.flash.assert_success_message(`Button Group \"${updated_hover}\" was saved`);
  if (!buttongroup.exists) throw new ();
  view = navigate_to(buttongroup, "Details");
  if (view.text.text != updated_text) throw new ();
  if (view.hover.text != updated_hover) throw new ();
  buttongroup.delete({cancel: true});
  if (!view.is_displayed) throw new ();
  if (!buttongroup.exists) throw new ();
  buttongroup.delete();

  view = buttongroup.create_view(
    ButtonGroupObjectTypeView,
    {wait: "10s"}
  );

  view.flash.assert_success_message(`Button Group \"${buttongroup.hover}\": Delete successful`);
  if (!!buttongroup.exists) throw new ()
};

function test_button_crud(appliance, dialog, request, button_group, obj_type) {
  // Test crud operation for Custom Button
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: critical
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Create a Button with random button text and button hover text, and random request
  //           2. Assert that the button exists
  //           3. Assert that the entered values correspond with what is displayed on the details page
  //           4. Change the hover text, ensure the text is changed on details page
  //           5. Delete the button
  //           6. Assert that the button no longer exists.
  // 
  //   Bugzilla:
  //       1143019
  //       1205235
  //   
  let button = button_group.buttons.create({
    text: fauxfactory.gen_alphanumeric({start: "btn_"}),
    hover: fauxfactory.gen_alphanumeric({start: "hvr_"}),
    icon_color: "#ff0000",
    dialog,
    system: "Request",
    request: "InspectMe"
  });

  request.addfinalizer(button.delete_if_exists);

  let view = button_group.create_view(
    ButtonGroupDetailView,
    {wait: "10s"}
  );

  view.flash.assert_message(`Custom Button \"${button.hover}\" was added`);
  if (!button.exists) throw new ();
  view = navigate_to(button, "Details");
  if (view.text.text != button.text) throw new ();
  if (view.hover.text != button.hover) throw new ();
  if (view.dialog.text != dialog.label) throw new ();
  if (view.request.text != button.request) throw new ();
  view = navigate_to(button, "Edit");
  view.cancel_button.click();
  view.flash.assert_success_message(`Edit of Custom Button \"${button.text}\" was cancelled by the user`);

  let edited_text = fauxfactory.gen_alphanumeric(
    15,
    {start: "edit_btn_"}
  );

  let edited_hover = fauxfactory.gen_alphanumeric(
    15,
    {start: "edit_hvr_"}
  );

  let edited_request = fauxfactory.gen_alphanumeric(
    15,
    {start: "edit_req_"}
  );

  update(button, () => {
    button.text = edited_text;
    button.hover = edited_hover;
    button.system = "Automation";
    button.request = edited_request
  });

  view = button.create_view(ButtonDetailView, {wait: "10s"});
  view.flash.assert_success_message(`Custom Button \"${button.hover}\" was saved`);
  if (!button.exists) throw new ();
  view = navigate_to(button, "Details");
  if (view.text.text != edited_text) throw new ();
  if (view.hover.text != edited_hover) throw new ();
  if (view.system.text != "Automation") throw new ();
  if (view.request.text != edited_request) throw new ();
  button.delete({cancel: true});
  if (!view.is_displayed) throw new ();
  if (!button.exists) throw new ();
  button.delete();
  view = button_group.create_view(ButtonGroupDetailView, {wait: "10s"});
  view.flash.assert_message(`Button \"${button.hover}\": Delete successful`);
  if (!!button.exists) throw new ()
};

function test_button_avp_displayed(appliance, dialog, request) {
  // This test checks whether the Attribute/Values pairs are displayed in the dialog.
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/12h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Open a dialog to create a button.
  //           2. Locate the section with attribute/value pairs.
  // 
  //   Bugzilla:
  //       1229348
  //       1460774
  //   
  let buttongroup = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned buttons",
    type: appliance.collections.button_groups.VM_INSTANCE
  });

  let buttons_collection = appliance.collections.buttons;
  buttons_collection.group = buttongroup;
  let view = navigate_to(buttons_collection, "Add");

  for (let n in (1).upto(6 - 1)) {
    if (!view.advanced.attributes.fields(n.to_s).attribute.is_displayed) {
      throw new ()
    };

    if (!view.advanced.attributes.fields(n.to_s).value.is_displayed) throw new ()
  };

  view.cancel_button.click()
};

function test_button_required(appliance, field) {
  let msg;

  // Test Icon and Request are required field while adding custom button.
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: low
  //       caseposneg: positive
  //       testtype: nonfunctional
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       setup: Button Group
  //       testSteps:
  //           1. Try to add custom button without icon/request
  //           2. Assert flash message.
  //   
  let unassigned_gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned Buttons",
    type: "VM and Instance"
  });

  let button_coll = appliance.collections.buttons;
  button_coll.group = unassigned_gp;
  let view = navigate_to(button_coll, "Add");

  view.fill({
    options: {
      text: fauxfactory.gen_alphanumeric(),
      hover: fauxfactory.gen_alphanumeric(),
      open_url: true
    },

    advanced: {system: "Request", request: "InspectMe"}
  });

  if (field == "icon") {
    msg = "Button Icon must be selected"
  } else if (field == "request") {
    view.fill({options: {image: "fa-user"}, advanced: {request: ""}});
    msg = "Request is required"
  };

  view.title.click();
  view.add_button.click();
  view.flash.assert_message(msg);
  view.cancel_button.click()
};

function test_open_url_availability(appliance) {
  // Test open URL option should only available for Single display.
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: low
  //       caseposneg: positive
  //       testtype: nonfunctional
  //       startsin: 5.9
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       setup: Button Group
  //       testSteps:
  //           1. Create a Button with other than Single display options
  //           2. Assert flash message.
  // 
  //   Bugzilla:
  //       1706900
  //   
  let unassigned_gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned buttons",
    type: "VM and Instance"
  });

  let button_coll = appliance.collections.buttons;
  button_coll.group = unassigned_gp;
  let view = navigate_to(button_coll, "Add");
  if (!view.options.open_url.is_enabled) throw new ();

  view.fill({
    options: {
      text: "test_open_url",
      hover: "Open Url Test",
      image: "fa-user",
      open_url: true
    },

    advanced: {system: "Request", request: "InspectMe"}
  });

  for (let display in ["List", "Single and list"]) {
    view.options.display_for.fill(display);

    if (appliance.version < "5.11") {
      view.add_button.click();
      view.flash.assert_message("URL can be opened only by buttons for a single entity")
    } else if (!!view.options.open_url.is_enabled) {
      throw new ()
    }
  };

  view.cancel_button.click()
};

function test_custom_button_quotes(appliance, provider, setup_provider, dialog, request) {
  //  Test custom button and group allows quotes or not
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: nonfunctional
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       setup: Simple TextInput service dialog
  //       testSteps:
  //           1. Create custom button group with single quote in name like \"Group\'s\"
  //           2. Create a custom button with quote in name like \"button\'s\"
  //           3. Navigate to object Details page
  //           4. Check for button group and button
  //           5. Select/execute button from group dropdown for selected entities
  //           6. Fill dialog and submit Check for the flash message related to button execution
  // 
  //   Bugzilla:
  //       1646905
  //   
  let collection = appliance.collections.button_groups;

  let group = collection.create({
    text: "Group's",
    hover: "Group's Hover",
    type: collection.getattr("PROVIDER")
  });

  request.addfinalizer(group.delete_if_exists);

  let button = group.buttons.create({
    text: "Button's",
    hover: "Button's Hover",
    dialog,
    system: "Request",
    request: "InspectMe"
  });

  request.addfinalizer(button.delete_if_exists);
  let view = navigate_to(provider, "Details");
  let custom_button_group = Dropdown(view, group.hover);
  if (!custom_button_group.has_item(button.text)) throw new ();
  custom_button_group.item_select(button.text);

  let dialog_view = view.browser.create_view(
    TextInputDialogView,
    {wait: "60s"}
  );

  dialog_view.service_name.fill("Custom Button Execute");
  dialog_view.submit.click();
  view.flash.assert_message("Order Request was Submitted")
};

function test_custom_button_simulation(request, appliance, provider, setup_provider, button_tag) {
  let btn_type, obj;

  //  Test whether custom button works with simulation option
  //   Note: For version less than 5.10 EVM custom button object not supported.
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       testtype: functional
  //       startsin: 5.9
  //       casecomponent: CustomButton
  //       tags: custom_button
  // 
  //   Bugzilla:
  //       1535215
  //   
  if (button_tag == "Evm") {
    btn_type = "User";
    obj = appliance.collections.users.instantiate({name: "Administrator"})
  } else {
    btn_type = "Provider";
    obj = provider
  };

  let gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned buttons",
    type: btn_type
  });

  let button = gp.buttons.create({
    text: fauxfactory.gen_alphanumeric({start: "btn_"}),
    hover: fauxfactory.gen_alphanumeric(15, {start: "btn_hvr_"}),
    system: "Request",
    request: "InspectMe"
  });

  request.addfinalizer(button.delete_if_exists);

  if (!appliance.ssh_client.run_command("echo -n \"\" > /var/www/miq/vmdb/log/automation.log")) {
    throw new ()
  };

  button.simulate({
    target_object: obj.name,
    instance: button.system,
    request: button.request
  });

  let view = appliance.browser.create_view(AutomateSimulationView);
  view.flash.assert_message("Automation Simulation has been run");

  try {
    wait_for(log_request_check, [appliance, 1], {
      timeout: 600,
      message: "Check for expected request count",
      delay: 20
    })
  } catch ($EXCEPTION) {
    if ($EXCEPTION instanceof TimedOutError) {
      if (!false) throw "Requests not found in automation log"
    } else {
      throw $EXCEPTION
    }
  }
};

function test_custom_button_order_sort(appliance, request, provider, setup_provider, button_tag) {
  let btn_type, obj;

  //  Test custom button order reflection on destination
  //   # ToDo: Now, we are testing this against single object per group tag. If need extends for all.
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       testtype: functional
  //       startsin: 5.9
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Create [Unassigned Buttons] custom buttons
  //           2. Create custom button Group with unassigned buttons
  //           3. Navigate to object Details page
  //           4. Check for custom button order
  //           5. Update order of custom buttons
  //           6. Navigate to object Details page
  //           7. Check for custom button order updated or not
  //   Bugzilla:
  //       1628737
  //   
  if (button_tag == "Evm") {
    btn_type = "Group";
    obj = appliance.collections.groups.instantiate({description: "EvmGroup-super_administrator"})
  } else {
    btn_type = "Provider";
    obj = provider
  };

  let unassigned_gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned buttons",
    type: btn_type
  });

  let buttons = [];

  for (let ind in (0).upto(4 - 1)) {
    let button = unassigned_gp.buttons.create({
      text: fauxfactory.gen_alphanumeric({start: `btn_${ind}_`}),
      hover: fauxfactory.gen_alphanumeric(15, {start: `btn_hvr_${ind}_`}),
      system: "Request",
      request: "InspectMe"
    });

    buttons.push(button)
  };

  let _clean = () => {
    for (let btn in buttons) {
      btn.delete_if_exists()
    }
  };

  let unassigned_buttons = buttons.map(btn => btn.text);

  let group = appliance.collections.button_groups.create({
    text: fauxfactory.gen_alphanumeric({start: "grp_"}),
    hover: fauxfactory.gen_alphanumeric(15, {start: "grp_hvr_"}),
    type: btn_type,
    assign_buttons: unassigned_buttons
  });

  request.addfinalizer(group.delete_if_exists);
  let view = navigate_to(obj, "Details");
  let custom_button_group = Dropdown(view, group.hover);
  if (custom_button_group.to_a != unassigned_buttons) throw new ();
  let shuffle_buttons = unassigned_buttons.to_a;
  random.shuffle(shuffle_buttons, random.random);
  update(group, () => group.assign_buttons = shuffle_buttons);
  navigate_to(obj, "Details");
  if (custom_button_group.to_a != shuffle_buttons) throw new ()
};

function test_custom_button_role_selection(appliance, request) {
  // Test custom button role selection
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/6h
  //       caseimportance: medium
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       testSteps:
  //           1. Add custom button with specific roles and verify from summary page
  //           2. Update roles and verify
  //           3. Update button for role access to All and verify
  // 
  //   Bugzilla:
  //       1703588
  //   
  let test_roles = ["EvmRole-administrator", "EvmRole-security"];

  let unassigned_gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned Buttons",
    type: "Provider"
  });

  let btn = unassigned_gp.buttons.create({
    text: fauxfactory.gen_alphanumeric({start: "grp_"}),
    hover: fauxfactory.gen_alphanumeric(15, {start: "grp_hvr_"}),
    system: "Request",
    request: "InspectMe",
    roles: test_roles
  });

  request.addfinalizer(btn.delete_if_exists);
  if (btn.user_roles != test_roles) throw new ();
  test_roles.push("EvmRole-user_self_service");
  btn.update({roles: test_roles});
  if (btn.user_roles != test_roles) throw new ();
  btn.update({role_show: "<To All>"});
  if (btn.user_roles != "To All") throw new ()
};

//  There was bug with usecase before... (#1568417)
// 
//   Polarion:
//       assignee: ndhandre
//       initialEstimate: 1/4h
//       caseimportance: low
//       caseposneg: positive
//       testtype: functional
//       startsin: 5.9
//       casecomponent: CustomButton
//       tags: custom_button
//       testSteps:
//           1. set the language to french
//           2. go to automation-> automate -> customization
//           3. check the custom buttons tree should not empty from automation
//       expectedResults:
//           1.
//           2. Navigate as per french i18n code
//           3. check we are getting french i18n code in tree
// 
//   Bugzilla:
//       1568417
//   
// pass
function test_custom_button_language() {};

function test_attribute_override(appliance, request, provider, setup_provider, obj_type, button_group) {
  //  Test custom button attribute override
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: nonfunctional
  //       startsin: 5.9
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. create a custom button to request the call_instance_with_message
  //           2. set the message to create
  //           3. set the attributes instance, class, namespace to \"whatever\"
  //           4. set the attribute message to \"my_message\"
  //           5. save it
  // 
  //   Bugzilla:
  //       1651099
  //   
  let attributes = {
    class: "Request",
    instance: "TestNotification",
    message: "digitronik_msg",
    namespace: "/System"
  };

  let req = "call_instance_with_message";

  let patterns = [
    "[miqaedb:/System/Request/TestNotification#create]",
    "[miqaedb:/System/Request/TestNotification#digitronik_msg]"
  ];

  let button = button_group.buttons.create({
    text: fauxfactory.gen_alphanumeric({start: "btn_"}),
    hover: fauxfactory.gen_alphanumeric({start: "hvr_"}),
    system: "Request",
    request: req,
    attributes
  });

  request.addfinalizer(button.delete_if_exists);

  let log = LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: patterns}
  );

  log.start_monitoring();
  let view = navigate_to(provider, "Details");
  let custom_button_group = Dropdown(view, button_group.hover);
  custom_button_group.item_select(button.text);
  button.simulate(provider.name, {request: req});
  log.validate({wait: "120s"})
};

function test_simulated_object_copy_on_button(appliance, provider, setup_provider, button_type) {
  let target_type, target_obj;

  //  Test copy of simulated object over custom button
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       caseposneg: positive
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. simulate button with Automate -> Simulation
  //           2. copy simulated data
  //           3. paste simulated data on button from Automate -> Customizationn -> Buttons
  //           4. check copy-paste working or not
  // 
  //   Bugzilla:
  //       1426390
  //       1719282
  //   
  if (button_type == "User") {
    target_type = "{}User".format((appliance.version < "5.11" ? "EVM " : ""));
    target_obj = "Administrator"
  } else {
    target_type = "Provider";
    target_obj = provider.name
  };

  let attributes = {
    class: "Request",
    instance: "TestNotification",
    message: "digitronik_msg",
    namespace: "/System"
  };

  simulate({
    appliance,
    instance: "Automation",
    message: "test_bz",
    request: "InspectMe",
    target_type,
    target_object: target_obj,
    execute_methods: true,
    pre_clear: true,
    attributes_values: attributes
  });

  let view = appliance.browser.create_view(
    AutomateSimulationView,
    {wait: "15s"}
  );

  view.copy.click();
  let button_coll = appliance.collections.buttons;

  button_coll.group = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned buttons",
    type: button_type
  });

  view = navigate_to(button_coll, "Add");
  view.paste.click();
  if (view.advanced.system.read() != "Automation") throw new ();
  if (view.advanced.message.read() != "test_bz") throw new ();
  if (view.advanced.request.read() != "InspectMe") throw new ();
  let attributes_on_page = view.advanced.attributes.read();

  for (let [key, value] in attributes_on_page.to_a()) {
    if (attributes[key] != value) throw new ()
  }
};

function test_under_group_multiple_button_crud(appliance, obj_type, button_group, dialog) {
  // Test multiple button creation and deletion under same group
  // 
  //   Bugzilla:
  //       1755229
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/10h
  //       caseimportance: critical
  //       startsin: 5.8
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Create a Button Group
  //           2. Create button and delete button
  //           3. Repeat step-2 multiple time
  //   
  let view = navigate_to(button_group, "Details");

  for (let exp in ["enablement", "visibility"]) {
    let expression = {exp: {
      tag: "My Company Tags : Department",
      value: "Engineering"
    }};

    let button = button_group.buttons.create({
      text: fauxfactory.gen_alphanumeric({start: "btn_"}),
      hover: fauxfactory.gen_alphanumeric({start: "hover_"}),
      dialog,
      system: "Request",
      request: "InspectMe",
      None: expression
    });

    view.flash.assert_message(`Custom Button \"${button.hover}\" was added`);
    if (!button.exists) throw new ();
    button.delete();
    view.flash.assert_message(`Button \"${button.hover}\": Delete successful`);
    if (!!button.exists) throw new ();
    if (!button_group.exists) throw new ()
  }
};

function test_custom_button_service_dialog_link(request, appliance, dialog) {
  // Test service dialog linked with custom button should not raise FATAL Error; if custom button
  //   delete before service dialog
  // 
  //   Bugzilla:
  //       1770300
  // 
  // 
  //   Polarion:
  //       assignee: ndhandre
  //       initialEstimate: 1/10h
  //       caseimportance: high
  //       startsin: 5.9
  //       casecomponent: CustomButton
  //       tags: custom_button
  //       testSteps:
  //           1. Create a service dialog
  //           2. Creating a new custom button and associating it to a service dialog.
  //           3. Delete a custom button before service dialog deletion
  //           4. Delete service dialog and check production log
  //   
  let unassigned_gp = appliance.collections.button_groups.instantiate({
    text: "[Unassigned Buttons]",
    hover: "Unassigned Buttons",
    type: "Provider"
  });

  let btn = unassigned_gp.buttons.create({
    text: fauxfactory.gen_alphanumeric({start: "btn_"}),
    hover: fauxfactory.gen_alphanumeric(15, {start: "btn_hvr_"}),
    dialog,
    system: "Request",
    request: "InspectMe"
  });

  request.addfinalizer(btn.delete_if_exists);

  (LogValidator(
    "/var/www/miq/vmdb/log/production.log",
    {failure_patterns: [".*FATAL.*"]}
  )).waiting({timeout: 120}, () => {
    btn.delete();
    if (!!btn.exists) throw new ();
    dialog.delete();
    if (!!dialog.exists) throw new ()
  })
}
