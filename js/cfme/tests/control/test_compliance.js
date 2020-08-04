require_relative("wrapanapi");
include(Wrapanapi);
require_relative("cfme");
include(Cfme);
require_relative("cfme/control/explorer/conditions");
include(Cfme.Control.Explorer.Conditions);
require_relative("cfme/control/explorer/policies");
include(Cfme.Control.Explorer.Policies);
require_relative("cfme/control/explorer/policies");
include(Cfme.Control.Explorer.Policies);
require_relative("cfme/infrastructure/provider/virtualcenter");
include(Cfme.Infrastructure.Provider.Virtualcenter);
require_relative("cfme/tests/control");
include(Cfme.Tests.Control);
require_relative("cfme/utils");
include(Cfme.Utils);
require_relative("cfme/utils/update");
include(Cfme.Utils.Update);

let pytestmark = [
  pytest.mark.meta({server_roles: [
    "+automate",
    "+smartstate",
    "+smartproxy"
  ]}),

  pytest.mark.tier(3),
  test_requirements.control,
  pytest.mark.provider([VMwareProvider], {scope: "module"}),
  pytest.mark.usefixtures("setup_provider_modscope")
];

function policy_name() {
  return fauxfactory.gen_alphanumeric(
    35,
    {start: "compliance_testing: policy "}
  )
};

function policy_profile_name() {
  return fauxfactory.gen_alphanumeric(
    43,
    {start: "compliance_testing: policy profile "}
  )
};

function host(provider, setup_provider) {
  return provider.hosts.all()[0]
};

function policy_for_testing(appliance, policy_name, policy_profile_name) {
  let policy = appliance.collections.policies.create(
    HostCompliancePolicy,
    policy_name
  );

  let policy_profile = appliance.collections.policy_profiles.create(
    policy_profile_name,
    {policies: [policy]}
  );

  yield(policy);
  policy_profile.delete();
  policy.delete()
};

function assign_policy_for_testing(policy_for_testing, host, policy_profile_name) {
  host.assign_policy_profiles(policy_profile_name);
  yield(policy_for_testing);
  host.unassign_policy_profiles(policy_profile_name)
};

function compliance_vm(configure_fleecing_modscope, provider, full_template_modscope) {
  let name = fauxfactory.gen_alpha(20, {start: "test-compliance-"});
  let collection = provider.appliance.provider_based_collection(provider);

  let vm = collection.instantiate(
    name,
    provider,
    full_template_modscope.name
  );

  if (provider.version == 6.5) {
    vm.create_on_provider({
      allow_skip: "default",
      host: conf.cfme_data.management_systems[provider.key].hosts[0].name
    })
  } else {
    vm.create_on_provider({allow_skip: "default"})
  };

  vm.mgmt.ensure_state(VmState.RUNNING);
  if (is_bool(!vm.exists)) vm.wait_to_appear({timeout: 900});
  yield(vm);
  vm.cleanup_on_provider();
  provider.refresh_provider_relationships()
};

function analysis_profile(appliance) {
  let ap = appliance.collections.analysis_profiles.instantiate({
    name: "default",
    description: "ap-desc",
    profile_type: appliance.collections.analysis_profiles.VM_TYPE,

    categories: [
      "Services",
      "User Accounts",
      "Software",
      "VM Configuration",
      "System"
    ]
  });

  if (is_bool(ap.exists)) ap.delete();

  appliance.collections.analysis_profiles.create({
    name: "default",
    description: "ap-desc",
    profile_type: appliance.collections.analysis_profiles.VM_TYPE,

    categories: [
      "Services",
      "User Accounts",
      "Software",
      "VM Configuration",
      "System"
    ]
  });

  yield(ap);
  if (is_bool(ap.exists)) ap.delete()
};

function test_check_package_presence(request, appliance, compliance_vm, analysis_profile) {
  // This test checks compliance by presence of a certain \"kernel\" package which is expected
  //   to be present on the full_template.
  // 
  //   Metadata:
  //       test_flag: provision, policy
  // 
  //   Bugzilla:
  //       1730805
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/4h
  //       casecomponent: Control
  //       caseimportance: high
  //   
  let condition = appliance.collections.conditions.create(
    VMCondition,

    fauxfactory.gen_alphanumeric(
      40,
      {start: "Compliance testing condition "}
    ),

    {expression: "fill_find(field=VM and Instance.Guest Applications : Name, skey=STARTS WITH, value=kernel, check=Check Count, ckey= = , cvalue=1)"}
  );

  request.addfinalizer(() => diaper(condition.delete));

  let policy = appliance.collections.policies.create(
    VMCompliancePolicy,
    fauxfactory.gen_alphanumeric(15, {start: "Compliance "})
  );

  request.addfinalizer(() => diaper(policy.delete));
  policy.assign_conditions(condition);

  let profile = appliance.collections.policy_profiles.create(
    fauxfactory.gen_alphanumeric(20, {start: "Compliance PP "}),
    {policies: [policy]}
  );

  request.addfinalizer(() => diaper(profile.delete));
  compliance_vm.assign_policy_profiles(profile.description);

  request.addfinalizer(() => (
    compliance_vm.unassign_policy_profiles(profile.description)
  ));

  do_scan(compliance_vm);
  compliance_vm.check_compliance();
  if (!compliance_vm.compliant) throw new ()
};

function test_check_files(request, appliance, compliance_vm, analysis_profile) {
  // This test checks presence and contents of a certain file. Due to caching, an existing file
  //   is checked.
  // 
  //   Metadata:
  //       test_flag: provision, policy
  // 
  //   Bugzilla:
  //       1730805
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/4h
  //       casecomponent: Control
  //       caseimportance: high
  //   
  let check_file_name = "/etc/hosts";
  let check_file_contents = "127.0.0.1";

  let condition = appliance.collections.conditions.create(
    VMCondition,

    fauxfactory.gen_alphanumeric(
      40,
      {start: "Compliance testing condition "}
    ),

    {expression: "fill_find(VM and Instance.Files : Name, =, {}, Check Any, Contents, INCLUDES, {})".format(
      check_file_name,
      check_file_contents
    )}
  );

  request.addfinalizer(() => diaper(condition.delete));

  let policy = appliance.collections.policies.create(
    VMCompliancePolicy,
    fauxfactory.gen_alphanumeric(15, {start: "Compliance "})
  );

  request.addfinalizer(() => diaper(policy.delete));
  policy.assign_conditions(condition);

  let profile = appliance.collections.policy_profiles.create(
    fauxfactory.gen_alphanumeric(20, {start: "Compliance PP "}),
    {policies: [policy]}
  );

  request.addfinalizer(() => diaper(profile.delete));
  compliance_vm.assign_policy_profiles(profile.description);

  request.addfinalizer(() => (
    compliance_vm.unassign_policy_profiles(profile.description)
  ));

  update(analysis_profile, () => (
    analysis_profile.files = [{
      Name: check_file_name,
      "Collect Contents?": true
    }]
  ));

  do_scan(compliance_vm, ["Configuration", "Files"]);
  compliance_vm.check_compliance();
  if (!compliance_vm.compliant) throw new ()
};

function test_compliance_with_unconditional_policy(host, assign_policy_for_testing) {
  // 
  // 
  //   Metadata:
  //       test_flag: policy
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/6h
  //       casecomponent: Control
  //       caseimportance: high
  //   
  assign_policy_for_testing.assign_actions_to_event(
    "Host Compliance Check",
    {"Mark as Non-Compliant": true}
  );

  host.check_compliance();
  if (!!host.is_compliant) throw new ()
}
