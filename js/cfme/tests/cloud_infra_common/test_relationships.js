require_relative("navmazing");
include(Navmazing);
require_relative("cfme");
include(Cfme);
require_relative("cfme/cloud/availability_zone");
include(Cfme.Cloud.Availability_zone);
require_relative("cfme/cloud/flavor");
include(Cfme.Cloud.Flavor);
require_relative("cfme/cloud/provider");
include(Cfme.Cloud.Provider);
require_relative("cfme/cloud/provider");
include(Cfme.Cloud.Provider);
require_relative("cfme/cloud/provider");
include(Cfme.Cloud.Provider);
require_relative("cfme/cloud/provider/azure");
include(Cfme.Cloud.Provider.Azure);
require_relative("cfme/cloud/provider/ec2");
include(Cfme.Cloud.Provider.Ec2);
require_relative("cfme/cloud/provider/openstack");
include(Cfme.Cloud.Provider.Openstack);
require_relative("cfme/cloud/stack");
include(Cfme.Cloud.Stack);
require_relative("cfme/cloud/tenant");
include(Cfme.Cloud.Tenant);
require_relative("cfme/common/host_views");
include(Cfme.Common.Host_views);
require_relative("cfme/common/provider_views");
include(Cfme.Common.Provider_views);
require_relative("cfme/common/vm_views");
include(Cfme.Common.Vm_views);
require_relative("cfme/common/vm_views");
include(Cfme.Common.Vm_views);
require_relative("cfme/infrastructure/cluster");
include(Cfme.Infrastructure.Cluster);
require_relative("cfme/infrastructure/cluster");
include(Cfme.Infrastructure.Cluster);
require_relative("cfme/infrastructure/datastore");
include(Cfme.Infrastructure.Datastore);
require_relative("cfme/infrastructure/datastore");
include(Cfme.Infrastructure.Datastore);
require_relative("cfme/infrastructure/provider");
include(Cfme.Infrastructure.Provider);
require_relative("cfme/infrastructure/provider/rhevm");
include(Cfme.Infrastructure.Provider.Rhevm);
require_relative("cfme/infrastructure/provider/virtualcenter");
include(Cfme.Infrastructure.Provider.Virtualcenter);
require_relative("cfme/infrastructure/virtual_machines");
include(Cfme.Infrastructure.Virtual_machines);
require_relative("cfme/infrastructure/virtual_machines");
include(Cfme.Infrastructure.Virtual_machines);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/networks/provider");
include(Cfme.Networks.Provider);
require_relative("cfme/networks/views");
include(Cfme.Networks.Views);
require_relative("cfme/networks/views");
include(Cfme.Networks.Views);
require_relative("cfme/storage/manager");
include(Cfme.Storage.Manager);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/blockers");
include(Cfme.Utils.Blockers);
require_relative("cfme/utils/generators");
include(Cfme.Utils.Generators);
require_relative("cfme/utils/log");
include(Cfme.Utils.Log);
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);

const HOST_RELATIONSHIPS = [
  ["Infrastructure Provider", InfraProviderDetailsView],
  ["Cluster", ClusterDetailsView],
  ["Datastores", HostAllDatastoresView],
  ["VMs", HostAllVMsView],
  ["Templates", HostTemplatesOnlyAllView]
];

const INFRA_PROVIDER_RELATIONSHIPS = [
  ["Clusters", ProviderAllClustersView],
  ["Hosts", ProviderAllHostsView],
  ["Datastores", ProviderAllDatastoresView],
  ["Virtual Machines", ProviderAllVMsView],
  ["Templates", ProviderTemplatesOnlyAllView]
];

const CLOUD_PROVIDER_RELATIONSHIPS = [
  ["Network Manager", NetworkProviderDetailsView],
  ["Availability Zones", ProviderAvailabilityZoneAllView],
  ["Cloud Tenants", ProviderTenantAllView],
  ["Flavors", ProviderFlavorAllView],
  ["Security Groups", ProviderSecurityGroupAllView],
  ["Instances", CloudProviderInstancesView],
  ["Images", CloudProviderImagesView],
  ["Orchestration Stacks", ProviderStackAllView],
  ["Storage Managers", ProviderStorageManagerAllView]
];

let cloud_test_items = [
  "cloud_instances",
  "cloud_flavors",
  "cloud_av_zones",
  "cloud_tenants",
  "cloud_images",
  "security_groups",
  "cloud_stacks",
  "block_managers",
  "network_providers"
];

let infra_test_items = [
  "clusters",
  "hosts",
  "datastores",
  "infra_vms",
  "infra_templates"
];

