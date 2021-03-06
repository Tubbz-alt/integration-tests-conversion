require_relative("textwrap");
include(Textwrap);
require_relative("cfme");
include(Cfme);
require_relative("cfme/automate/explorer/klass");
include(Cfme.Automate.Explorer.Klass);
require_relative("cfme/automate/simulation");
include(Cfme.Automate.Simulation);
require_relative("cfme/rest/gen_data");
include(Cfme.Rest.Gen_data);
var _users = users.bind(this);
require_relative("cfme/services/service_catalogs");
include(Cfme.Services.Service_catalogs);
require_relative("cfme/utils/appliance/implementations/rest");
include(Cfme.Utils.Appliance.Implementations.Rest);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/blockers");
include(Cfme.Utils.Blockers);
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);
require_relative("cfme/utils/update");
include(Cfme.Utils.Update);
require_relative("cfme/utils/wait");
include(Cfme.Utils.Wait);
let pytestmark = [test_requirements.automate, pytest.mark.tier(2)];

function original_class(domain) {
  domain.parent.instantiate({name: "ManageIQ"}).namespaces.instantiate({name: "System"}).classes.instantiate({name: "Request"}).copy_to(domain.name);
  let klass = domain.namespaces.instantiate({name: "System"}).classes.instantiate({name: "Request"});
  return klass
};

function test_method_crud(klass) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: critical
  //       initialEstimate: 1/16h
  //       tags: automate
  //   
  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: "$evm.log(:info, \":P\")"
  });

  let view = method.create_view(ClassDetailsView);
  view.flash.assert_message(`Automate Method \"${method.name}\" was added`);
  if (!method.exists) throw new ();
  let origname = method.name;

  update(method, () => {
    method.name = fauxfactory.gen_alphanumeric(8);
    method.script = "bar"
  });

  if (!method.exists) throw new ();
  update(method, () => method.name = origname);
  if (!method.exists) throw new ();
  method.delete();
  if (!!method.exists) throw new ()
};

function test_automate_method_inputs_crud(appliance, klass) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       initialEstimate: 1/8h
  //       caseimportance: critical
  //       tags: automate
  //   
  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: "blah",

    inputs: {
      foo: {data_type: "string"},
      bar: {data_type: "integer", default_value: "42"}
    }
  });

  if (!method.exists) throw new ();
  let view = navigate_to(method, "Details");
  if (!view.inputs.is_displayed) throw new ();

  if (view.inputs.read() != {
    foo: {"Data Type": "string", "Default Value": ""},
    bar: {"Data Type": "integer", "Default Value": "42"}
  }) throw new ();

  update(
    method,
    () => method.inputs = {different: {default_value: "value"}}
  );

  view = navigate_to(method, "Details");
  if (!view.inputs.is_displayed) throw new ();

  if (view.inputs.read() != {different: {
    "Data Type": "string",
    "Default Value": "value"
  }}) throw new ();

  update(method, () => method.inputs = {});
  view = navigate_to(method, "Details");
  if (!!view.inputs.is_displayed) throw new ();
  method.delete()
};

function test_duplicate_method_disallowed(klass) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseposneg: negative
  //       initialEstimate: 1/10h
  //       caseimportance: critical
  //       tags: automate
  //   
  let name = fauxfactory.gen_alpha();

  klass.methods.create({
    name,
    location: "inline",
    script: "$evm.log(:info, \":P\")"
  });

  pytest.raises(
    Exception,
    {match: "Name has already been taken"},

    () => (
      klass.methods.create({
        name,
        location: "inline",
        script: "$evm.log(:info, \":P\")"
      })
    )
  )
};

