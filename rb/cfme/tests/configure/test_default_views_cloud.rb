require_relative 'cfme'
include Cfme
require_relative 'cfme/cloud/provider'
include Cfme::Cloud::Provider
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
pytestmark = [pytest.mark.tier(3), test_requirements.settings, pytest.mark.usefixtures("openstack_provider")]
gtl_params = {"Cloud Providers" => CloudProvider, "Availability Zones" => "cloud_av_zones", "Flavors" => "cloud_flavors", "Instances" => "cloud_instances", "Images" => "cloud_images"}
def test_default_view_cloud_reset(appliance)
  # This test case performs Reset button test.
  # 
  #   Steps:
  #       * Navigate to DefaultViews page
  #       * Check Reset Button is disabled
  #       * Select 'availability_zones' button from cloud region and change it's default mode
  #       * Check Reset Button is enabled
  # 
  #   Polarion:
  #       assignee: pvala
  #       casecomponent: Settings
  #       caseimportance: high
  #       initialEstimate: 1/20h
  #       tags: settings
  #   
  view = navigate_to(appliance.user.my_settings, "DefaultViews")
  raise unless view.tabs.default_views.reset.disabled
  cloud_btn = view.tabs.default_views.clouds.availability_zones
  views = ["Tile View", "Grid View", "List View"]
  views.remove(cloud_btn.active_button)
  cloud_btn.select_button(random.choice(views))
  raise unless !view.tabs.default_views.reset.disabled
end
def test_cloud_default_view(appliance, group_name, expected_view)
  # This test case changes the default view of a cloud related page and asserts the change.
  # 
  #   Polarion:
  #       assignee: pvala
  #       casecomponent: Settings
  #       caseimportance: high
  #       initialEstimate: 1/10h
  #       tags: settings
  #   
  page = gtl_params[group_name]
  default_views = appliance.user.my_settings.default_views
  old_default = default_views.get_default_view(group_name, fieldset: "Clouds")
  default_views.set_default_view(group_name, expected_view, fieldset: "Clouds")
  nav_cls = is_bool(page.is_a? String) ? appliance.collections.getattr(page) : page
  selected_view = navigate_to(nav_cls, "All", use_resetter: false).toolbar.view_selector.selected
  raise "#{expected_view} view setting failed" unless expected_view == selected_view
  default_views.set_default_view(group_name, old_default, fieldset: "Clouds")
end
def test_cloud_compare_view(appliance, expected_view)
  # This test changes the default view/mode for comparison between cloud provider instances
  #   and asserts the change.
  # 
  #   Polarion:
  #       assignee: pvala
  #       casecomponent: Settings
  #       caseimportance: high
  #       initialEstimate: 1/10h
  #       tags: settings
  #   
  if ["Expanded View", "Compressed View"].include?(expected_view)
    group_name,selector_type = ["Compare", "views_selector"]
  else
    group_name,selector_type = ["Compare Mode", "modes_selector"]
  end
  default_views = appliance.user.my_settings.default_views
  old_default = default_views.get_default_view(group_name)
  default_views.set_default_view(group_name, expected_view)
  inst_view = navigate_to(appliance.collections.cloud_instances, "All")
  e_slice = slice(0, 2, nil)
  inst_view.entities.get_all(slice: e_slice).map{|e| e.ensure_checked()}
  inst_view.toolbar.configuration.item_select("Compare Selected items")
  selected_view = inst_view.actions.getattr(selector_type).selected
  raise "#{expected_view} setting failed" unless expected_view == selected_view
  default_views.set_default_view(group_name, old_default)
end