const RELATIONSHIPS = new Set([
  "Infrastructure Provider",
  "Availability zones",
  "Availability Zones",
  "Flavors",
  "Security Groups",
  "Instances",
  "Images",
  "Orchestration stacks",
  "Orchestration Stacks",
  "Storage Managers",
  "Cloud Tenants",
  "Cloud tenants"
]);

function get_obj(relationship, appliance, kwargs, { ...kwargs }) {
  let obj;

  if (RELATIONSHIPS.include(relationship)) {
    obj = kwargs.get("provider")
  } else if (relationship == "Cluster") {
    let cluster_col = appliance.collections.clusters;
    let host = kwargs.get("host");
    let provider = kwargs.get("provider");
    let view = navigate_to(host, "Details");
    let cluster_name = view.entities.summary("Relationships").get_text_of("Cluster");

    if (cluster_name == "None") {
      pytest.skip(`Host ${host.name} is not a clustered host`)
    };

    obj = cluster_col.instantiate({name: cluster_name, provider})
  } else if (["Datastores", "VMs", "Templates"].include(relationship)) {
    obj = kwargs.get("host")
  } else if (relationship == "Network Manager") {
    let network_providers_col = appliance.collections.network_providers;
    let provider = kwargs.get("provider");
    let view = navigate_to(provider, "Details");
    let network_prov_name = view.entities.summary("Relationships").get_text_of("Network Manager");

    obj = network_providers_col.instantiate({
      prov_class: NetworkProvider,
      name: network_prov_name
    })
  };

  return obj
};

function host(appliance, provider) {
  let host_collection = provider.hosts;
  return random.choice(host_collection.all())
};

function test_host_relationships(appliance, provider, setup_provider, host, relationship, view) {
  // Tests relationship navigation for a host
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: medium
  //       initialEstimate: 1/12h
  //       tags: relationship
  //   
  let host_view = navigate_to(host, "Details");

  if (host_view.entities.summary("Relationships").get_text_of(relationship) == "0") {
    pytest.skip(`There are no relationships for ${relationship}`)
  };

  let obj = get_obj(relationship, appliance, {provider, host});
  host_view.entities.summary("Relationships").click_at(relationship);

  let relationship_view = appliance.browser.create_view(
    view,
    {additional_context: {object: obj}}
  );

  if (!relationship_view.is_displayed) throw new ()
};

function test_infra_provider_relationships(appliance, provider, setup_provider, relationship, view) {
  // Tests relationship navigation for an infrastructure provider
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: medium
  //       initialEstimate: 1/10h
  //       tags: relationship
  //   
  let provider_view = navigate_to(provider, "Details");

  if (provider_view.entities.summary("Relationships").get_text_of(relationship) == "0") {
    pytest.skip(`There are no relationships for ${relationship}`)
  };

  provider_view.entities.summary("Relationships").click_at(relationship);

  let relationship_view = appliance.browser.create_view(
    view,
    {additional_context: {object: provider}}
  );

  if (!relationship_view.is_displayed) throw new ()
};

function test_cloud_provider_relationships(appliance, provider, setup_provider, relationship, view) {
  // Tests relationship navigation for a cloud provider
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Cloud
  //       caseimportance: medium
  //       initialEstimate: 1/8h
  //       tags: relationship
  //   
  let provider_view = navigate_to(provider, "Details");

  if (provider_view.entities.summary("Relationships").get_text_of(relationship) == "0") {
    pytest.skip(`There are no relationships for ${relationship}`)
  };

  let obj = get_obj(relationship, appliance, {provider});
  provider_view.entities.summary("Relationships").click_at(relationship);

  let relationship_view = appliance.browser.create_view(
    view,
    {additional_context: {object: obj}}
  );

  if (!relationship_view.is_displayed) throw new ()
};

function prov_child_visibility(appliance, provider, request, tag, user_restricted) {
  let _prov_child_visibility = (relationship, visibility) => {
    provider.add_tag({tag});
    let rel_cls = appliance.collections.getattr(relationship);
    let actual_visibility = _check_actual_visibility(rel_cls);
    let _finalize = () => provider.remove_tag({tag});

    if (is_bool(!actual_visibility)) {
      pytest.skip(`There are no relationships for ${relationship}`)
    };

    user_restricted(() => {
      actual_visibility = _check_actual_visibility(rel_cls)
    });

    if (actual_visibility != visibility) return throw new ()
  };

  let _check_actual_visibility = (item_cls) => {
    try {
      let view = navigate_to(item_cls, "All")
    } catch ($EXCEPTION) {
      if ($EXCEPTION instanceof NavigationDestinationNotFound) {
        let view = navigate_to(item_cls.parent, "All")
      } else {
        throw $EXCEPTION
      }
    };

    try {
      if (is_bool(view.entities.instance_variable_defined("@entity_names"))) {
        if (!view.entities.entity_names) throw new ()
      } else if (!view.entities.read()) {
        throw new ()
      };

      let actual_visibility = true
    } catch ($EXCEPTION) {
      if ($EXCEPTION instanceof RuntimeError) {
        let actual_visibility = false
      } else {
        throw $EXCEPTION
      }
    };

    return actual_visibility
  };

  return _prov_child_visibility
};