function test_automate_simulate_retry(klass, domain, namespace, original_class) {
  // Automate simulation now supports simulating the state machines.
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.6
  //       casecomponent: Automate
  //       tags: automate
  //       setup:
  //           1. Create a state machine that contains a couple of states
  //       testSteps:
  //           1. Create an Automate model that has a State Machine that can end in a retry
  //           2. Run a simulation to test the Automate Model from Step 1
  //           3. When the Automation ends in a retry, we should be able to resubmit the request
  //           4. Use automate simulation UI to call the state machine (Call_Instance)
  //       expectedResults:
  //           1.
  //           2.
  //           3.
  //           4. A Retry button should appear.
  // 
  //   Bugzilla:
  //       1299579
  //   
  klass.schema.add_fields({
    name: "RUN",
    type: "Method",
    data_type: "String"
  });

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: `root = $evm.root 

                  if root['ae_state_retries'] && root['ae_state_retries'] > 2 

                  \t \t root['ae_result'] = 'ok'
 else \t \t root['ae_result'] = 'retry' 
 end`
  });

  let instance = klass.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {RUN: {value: method.name}}
  });

  let new_class = namespace.collections.classes.create({name: fauxfactory.gen_alphanumeric()});

  new_class.schema.add_fields({
    name: "STATE1",
    type: "State",
    data_type: "String"
  });

  let new_instance = new_class.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),

    fields: {STATE1: {value: ("/{domain}/{namespace}/{klass}/{instance}").format({
      domain: domain.name,
      namespace: namespace.name,
      klass: klass.name,
      instance: instance.name
    })}}
  });

  let original_instance = original_class.instances.create({
    name: fauxfactory.gen_alphanumeric(),

    fields: {rel1: {value: ("/{domain}/{namespace}/{klass}/{instance}").format({
      domain: domain.name,
      namespace: namespace.name,
      klass: new_class.name,
      instance: new_instance.name
    })}}
  });

  let view = navigate_to(klass.appliance.server, "AutomateSimulation");
  if (!!view.retry_button.is_displayed) throw new ();

  simulate({
    appliance: klass.appliance,
    instance: "Request",
    message: "create",
    request: original_instance.name,
    execute_methods: true
  });

  if (!view.retry_button.is_displayed) throw new ()
};

function test_task_id_for_method_automation_log(request, generic_catalog_item) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/30h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: Automate
  //       tags: automate
  //       setup:
  //           1. Add existing or new automate method to newly created domain or create generic service
  //       testSteps:
  //           1. Run that instance using simulation or order service catalog item
  //           2. See automation log
  //       expectedResults:
  //           1.
  //           2. Task id should be included in automation log for method logs.
  // 
  //   Bugzilla:
  //       1592428
  //   
  let result = LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [".*Q-task_id.*"]}
  );

  result.start_monitoring();
  let service_request = generic_catalog_item.appliance.rest_api.collections.service_templates.get({name: generic_catalog_item.name}).action.order();
  request.addfinalizer(service_request.action.delete);

  wait_for(
    () => service_request.request_state == "active",
    {fail_func: service_request.reload, timeout: 60, delay: 3}
  );

  if (!result.validate({wait: "60s"})) throw new ()
};

function test_send_email_method(smtp_test, klass) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/20h
  //       startsin: 5.10
  //       casecomponent: Automate
  // 
  //   Bugzilla:
  //       1688500
  //       1702304
  //   
  let mail_to = fauxfactory.gen_email();
  let mail_cc = fauxfactory.gen_email();
  let mail_bcc = fauxfactory.gen_email();
  let schema_field = fauxfactory.gen_alphanumeric();
  let script = `to = \"{mail_to}\"
subject = \"Hello\"
body = \"Hi\"
bcc = \"{mail_bcc}\"
cc = \"{mail_cc}\"
content_type = \"message\"
from = \"cfadmin@cfserver.com\"
$evm.execute(:send_email, to, from, subject, body, {{:bcc => bcc, :cc => cc,:content_type => content_type}})`;
  script = script.format({mail_cc, mail_bcc, mail_to});

  klass.schema.add_fields({
    name: schema_field,
    type: "Method",
    data_type: "String"
  });

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script
  });

  let instance = klass.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {schema_field: {value: method.name}}
  });

  let result = LogValidator(
    "/var/www/miq/vmdb/log/evm.log",

    {matched_patterns: [(".*:to=>\"{mail_to}\".*.*:cc=>\"{mail_cc}\".*.*:bcc=>\"{mail_bcc}\".*").format({
      mail_to,
      mail_cc,
      mail_bcc
    })]}
  );

  result.start_monitoring();

  simulate({
    appliance: klass.appliance,

    attributes_values: {
      namespace: klass.namespace.name,
      class: klass.name,
      instance: instance.name
    },

    message: "create",
    request: "Call_Instance",
    execute_methods: true
  });

  if (!result.validate({wait: "60s"})) throw new ();

  wait_for(
    () => smtp_test.get_emails({to_address: mail_to}).size > 0,
    {num_sec: 60, delay: 10}
  )
};

function generic_object_definition(appliance) {
  appliance.context.use(ViaREST, () => {
    let definition = appliance.collections.generic_object_definitions.create({
      name: fauxfactory.gen_numeric_string(18, {start: "LoadBalancer_"}),
      description: "LoadBalancer",
      attributes: {location: "string"},
      associations: {vms: "Vm", services: "Service"}
    })
  });

  yield(definition);
  appliance.context.use(ViaREST, () => definition.delete_if_exists())
};

