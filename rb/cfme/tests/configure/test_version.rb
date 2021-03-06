require_relative 'cfme'
include Cfme
require_relative 'cfme/configure'
include Cfme::Configure
def test_appliance_version(appliance)
  # Check version presented in UI against version retrieved directly from the machine.
  # 
  #   Version retrieved from appliance is in this format: 1.2.3.4
  #   Version in the UI is always: 1.2.3.4.20140505xyzblabla
  # 
  #   So we check whether the UI version starts with SSH version
  # 
  #   Polarion:
  #       assignee: jhenner
  #       casecomponent: Appliance
  #       caseimportance: high
  #       initialEstimate: 1/4h
  #   
  ssh_version = appliance.version.to_s
  ui_version = about.get_detail(about.VERSION, server: appliance.server)
  raise "UI: #{ui_version}, SSH: #{ssh_version}" unless ui_version.startswith(ssh_version)
end
