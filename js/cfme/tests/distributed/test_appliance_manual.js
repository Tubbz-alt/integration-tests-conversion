// Manual tests
require_relative("cfme");
include(Cfme);

let pytestmark = [
  pytest.mark.ignore_stream("upstream"),
  pytest.mark.manual,
  test_requirements.distributed
];

// 
//   Adding a provider from the global region to a remote zone.
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       caseimportance: medium
//       initialEstimate: 1/12h
//   
// pass
function test_distributed_add_provider_to_remote_zone() {};

// 
//   Can a new provider be added the first time to a non default zone.
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       caseimportance: critical
//       initialEstimate: 1/12h
//   
// pass
function test_distributed_zone_add_provider_to_nondefault_zone() {};

// 
//   Delete Zone that has appliances in it.
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Appliance
//       caseimportance: critical
//       initialEstimate: 1/12h
//   
// pass
function test_distributed_zone_delete_occupied() {};

// 
//   IPv6 and IPv4 appliances
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       caseimportance: medium
//       initialEstimate: 1h
//   
// pass
function test_distributed_zone_mixed_appliance_ip_versions() {};

// 
//   Steps to Reproduce:
//   have 3 servers .
//   Shutdown one server. This become inactive.
//   go to WebUI > Configuration > Diagnostics > Select \"Zone: Default
//   zone\" > Select worker > Configuration > Delete
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Appliance
//       initialEstimate: 1/2h
//   
// pass
function test_distributed_delete_offline_worker_appliance() {};

// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       initialEstimate: 1h
//   
// pass
function test_distributed_zone_in_different_networks() {};

// 
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       caseimportance: medium
//       initialEstimate: 1/12h
//   
// pass
function test_distributed_diagnostics_servers_view() {};

// 
//   Azure,AWS, and local infra
// 
//   Polarion:
//       assignee: tpapaioa
//       casecomponent: Infra
//       caseimportance: medium
//       initialEstimate: 1/12h
//   
// pass
function test_distributed_zone_mixed_infra() {}
