// Tests to validate post-migrations usecases
require_relative("cfme");
include(Cfme);
require_relative("cfme/cloud/provider/openstack");
include(Cfme.Cloud.Provider.Openstack);
require_relative("cfme/common");
include(Cfme.Common);
require_relative("cfme/fixtures/v2v_fixtures");
include(Cfme.Fixtures.V2v_fixtures);
require_relative("cfme/infrastructure/provider/rhevm");
include(Cfme.Infrastructure.Provider.Rhevm);
require_relative("cfme/infrastructure/provider/virtualcenter");
include(Cfme.Infrastructure.Provider.Virtualcenter);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/markers/env_markers/provider");
include(Cfme.Markers.Env_markers.Provider);
require_relative("cfme/utils/appliance/implementations/ui");
include(Cfme.Utils.Appliance.Implementations.Ui);
require_relative("cfme/utils/wait");
include(Cfme.Utils.Wait);

let pytestmark = [
  test_requirements.v2v,

  pytest.mark.provider({
    classes: [RHEVMProvider, OpenStackProvider],
    selector: ONE_PER_VERSION,
    required_flags: ["v2v"],
    scope: "module"
  }),

  pytest.mark.provider({
    classes: [VMwareProvider],
    selector: ONE_PER_TYPE,
    required_flags: ["v2v"],
    fixture_name: "source_provider",
    scope: "module"
  }),

  pytest.mark.usefixtures("v2v_provider_setup")
];

function test_migration_post_attribute(appliance, provider, mapping_data_vm_obj_mini, soft_assert) {
  // 
  //   Test to validate v2v post-migrations usecases
  // 
  //   Polarion:
  //       assignee: sshveta
  //       initialEstimate: 1/4h
  //       caseimportance: critical
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: V2V
  //       testSteps:
  //           1. Add source and target provider
  //           2. Create infra map and migration plan
  //           3. Migrate VM
  //           4. Check vm attributes upon successful migration
  //   
  let src_vm_obj = mapping_data_vm_obj_mini.vm_list[0];
  let source_view = navigate_to(src_vm_obj, "Details");
  let summary = source_view.entities.summary("Properties").get_text_of("Container");

  let [source_cpu, source_socket, source_core, source_memory] = re.findall(
    "\\d+",
    summary
  );

  let migration_plan_collection = appliance.collections.v2v_migration_plans;

  let migration_plan = migration_plan_collection.create({
    name: fauxfactory.gen_alphanumeric({start: "plan_"}),
    description: fauxfactory.gen_alphanumeric(15, {start: "plan_desc_"}),
    infra_map: mapping_data_vm_obj_mini.infra_mapping_data.get("name"),
    target_provider: provider,
    vm_list: mapping_data_vm_obj_mini.vm_list
  });

  if (!migration_plan.wait_for_state("Started")) throw new ();
  if (!migration_plan.wait_for_state("In_Progress")) throw new ();
  if (!migration_plan.wait_for_state("Completed")) throw new ();
  if (!migration_plan.wait_for_state("Successful")) throw new ();
  let migrated_vm = get_migrated_vm(src_vm_obj, provider);
  soft_assert.call(src_vm_obj.mac_address == migrated_vm.mac_address);
  let available_tags = src_vm_obj.get_tags();
  soft_assert.call(available_tags.map(tag => tag.display_name).include("Migrated"));

  src_vm_obj.wait_for_vm_state_change({
    desired_state: src_vm_obj.STATE_OFF,
    timeout: 720
  });

  src_vm_obj.power_control_from_cfme({
    option: src_vm_obj.POWER_ON,
    cancel: false
  });

  let view = appliance.browser.create_view(BaseLoggedInPage);

  view.flash.assert_success_message({
    text: "Start initiated",
    partial: true
  });

  // pass
  try {
    src_vm_obj.wait_for_vm_state_change({
      desired_state: src_vm_obj.STATE_ON,
      timeout: 120
    })
  } catch ($EXCEPTION) {
    if ($EXCEPTION instanceof TimedOutError) {

    } else {
      throw $EXCEPTION
    }
  };

  let vm_state = src_vm_obj.find_quadicon().data.state;
  soft_assert.call(vm_state == "off");
  let target_view = navigate_to(migrated_vm, "Details");
  summary = target_view.entities.summary("Properties").get_text_of("Container");

  let [target_cpu, target_socket, target_core, target_memory] = re.findall(
    "\\d+",
    summary
  );

  soft_assert.call(source_cpu == target_cpu);
  soft_assert.call(source_socket == target_socket);
  soft_assert.call(source_core == target_core);
  soft_assert.call(source_memory == target_memory)
}
