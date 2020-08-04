require_relative("cfme");
include(Cfme);
require_relative("cfme/exceptions");
include(Cfme.Exceptions);
require_relative("cfme/services/myservice");
include(Cfme.Services.Myservice);
require_relative("cfme/services/service_catalogs");
include(Cfme.Services.Service_catalogs);
require_relative("cfme/services/workloads");
include(Cfme.Services.Workloads);
require_relative("cfme/services/workloads");
include(Cfme.Services.Workloads);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);

let pytestmark = [
  pytest.mark.tier(3),
  test_requirements.settings,
  pytest.mark.usefixtures("virtualcenter_provider")
];

const GTL_PARAMS = {
  "Infrastructure Providers": "infra_providers",
  VMs: "infra_vms",
  "My Services": MyService,
  "VMs & Instances": VmsInstances,
  "Templates & Images": TemplatesImages,
  "Service Catalogs": ServiceCatalogs
};

function check_vm_visibility(appliance, { check = false }) {
  let view = navigate_to(appliance.collections.infra_vms, "All");
  let value = view.sidebar.vmstemplates.tree.read_contents();
  let vm_name = value[-1];

  while (vm_name.is_a(Array)) {
    vm_name = vm_name[-1]
  };

  if (is_bool(vm_name == "<Orphaned>" && !check)) return false;

  if (is_bool(vm_name == "<Orphaned>" && check)) {
    view.sidebar.vmstemplates.tree.click_path(
      "All VMs & Templates",
      vm_name
    );

    // pass
    try {
      view.entities.get_first_entity()
    } catch ($EXCEPTION) {
      if ($EXCEPTION instanceof ItemNotFound) {

      } else {
        throw $EXCEPTION
      }
    }
  };

  return true
};

function _get_page(page, appliance) {
  // This is a bit of a hack, but I currently don't see a way around it
  if ([TemplatesImages, VmsInstances].include(page)) return page.call(appliance);
  if (is_bool(page.is_a(String))) return appliance.collections.getattr(page);
  return page
};

function test_default_view_infra_reset(appliance) {
  // This test case performs Reset button test.
  // 
  //   Steps:
  //       * Navigate to DefaultViews page
  //       * Check Reset Button is disabled
  //       * Select 'infrastructure_providers' button from infrastructure region
  //       * Change it's default mode
  //       * Check Reset Button is enabled
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Settings
  //       caseimportance: high
  //       initialEstimate: 1/20h
  //       tags: settings
  //   
  let view = navigate_to(appliance.user.my_settings, "DefaultViews");
  if (!view.tabs.default_views.reset.disabled) throw new ();
  let infra_btn = view.tabs.default_views.infrastructure.infrastructure_providers;
  let views = ["Tile View", "Grid View", "List View"];
  views.remove(infra_btn.active_button);
  infra_btn.select_button(random.choice(views));
  if (!!view.tabs.default_views.reset.disabled) throw new ()
};

function test_infra_default_view(appliance, group_name, view) {
  // This test case changes the default view of an infra related page and asserts the change.
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Settings
  //       caseimportance: high
  //       initialEstimate: 1/10h
  //       tags: settings
  // 
  //   Bugzilla:
  //       1553337
  //   
  let page = _get_page(GTL_PARAMS[group_name], appliance);
  let default_views = appliance.user.my_settings.default_views;
  let old_default = default_views.get_default_view(group_name);
  default_views.set_default_view(group_name, view);
  let dest = "All";
  if (group_name == "VMs") dest = "VMsOnly";
  let selected_view = navigate_to(page, dest, {use_resetter: false}).toolbar.view_selector.selected;
  if (view != selected_view) throw `${view} view setting failed`;
  default_views.set_default_view(group_name, old_default)
};

function test_infra_compare_view(appliance, expected_view) {
  let group_name, selector_type;

  // This test changes the default view/mode for comparison between infra provider instances
  //   and asserts the change.
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Settings
  //       caseimportance: high
  //       initialEstimate: 1/10h
  //       tags: settings
  //   
  if (["Expanded View", "Compressed View"].include(expected_view)) {
    let [group_name, selector_type] = ["Compare", "views_selector"]
  } else {
    [group_name, selector_type] = ["Compare Mode", "modes_selector"]
  };

  let default_views = appliance.user.my_settings.default_views;
  let old_default = default_views.get_default_view(group_name);
  default_views.set_default_view(group_name, expected_view);
  let vm_view = navigate_to(appliance.collections.infra_vms, "All");
  let e_slice = slice(0, 2, null);
  vm_view.entities.get_all({slice: e_slice}).map(e => e.ensure_checked());
  vm_view.toolbar.configuration.item_select("Compare Selected items");
  let selected_view = vm_view.actions.getattr(selector_type).selected;
  if (expected_view != selected_view) throw `${expected_view} setting failed`;
  default_views.set_default_view(group_name, old_default)
};

function test_vm_visibility_off(appliance) {
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Settings
  //       caseimportance: medium
  //       initialEstimate: 1/10h
  //       tags: settings
  //       endsin: 5.10
  //   
  appliance.user.my_settings.default_views.set_default_view_switch_off();
  if (!!check_vm_visibility(appliance)) throw new ()
};

function test_vm_visibility_on(appliance) {
  // 
  //   Polarion:
  //       assignee: pvala
  //       casecomponent: Settings
  //       caseimportance: medium
  //       initialEstimate: 1/5h
  //       tags: settings
  //       endsin: 5.10
  //   
  appliance.user.my_settings.default_views.set_default_view_switch_on();
  if (!check_vm_visibility(appliance, {check: true})) throw new ()
}
