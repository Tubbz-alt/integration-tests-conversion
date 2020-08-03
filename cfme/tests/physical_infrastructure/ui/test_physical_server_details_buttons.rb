require_relative 'cfme/common/physical_server_views'
include Cfme::Common::Physical_server_views
require_relative 'cfme/physical/provider/lenovo'
include Cfme::Physical::Provider::Lenovo
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
pytestmark = [pytest.mark.tier(3), pytest.mark.provider([LenovoProvider], scope: "module")]
def physical_server(appliance, provider)
  ph_server = appliance.collections.physical_servers.all(provider)[0]
  return ph_server
end
def test_refresh_relationships(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  last_refresh = provider.last_refresh_date()
  physical_server.refresh(provider, handle_alert: true)
  raise unless last_refresh != provider.last_refresh_date()
end
def test_power_off(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.power_off()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server power_off for the selected server")
end
def test_power_on(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.power_on()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server power_on for the selected server")
end
def test_power_off_immediately(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.power_off_immediately()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server power_off_now for the selected server")
end
def test_restart(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.restart()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server restart for the selected server")
end
def test_restart_immediately(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.restart_immediately()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server restart_now for the selected server")
end
def test_turn_on_led(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.turn_on_led()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server turn_on_loc_led for the selected server")
end
def test_turn_off_led(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.turn_off_led()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server turn_off_loc_led for the selected server")
end
def test_turn_blink_led(physical_server, provider)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  physical_server.turn_blink_led()
  view = provider.create_view(PhysicalServerDetailsView, physical_server)
  view.flash.assert_message("Requested Server blink_loc_led for the selected server")
end
def test_lifecycle_provision(physical_server)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  view = navigate_to(physical_server, "Provision")
  raise unless view.is_displayed
end
def test_monitoring_button(physical_server)
  # 
  #   Polarion:
  #       assignee: rhcf3_machine
  #       casecomponent: Infra
  #       initialEstimate: 1/4h
  #   
  view = navigate_to(physical_server, "Timelines")
  raise unless view.is_displayed
end
