require_relative("cfme/physical/provider/lenovo");
include(Cfme.Physical.Provider.Lenovo);
require_relative("cfme/utils/rest");
include(Cfme.Utils.Rest);

let pytestmark = [
  pytest.mark.tier(3),
  pytest.mark.provider([LenovoProvider])
];

function test_get_hardware(appliance, physical_switch) {
  // 
  //   Polarion:
  //       assignee: rhcf3_machine
  //       casecomponent: Rest
  //       initialEstimate: 1/4h
  //   
  physical_switch.reload({attributes: ["hardware"]});
  assert_response(appliance);
  if (!!physical_switch.hardware.equal(null)) throw new ()
};

function test_get_hardware_attributes(appliance, physical_switch, attribute) {
  // 
  //   Polarion:
  //       assignee: rhcf3_machine
  //       casecomponent: Rest
  //       initialEstimate: 1/4h
  //   
  let expanded_attribute = `hardware.${attribute}`;
  physical_switch.reload({attributes: [expanded_attribute]});
  assert_response(appliance);
  if (!!physical_switch.hardware[attribute].equal(null)) throw new ()
};

function test_get_asset_detail(appliance, physical_switch) {
  // 
  //   Polarion:
  //       assignee: rhcf3_machine
  //       casecomponent: Rest
  //       initialEstimate: 1/4h
  //   
  physical_switch.reload({attributes: ["asset_detail"]});
  assert_response(appliance);
  if (!!physical_switch.asset_detail.equal(null)) throw new ()
}
