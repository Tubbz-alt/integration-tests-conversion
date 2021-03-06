require_relative("riggerlib");
include(Riggerlib);
require_relative("cfme");
include(Cfme);
require_relative("cfme/infrastructure/provider/rhevm");
include(Cfme.Infrastructure.Provider.Rhevm);
require_relative("cfme/infrastructure/provider/virtualcenter");
include(Cfme.Infrastructure.Provider.Virtualcenter);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/provisioning");
include(Cfme.Provisioning);
require_relative("cfme/utils/generators");
include(Cfme.Utils.Generators);
require_relative("cfme/utils/log");
include(Cfme.Utils.Log);
require_relative("cfme/utils/update");
include(Cfme.Utils.Update);

let pytestmark = [
  test_requirements.quota,
  pytest.mark.usefixtures("setup_provider"),

  pytest.mark.provider(
    [RHEVMProvider, VMwareProvider],
    {scope: "module", selector: ONE_PER_TYPE}
  )
];

const NUM_GROUPS = NUM_TENANTS = 3;

function admin_email(appliance) {
  // Required for user quota tagging services to work, as it's mandatory for it's functioning.
  let user = appliance.collections.users;
  let admin = user.instantiate({name: "Administrator"});
  update(admin, () => admin.email = fauxfactory.gen_email());
  yield;
  update(admin, () => admin.email = "")
};

function vm_name() {
  return random_vm_name({context: "quota"})
};

function template_name(provider) {
  if (is_bool(provider.one_of(RHEVMProvider))) {
    return provider.data.templates.get("full_template").name
  } else if (is_bool(provider.one_of(VMwareProvider))) {
    return provider.data.templates.get("big_template").name
  }
};

function prov_data(vm_name) {
  return {
    catalog: {vm_name: vm_name},
    environment: {automatic_placement: true}
  }
};

function domain(appliance) {
  let domain = appliance.collections.domains.create(
    fauxfactory.gen_alphanumeric(15, {start: "domain_"}),
    fauxfactory.gen_alphanumeric(15, {start: "domain_desc_"}),
    {enabled: true}
  );

  yield(domain);
  if (is_bool(domain.exists)) domain.delete()
};

function max_quota_test_instance(appliance, domain) {
  let miq = appliance.collections.domains.instantiate("ManageIQ");
  let original_instance = miq.namespaces.instantiate("System").namespaces.instantiate("CommonMethods").classes.instantiate("QuotaMethods").instances.instantiate("quota_source");
  original_instance.copy_to({domain});
  original_instance = miq.namespaces.instantiate("System").namespaces.instantiate("CommonMethods").classes.instantiate("QuotaStateMachine").instances.instantiate("quota");
  original_instance.copy_to({domain});
  let instance = domain.namespaces.instantiate("System").namespaces.instantiate("CommonMethods").classes.instantiate("QuotaStateMachine").instances.instantiate("quota");
  return instance
};

function set_entity_quota_source(max_quota_test_instance, entity) {
  update(
    max_quota_test_instance,
    () => max_quota_test_instance.fields = {quota_source_type: {value: entity}}
  )
};

function entities(appliance, request, max_quota_test_instance) {
  let [collection, entity, description] = request.param;
  set_entity_quota_source(max_quota_test_instance, entity);
  return appliance.collections.getattr(collection).instantiate(description)
};

function new_tenant(appliance) {
  // Fixture is used to Create three tenants.
  //   
  let tenant_list = [];

  for (let i in (0).upto(NUM_TENANTS - 1)) {
    let collection = appliance.collections.tenants;

    let tenant = collection.create({
      name: fauxfactory.gen_alphanumeric(15, {start: "tenant_"}),

      description: fauxfactory.gen_alphanumeric(
        15,
        {start: "tenant_desc_"}
      ),

      parent: collection.get_root_tenant()
    });

    tenant_list.push(tenant)
  };

  yield(tenant_list);

  for (let tnt in tenant_list) {
    if (is_bool(tnt.exists)) tnt.delete()
  }
};

