require_relative 'cfme'
include Cfme
require_relative 'cfme/common/provider'
include Cfme::Common::Provider
require_relative 'cfme/containers/provider'
include Cfme::Containers::Provider
require_relative 'cfme/fixtures/provider'
include Cfme::Fixtures::Provider
require_relative 'cfme/fixtures/pytest_store'
include Cfme::Fixtures::Pytest_store
require_relative 'cfme/utils'
include Cfme::Utils
require_relative 'cfme/utils/log'
include Cfme::Utils::Log
pytestmark = [pytest.mark.tier(1), test_requirements.c_and_u, pytest.mark.provider([ContainersProvider], scope: "module")]
def enable_candu(appliance)
  candu = appliance.collections.candus
  original_roles = appliance.server.settings.server_roles_db
  begin
    appliance.server.settings.enable_server_roles("ems_metrics_coordinator", "ems_metrics_collector", "ems_metrics_processor")
    candu.enable_all()
    yield
  ensure
    candu.disable_all()
    appliance.server.settings.update_server_roles_db(original_roles)
  end
end
def clean_setup_provider(request, provider)
  BaseProvider.clear_providers()
  setup_or_skip(request, provider)
  yield
  BaseProvider.clear_providers()
end
def test_metrics_collection(clean_setup_provider, provider, enable_candu)
  # Check the db is gathering collection data for the given provider
  # 
  #   Metadata:
  #       test_flag: metrics_collection
  # 
  #   Polarion:
  #       assignee: nachandr
  #       initialEstimate: 1/4h
  #       casecomponent: CandU
  #   
  metrics_tbl = store.current_appliance.db.client["metrics"]
  mgmt_systems_tbl = store.current_appliance.db.client["ext_management_systems"]
  logger.info("Fetching provider ID for %s", provider.key)
  mgmt_system_id = store.current_appliance.db.client.session.query(mgmt_systems_tbl).filter(mgmt_systems_tbl.name == conf.cfme_data.get("management_systems", {})[provider.key]["name"]).first().id
  logger.info("ID fetched; testing metrics collection now")
  start_time = time.time()
  host_count = 0
  vm_count = 0
  host_rising = false
  vm_rising = false
  timeout = 900.0
  while time.time() < start_time + timeout
    last_host_count = host_count
    last_vm_count = vm_count
    logger.info("name: %s, id: %s, vms: %s, hosts: %s", provider.key, mgmt_system_id, vm_count, host_count)
    host_count = store.current_appliance.db.client.session.query(metrics_tbl).filter(metrics_tbl.parent_ems_id == mgmt_system_id).filter(metrics_tbl.resource_type == "Host").count()
    vm_count = store.current_appliance.db.client.session.query(metrics_tbl).filter(metrics_tbl.parent_ems_id == mgmt_system_id).filter(metrics_tbl.resource_type == "VmOrTemplate").count()
    if is_bool(host_count > last_host_count && last_host_count > 0)
      host_rising = true
    end
    if is_bool(vm_count > last_vm_count && last_vm_count > 0)
      vm_rising = true
    end
    if is_bool(provider.category == "cloud" && vm_rising)
      return
    else
      if is_bool(provider.category == "infra" && vm_rising && host_rising)
        return
      else
        time.sleep(15)
      end
    end
  end
  if time.time() > start_time + timeout
    raise Exception, "Timed out waiting for metrics to be collected"
  end
end
