require_relative("cfme");
include(Cfme);
require_relative("cfme/infrastructure/datastore");
include(Cfme.Infrastructure.Datastore);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);

let pytestmark = [
  pytest.mark.tier(3),
  pytest.mark.usefixtures("virtualcenter_provider"),
  test_requirements.filtering
];

function test_set_default_host_filter(request, appliance) {
  //  Test for setting default filter for hosts.
  // 
  //   Polarion:
  //       assignee: gtalreja
  //       casecomponent: WebUI
  //       caseimportance: low
  //       initialEstimate: 1/12h
  //   
  let host_collection = appliance.collections.hosts;

  let unset_default_host_filter = () => {
    let view = navigate_to(host_collection, "All");
    view.filters.navigation.select("ALL");
    return view.default_filter_btn.click()
  };

  request.addfinalizer(method("unset_default_host_filter"));
  let view = navigate_to(host_collection, "All");
  view.filters.navigation.select("Status / Running");
  view.default_filter_btn.click();
  appliance.server.logout();
  appliance.server.login_admin();
  navigate_to(host_collection, "All");

  if (view.filters.navigation.currently_selected[0] != "Status / Running (Default)") {
    throw new ()
  }
};

function test_clear_host_filter_results(appliance) {
  //  Test for clearing filter results for hosts.
  // 
  //   Polarion:
  //       assignee: gtalreja
  //       casecomponent: WebUI
  //       caseimportance: low
  //       initialEstimate: 1/30h
  //   
  let host_collection = appliance.collections.hosts;
  let view = navigate_to(host_collection, "All");
  view.filters.navigation.select("Status / Stopped");
  view.entities.search.remove_search_filters();
  let page_title = view.title.text;
  if (page_title != "Hosts") throw "Clear filter results failed"
};

function test_clear_datastore_filter_results(appliance) {
  //  Test for clearing filter results for datastores.
  // 
  //   Polarion:
  //       assignee: gtalreja
  //       casecomponent: WebUI
  //       caseimportance: low
  //       initialEstimate: 1/12h
  //   
  let dc = DatastoreCollection(appliance);
  let view = navigate_to(dc, "All");

  view.sidebar.datastores.tree.click_path(
    "All Datastores",
    "Global Filters",
    "Store Type / VMFS"
  );

  view.entities.search.remove_search_filters();

  if (view.entities.title.text != "All Datastores") {
    throw "Clear filter results failed"
  }
}