function go_service_request(generic_catalog_item) {
  let service_request = generic_catalog_item.appliance.rest_api.collections.service_templates.get({name: generic_catalog_item.name}).action.order();
  yield;
  service_request.action.delete()
};

function test_automate_generic_object_service_associations(appliance, klass, go_service_request, generic_object_definition) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/10h
  //       caseimportance: medium
  //       startsin: 5.7
  //       casecomponent: Automate
  // 
  //   Bugzilla:
  //       1410920
  //   
  let schema_field = fauxfactory.gen_alphanumeric();
  let script = "go_class = $evm.vmdb(:generic_object_definition).find_by(:name => \"{name}\")\n".format({name: generic_object_definition.name});
  script = script + `load_balancer = go_class.create_object(:name => \"Test Load Balancer\", :location => \"Mahwah\")
$evm.log(\"info\", \"XYZ go object: \#{load_balancer.inspect}\")
service = $evm.vmdb(:service).first
load_balancer.services = [service]
content_type = \"message\"
load_balancer.save!
$evm.log(\"info\", \"XYZ load balancer got service: \#{load_balancer.services.first.inspect}\")
exit MIQ_OK`;

  appliance.context.use(ViaUI, () => {
    klass.schema.add_fields({
      name: schema_field,
      type: "Method",
      data_type: "String"
    });

    let method = klass.methods.create({
      name: fauxfactory.gen_alphanumeric(),
      display_name: fauxfactory.gen_alphanumeric(),
      location: "inline",
      script
    });

    let instance = klass.instances.create({
      name: fauxfactory.gen_alphanumeric(),
      display_name: fauxfactory.gen_alphanumeric(),
      description: fauxfactory.gen_alphanumeric(),
      fields: {schema_field: {value: method.name}}
    });

    let result = LogValidator(
      "/var/www/miq/vmdb/log/automation.log",

      {matched_patterns: [
        ".*XYZ go object: #<MiqAeServiceGenericObject.*",
        ".*XYZ load balancer got service: #<MiqAeServiceService.*"
      ]}
    );

    result.start_monitoring();

    simulate({
      appliance: klass.appliance,

      attributes_values: {
        namespace: klass.namespace.name,
        class: klass.name,
        instance: instance.name
      },

      message: "create",
      request: "Call_Instance",
      execute_methods: true
    });

    if (!result.validate({wait: "60s"})) throw new ()
  })
};

function test_automate_service_quota_runs_only_once(appliance, generic_catalog_item) {
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/4h
  //       tags: automate
  // 
  //   Bugzilla:
  //       1317698
  //   
  let pattern = ".*Getting Tenant Quota Values for:.*";

  let result = LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [pattern]}
  );

  result.start_monitoring();

  let service_catalogs = ServiceCatalogs(appliance, {
    catalog: generic_catalog_item.catalog,
    name: generic_catalog_item.name
  });

  let provision_request = service_catalogs.order();
  provision_request.wait_for_request();
  if (result.matches[pattern] != 1) throw new ()
};

function test_embedded_method_selection(klass) {
  // 
  //   Bugzilla:
  //       1718495
  //       1523379
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       casecomponent: Automate
  //       testSteps:
  //           1. Create a new inline method in CloudForms Automate.
  //           2. Add an embedded method.
  //       expectedResults:
  //           1.
  //           2. Selected embedded method should be visible
  //   
  let path = [
    "Datastore",
    "ManageIQ (Locked)",
    "System",
    "CommonMethods",
    "Utils",
    "log_object"
  ];

  let view = navigate_to(klass.methods, "Add");
  view.fill({location: "Inline", embedded_method: path});

  if (view.embedded_method_table.read()[0].Path != `/${path[_.range(
    2,
    0
  )].join("/")}`) throw new ()
};

function test_automate_state_method(klass) {
  // 
  //   You can pass methods as states compared to the old method of passing
  //   instances which had to be located in different classes. You use the
  //   METHOD:: prefix
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/4h
  //       tags: automate
  //       startsin: 5.6
  //       testSteps:
  //           1. Create an automate class that has one state.
  //           2. Create a method in the class, make the method output
  //              something recognizable in the logs
  //           3. Create an instance inside the class, and as a Value for the
  //              state use: METHOD::method_name where method_name is the name
  //              of the method you created
  //           4. Run a simulation, use Request / Call_Instance to call your
  //              state machine instance
  //       expectedResults:
  //           1. Class created
  //           2. Method created
  //           3. Instance created
  //           4. The method got called, detectable by grepping logs
  //   
  let state = fauxfactory.gen_alpha();
  klass.schema.add_fields({name: state, type: "State"});

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: `\n$evm.log(:info, \"Hello from state method\")`
  });

  let instance = klass.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {state: {value: `METHOD::${method.name}`}}
  });

  let result = LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [".*Hello from state method.*"]}
  );

  result.start_monitoring();

  simulate({
    appliance: klass.appliance,

    attributes_values: {
      namespace: klass.namespace.name,
      class: klass.name,
      instance: instance.name
    },

    message: "create",
    request: "Call_Instance",
    execute_methods: true
  });

  if (!result.validate()) throw new ()
};