function set_parent_tenant_quota(request, appliance, new_tenant) {
  // Fixture is used to set tenant quota one by one to each of the tenant in 'new_tenant' list.
  //   After testing quota(example: testing cpu limit) with particular user and it's current group
  //   which is associated with one of these tenants. Then it disables the current quota
  //   (example: cpu limit) and enable new quota limit(example: Max memory) for testing.
  //   
  for (let i in (0).upto(NUM_TENANTS - 1)) {
    let [field, value] = request.param;
    new_tenant[i].set_quota({None: {[`${field}_cb`]: true, field: value}})
  };

  yield;
  appliance.server.login_admin();
  appliance.server.browser.refresh();

  for (let i in (0).upto(NUM_TENANTS - 1)) {
    new_tenant[i].set_quota({None: {[`${field}_cb`]: false}})
  }
};

function new_group_list(appliance, new_tenant) {
  // Fixture is used to Create Three new groups and assigned to three different tenants.
  //   
  let group_list = [];
  let collection = appliance.collections.groups;

  for (let i in (0).upto(NUM_GROUPS - 1)) {
    let group = collection.create({
      description: fauxfactory.gen_alphanumeric({start: "group_"}),
      role: "EvmRole-super_administrator",
      tenant: ("My Company/{}").format(new_tenant[i].name)
    });

    group_list.push(group)
  };

  yield(group_list);

  for (let grp in group_list) {
    if (is_bool(grp.exists)) grp.delete()
  }
};

function new_user(appliance, new_group_list, new_credential) {
  // Fixture is used to Create new user and User should be member of three groups.
  //   
  let collection = appliance.collections.users;

  let user = collection.create({
    name: fauxfactory.gen_alphanumeric({start: "user_"}),
    credential: new_credential,
    email: fauxfactory.gen_email(),
    groups: new_group_list,
    cost_center: "Workload",
    value_assign: "Database"
  });

  yield(user);
  if (is_bool(user.exists)) user.delete()
};

function custom_prov_data(request, prov_data, vm_name, template_name) {
  let value = request.param;
  prov_data.update(value);
  prov_data.catalog.vm_name = vm_name;
  prov_data.catalog.catalog_name = {name: template_name}
};

function test_quota(appliance, provider, custom_prov_data, vm_name, admin_email, entities, template_name, prov_data) {
  // This test case checks quota limit using the automate's predefine method 'quota source'
  // 
  //   Polarion:
  //       assignee: tpapaioa
  //       casecomponent: Quota
  //       caseimportance: medium
  //       initialEstimate: 1/6h
  //       tags: quota
  //   
  recursive_update(prov_data, custom_prov_data);

  do_vm_provisioning(appliance, {
    template_name,
    provider,
    vm_name,
    provisioning_data: prov_data,
    wait: false,
    request: null
  });

  let request_description = "Provision from [{template}] to [{vm}]".format({
    template: template_name,
    vm: vm_name
  });

  let provision_request = appliance.collections.requests.instantiate(request_description);
  provision_request.wait_for_request({method: "ui"});
  if (provision_request.row.reason.text != "Quota Exceeded") throw new ()
};

function test_user_quota_diff_groups(appliance, provider, new_user, set_parent_tenant_quota, extra_msg, custom_prov_data, approve, prov_data, vm_name, template_name) {
  // 
  //   Polarion:
  //       assignee: tpapaioa
  //       initialEstimate: 1/4h
  //       casecomponent: Quota
  //       caseimportance: high
  //       tags: quota
  //   
  new_user(() => {
    recursive_update(prov_data, custom_prov_data);
    logger.info("Successfully updated VM provisioning data");

    do_vm_provisioning(appliance, {
      template_name,
      provider,
      vm_name,
      provisioning_data: prov_data,
      wait: false,
      request: null
    });

    let request_description = "Provision from [{template}] to [{vm}{msg}]".format({
      template: template_name,
      vm: vm_name,
      msg: extra_msg
    });

    let provision_request = appliance.collections.requests.instantiate(request_description);

    if (is_bool(approve)) {
      provision_request.approve_request({method: "ui", reason: "Approved"})
    };

    provision_request.wait_for_request({method: "ui"});
    if (provision_request.row.reason.text != "Quota Exceeded") throw new ()
  })
}