function test_tagvis_infra_provider_children(prov_child_visibility, setup_provider, relationship) {
  //  Tests that provider child's should not be visible for restricted user
  //   Prerequisites:
  //       Catalog, tag, role, group and restricted user should be created
  // 
  //   Steps:
  //       1. As admin add tag to provider
  //       2. Login as restricted user, providers child not visible for user
  // 
  //   Polarion:
  //       assignee: prichard
  //       casecomponent: Tagging
  //       initialEstimate: 1/4h
  //   
  prov_child_visibility.call(relationship, {visibility: false})
};

function test_tagvis_cloud_provider_children(prov_child_visibility, setup_provider, relationship) {
  //  Tests that provider child's should not be visible for restricted user
  //   Prerequisites:
  //       Catalog, tag, role, group and restricted user should be created
  // 
  //   Polarion:
  //       assignee: prichard
  //       initialEstimate: 1/8h
  //       casecomponent: Cloud
  //       caseimportance: high
  //       testSteps:
  //           1. As admin add tag to provider
  //           2. Login as restricted user, providers child not visible for user
  //   
  prov_child_visibility.call(relationship, {visibility: false})
};

function test_provider_refresh_relationship(provider, setup_provider) {
  // Tests provider refresh
  // 
  //   Bugzilla:
  //       1353285
  //       1756984
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: high
  //       initialEstimate: 1/8h
  //       tags: relationship
  //   
  let result = LogValidator(
    "/var/www/miq/vmdb/log/evm.log",
    {failure_patterns: [".*ERROR.*"]}
  );

  result.start_monitoring();
  provider.refresh_provider_relationships({method: "ui", wait: 600});
  if (!result.validate({wait: "60s"})) throw new ()
};

function test_host_refresh_relationships(provider, setup_provider) {
  //  Test that host refresh doesn\'t fail
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: high
  //       initialEstimate: 1/8h
  //       tags: relationship
  //       testSteps:
  //           1. Go to a host summary page in cfme
  //           2. From configuration -> select \"Refresh Relationships and Power State\"
  //           3. No error, host inventory properly refreshes
  // 
  //   Bugzilla:
  //       1658240
  //   
  let host = provider.hosts.all()[0];
  host.refresh({cancel: true});
  provider.wait_for_relationship_refresh()
};

function test_template_refresh_relationships(appliance, provider, setup_provider) {
  //  Test that template refresh doesn't fail
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: high
  //       initialEstimate: 1/8h
  //       tags: relationship
  // 
  //   Bugzilla:
  //       1732349
  //   
  let templates_view = navigate_to(provider, "ProviderTemplates");
  let template_names = templates_view.entities.entity_names;

  let template_collection = appliance.provider_based_collection({
    provider,
    coll_type: "templates"
  });

  let template = template_collection.instantiate(
    template_names[0],
    provider
  );

  template.refresh_relationships();
  provider.wait_for_relationship_refresh()
};

// 
//   Bugzilla:
//       1473619
// 
//   Polarion:
//       assignee: anikifor
//       casecomponent: Cloud
//       caseimportance: medium
//       initialEstimate: 1/12h
//   
// pass
function test_inventory_refresh_westindia_azure() {};

function test_change_network_security_groups_per_page_items(setup_provider, appliance, provider) {
  // 
  //   Bugzilla:
  //       1524443
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Cloud
  //       caseimportance: medium
  //       initialEstimate: 1/12h
  //       tags: relationship
  //       testSteps:
  //           1.Open Azure provider details view.
  //           2.Open Azure Network Manager
  //           3.Select Network Security Groups
  //           4.Change items per page
  //   
  let view = navigate_to(provider, "NetworkSecurityGroup");
  view.toolbar.view_selector.select("List View");
  let total_count = view.paginator.items_amount;

  for (let item_count in [5, 10, 20, 50, 100, 200, 500, 1000]) {
    if (item_count <= total_count) {
      view.paginator.set_items_per_page(item_count);
      if (view.entities.get_all().size > view.paginator.items_per_page) throw new ()
    } else {
      break
    }
  }
};