function test_method_for_log_and_notify(request, klass, notify_level, log_level) {
  // 
  //   PR:
  //       https://github.com/ManageIQ/manageiq-content/pull/423
  //       https://github.com/ManageIQ/manageiq-content/pull/362
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       startsin: 5.9
  //       casecomponent: Automate
  //       testSteps:
  //           1. Create a new Automate Method
  //           2. In the Automate Method screen embed ManageIQ/System/CommonMethods/Utils/log_object
  //              you can pick this method from the UI tree picker
  //           3. In your method add a line akin to
  //              ManageIQ::Automate::System::CommonMethods::Utils::LogObject.log_and_notify
  //              (:info, \"Hello Testing Log & Notify\", $evm.root[\'vm\'], $evm)
  //           4. Check the logs and In your UI session you should see a notification
  //   
  let schema_name = fauxfactory.gen_alpha();

  klass.schema.add_fields({
    name: schema_name,
    type: "Method",
    data_type: "String"
  });

  request.addfinalizer(() => klass.schema.delete_field(schema_name));

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",

    embedded_method: [
      "Datastore",
      "ManageIQ (Locked)",
      "System",
      "CommonMethods",
      "Utils",
      "log_object"
    ],

    script: `
               
ManageIQ::Automate::System::CommonMethods::Utils::LogObject.log_ar_objects()
               
ManageIQ::Automate::System::CommonMethods::Utils::LogObject.current()
               
ManageIQ::Automate::System::CommonMethods::Utils::LogObject.log_and_notify({},
                              \"Hello Testing Log & Notify\", $evm.root['vm'], $evm)
               `.format(notify_level)
  });

  request.addfinalizer(method.delete_if_exists);

  let instance = klass.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {schema_name: {value: method.name}}
  });

  request.addfinalizer(instance.delete_if_exists);

  let result = LogValidator("/var/www/miq/vmdb/log/automation.log", {
    matched_patterns: [
      `.*Validating Notification type: automate_user_${log_level}.*`,
      `.*Calling Create Notification type: automate_user_${log_level}.*`,
      ".*Hello Testing Log & Notify.*"
    ],

    failure_patterns: [".*ERROR.*"]
  });

  result.start_monitoring();

  simulate({
    appliance: klass.appliance,
    message: "create",
    request: "Call_Instance",
    execute_methods: true,

    attributes_values: {
      namespace: klass.namespace.name,
      class: klass.name,
      instance: instance.name
    }
  });

  if (log_level == "error") {
    pytest.raises(
      FailPatternMatchError,
      {match: "Pattern '.*ERROR.*': Expected failure pattern found in log."},
      () => result.validate({wait: "60s"})
    )
  } else {
    result.validate({wait: "60s"})
  }
};

function test_null_coalescing_fields(request, klass) {
  // 
  //   Bugzilla:
  //       1698184
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/8h
  //       caseimportance: high
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: Automate
  //       tags: automate
  //       testSteps:
  //           1.  Create a Ruby method or Ansible playbook method with Input Parameters.
  //           2.  Use Data Type null coalescing
  //           3.  Make the default value something like this : ${#var3} || ${#var2} || ${#var1}
  //       expectedResults:
  //           1.
  //           2.
  //           3. Normal null coalescing behavior
  //   
  let [var1, var2, var3, var4] = (4).times.map(_ => fauxfactory.gen_alpha());

  klass.schema.add_fields(...[
    [var1, "fred", "Attribute"],
    [var2, "george", "Attribute"],
    [var3, " ", "Attribute"],
    [var4, "", "Method"]
  ].map((var, value, var_type) => ({
    name: var,
    type: var_type,
    data_type: "String",
    default_value: value
  })));

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: dedent(`\n            $evm.log(:info, \"Hello world\")\n            `),

    inputs: {
      arg1: {
        data_type: "null coalescing",
        default_value: ["${#", var1, "} ||${#", var2, "} ||${#", var3, "}"].join("")
      },

      arg2: {
        data_type: "null coalescing",
        default_value: ["${#", var2, "} ||${#", var1, "} ||${#", var3, "}"].join("")
      }
    }
  });

  request.addfinalizer(method.delete_if_exists);

  let instance = klass.instances.create({
    name: fauxfactory.gen_alphanumeric(),
    description: fauxfactory.gen_alphanumeric(),
    fields: {var4: {value: method.name}}
  });

  request.addfinalizer(instance.delete_if_exists);

  let log = LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [".*\\[{\\\"arg1\\\"=>\\\"fred\\\", \\\"arg2\\\"=>\\\"george\\\"}\\].*"]}
  );

  log.start_monitoring();

  simulate({
    appliance: instance.klass.appliance,
    message: "create",
    request: "Call_Instance",
    execute_methods: true,

    attributes_values: {
      namespace: instance.klass.namespace.name,
      class: instance.klass.name,
      instance: instance.name
    }
  });

  if (!log.validate()) throw new ()
};

