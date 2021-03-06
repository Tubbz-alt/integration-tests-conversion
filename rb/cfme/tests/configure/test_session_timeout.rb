require_relative 'cfme'
include Cfme
require_relative 'cfme/utils/browser'
include Cfme::Utils::Browser
require_relative 'cfme/utils/browser'
include Cfme::Utils::Browser
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
def test_session_timeout(request, appliance)
  # Sets the timeout to shortest possible time and waits if it really times out.
  # 
  #   Polarion:
  #       assignee: tpapaioa
  #       casecomponent: Configuration
  #       caseimportance: low
  #       initialEstimate: 1/8h
  #   
  auth_settings = appliance.server.authentication
  _finalize = lambda do
    quit()
    ensure_browser_open()
    auth_settings.set_session_timeout(hours: "24", minutes: "0")
  end
  auth_settings.set_session_timeout(hours: "0", minutes: "5")
  time.sleep(10 * 60)
  wait_for(lambda{|| appliance.browser.widgetastic.selenium.find_elements_by_xpath("//div[(@id='flash_div' or @id='login_div') and contains(normalize-space(.), 'Session was timed out due to inactivity')]")}, num_sec: 60, delay: 5, fail_func: lambda{|| appliance.browser.widgetastic.selenium.click("//a[normalize-space(text())='Cloud Intelligence']")})
end
def test_bind_timeout_rest(appliance, request)
  # Sets the session timeout via REST
  # 
  #   Bugzilla:
  #       1553394
  # 
  #   Polarion:
  #       assignee: pvala
  #       casecomponent: Configuration
  #       caseimportance: medium
  #       initialEstimate: 1/4h
  #   
  old_bind = appliance.advanced_settings.get("authentication", {}).get("bind_timeout")
  if is_bool(!old_bind)
    pytest.skip("Unable to locate authentication:bind_timeout in advanced settings REST")
  end
  request.addfinalizer(lambda{|| appliance.update_advanced_settings({"authentication" => {"bind_timeout" => old_bind.to_i}})})
  offset = old_bind.to_i + 10
  appliance.update_advanced_settings({"authentication" => {"bind_timeout" => offset.to_i}})
  raise unless appliance.advanced_settings["authentication"]["bind_timeout"].to_i == offset
end