function testing_vm(appliance, provider, win2012_template) {
  // Fixture to provision vm
  //   Note: Need to use windows template to make sure `Extract Running process` works.
  //   
  let vm_name = random_vm_name("pwr-c");

  let vm = appliance.collections.infra_vms.instantiate(
    vm_name,
    provider,
    {template_name: win2012_template.name}
  );

  if (is_bool(!provider.mgmt.does_vm_exist(vm.name))) {
    logger.info("deploying %s on provider %s", vm.name, provider.key);
    vm.create_on_provider({allow_skip: "default", find_in_cfme: true})
  };

  yield(vm);
  vm.cleanup_on_provider()
};

function test_datastore_relationships(setup_provider, testing_vm) {
  // 
  //   Bugzilla:
  //       1729953
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: medium
  //       initialEstimate: 1/12h
  //       tags: relationship
  //       setup:
  //           1. Add infrastructure provider(e.g: vsphere65)
  //           2. Provision VM
  //           3. Setup SSA
  //       testSteps:
  //           1. Navigate to VM's details page and click on 'Datastores' from 'Relationships' table
  //           2. Click on 'Managed VMs' from 'Relationships' table
  //           3. Select VM(Vm should be in 'on' state) and perform operations(Refresh Relationships
  //              and Power States, Perform Smartstate Analysis, Extract Running Processes) by
  //              selecting from 'configuration' dropdown
  //       expectedResults:
  //           1.
  //           2.
  //           3. Operations should be performed successfully. It should not give unexpected error.
  //   
  let view = navigate_to(testing_vm.datastore, "ManagedVMs");
  view.entities.get_entity({name: testing_vm.name}).check();

  view.toolbar.configuration.item_select(
    "Refresh Relationships and Power States",
    {handle_alert: true}
  );

  view.flash.assert_success_message("Refresh Provider initiated for 1 VM and Instance from the CFME Database");
  view.flash.dismiss();

  view.toolbar.configuration.item_select(
    "Perform SmartState Analysis",
    {handle_alert: true}
  );

  view.flash.assert_success_message("Analysis initiated for 1 VM and Instance from the CFME Database");
  view.flash.dismiss();

  view.toolbar.configuration.item_select(
    "Extract Running Processes",
    {handle_alert: true}
  );

  view.flash.assert_no_error()
};

function cluster(provider) {
  let collection = provider.appliance.collections.clusters;

  try {
    let cluster_name = provider.data.cap_and_util.cluster
  } catch ($EXCEPTION) {
    if ($EXCEPTION instanceof KeyError) {
      pytest.skip(`Unable to identify cluster for provider: ${provider}`)
    } else {
      throw $EXCEPTION
    }
  };

  return collection.instantiate({name: cluster_name, provider})
};

function test_ssa_cluster_relationships(setup_provider, cluster, testing_vm) {
  // 
  //   Bugzilla:
  //       1732370
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Infra
  //       caseimportance: medium
  //       initialEstimate: 1/12h
  //       tags: relationship
  //       setup:
  //           1. Setup SSA
  //       testSteps:
  //           1. Add infra provider
  //           2. Go to it's details page
  //           3. Click on 'All VMs' from 'Relationships' table
  //           4. Select any vm and click on options like 'Refresh Relationships and Power states' or
  //             'perform smartstate analysis' and 'Extract running processes' from 'configuration'
  //       expectedResults:
  //           1.
  //           2.
  //           3.
  //           4. Operations should be performed successfully. It should not give unexpected error.
  //   
  let view = navigate_to(cluster, "AllVMs");
  view.entities.get_entity({name: testing_vm.name, surf_pages: true}).check();

  view.toolbar.configuration.item_select(
    "Refresh Relationships and Power States",
    {handle_alert: true}
  );

  view.flash.assert_success_message("Refresh Provider initiated for 1 VM and Instance from the CFME Database");
  view.flash.dismiss();

  view.toolbar.configuration.item_select(
    "Perform SmartState Analysis",
    {handle_alert: true}
  );

  view.flash.assert_success_message("Analysis initiated for 1 VM and Instance from the CFME Database");
  view.flash.dismiss();

  view.toolbar.configuration.item_select(
    "Extract Running Processes",
    {handle_alert: true}
  );

  view.flash.assert_success_message("Collect Running Processes initiated for 1 VM and Instance from the CFME Database");
  view.flash.dismiss()
}