function test_automate_user_has_groups(request, appliance, custom_instance) {
  // 
  //   This method should work:  groups = $evm.vmdb(:user).first.miq_groups
  //   $evm.log(:info, \"Displaying the user\"s groups: \#{groups.inspect}\")
  // 
  //   Bugzilla:
  //       1411424
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       caseimportance: medium
  //       initialEstimate: 1/12h
  //       tags: automate
  //       startsin: 5.8
  //   
  let [user, user_data] = _users(request, appliance);
  let script = dedent(`\n        group = $evm.vmdb(:user).find_by_name(\"${user[0].name}\").miq_groups\n        $evm.log(:info, \"Displaying the user's groups: \#{group.inspect}\")\n        `);
  let instance = custom_instance.call({ruby_code: script});

  (LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: [`.*${user_data[0].group.description}.*`]}
  )).waiting({timeout: 120}, () => (
    simulate({
      appliance: instance.klass.appliance,
      message: "create",
      request: "Call_Instance",
      execute_methods: true,

      attributes_values: {
        namespace: instance.klass.namespace.name,
        class: instance.klass.name,
        instance: instance.name
      }
    })
  ))
};

function test_copy_with_embedded_method(request, appliance, klass) {
  // 
  //   When copying a method within the automate model the copied method
  //   does not have the Embedded Methods that are a part of the source method
  // 
  //   Bugzilla:
  //       1592140
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       initialEstimate: 1/2h
  //       testSteps:
  //           1. Create a method in the automate model that has one or more Embedded Methods added
  //           2. Copy the method to a new domain
  //   
  let path = [
    "Datastore",
    "ManageIQ (Locked)",
    "System",
    "CommonMethods",
    "Utils",
    "log_object"
  ];

  let embedded_method_path = `/${path[_.range(2, 0)].join("/")}`;

  let method = klass.methods.create({
    name: fauxfactory.gen_alphanumeric(),
    display_name: fauxfactory.gen_alphanumeric(),
    location: "inline",
    script: "$evm.log(:info, \":P\")",
    embedded_method: path
  });

  request.addfinalizer(method.delete_if_exists);
  let view = navigate_to(method, "Details");

  if (view.embedded_method_table.read()[0].Path != embedded_method_path) {
    throw new ()
  };

  let domain = appliance.collections.domains.create({
    name: fauxfactory.gen_alpha(),
    description: fauxfactory.gen_alpha(),
    enabled: true
  });

  request.addfinalizer(domain.delete_if_exists);
  method.copy_to(domain.name);
  let copied_method = domain.namespaces.instantiate(klass.namespace.name).classes.instantiate(klass.name).methods.instantiate(method.name);
  view = navigate_to(copied_method, "Details");

  if (view.embedded_method_table.read()[0].Path != embedded_method_path) {
    throw new ()
  }
};

function test_delete_tag_from_category(custom_instance) {
  // 
  //   Bugzilla:
  //       1744514
  //       1767901
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       casecomponent: Automate
  //       initialEstimate: 1/12h
  //   
  let instance = custom_instance.call({ruby_code: tag_delete_from_category});

  (LogValidator(
    "/var/www/miq/vmdb/log/automation.log",
    {matched_patterns: ["true", "false"].map(value => `.*Tag exists: ${value}.*`)}
  )).waiting({timeout: 120}, () => (
    simulate({
      appliance: instance.klass.appliance,
      message: "create",
      request: "Call_Instance",
      execute_methods: true,

      attributes_values: {
        namespace: instance.klass.namespace.name,
        class: instance.klass.name,
        instance: instance.name
      }
    })
  ))
}
