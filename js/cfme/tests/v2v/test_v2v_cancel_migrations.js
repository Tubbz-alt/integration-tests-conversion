require_relative("selenium/common/exceptions");
include(Selenium.Common.Exceptions);
require_relative("cfme");
include(Cfme);
require_relative("cfme/cloud/provider/openstack");
include(Cfme.Cloud.Provider.Openstack);
require_relative("cfme/fixtures/templates");
include(Cfme.Fixtures.Templates);
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
require_relative("cfme/utils/log_validator");
include(Cfme.Utils.Log_validator);
require_relative("cfme/utils/wait");
include(Cfme.Utils.Wait);

let pytestmark = [
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

  pytest.mark.usefixtures("v2v_provider_setup"),
  test_requirements.v2v
];

function cancel_migration_plan(appliance, provider, mapping_data_vm_obj_mini) {
  let migration_plan_collection = appliance.collections.v2v_migration_plans;

  let migration_plan = migration_plan_collection.create({
    name: fauxfactory.gen_alphanumeric({start: "plan_"}),
    description: fauxfactory.gen_alphanumeric(15, {start: "plan_desc_"}),
    infra_map: mapping_data_vm_obj_mini.infra_mapping_data.get("name"),
    target_provider: provider,
    vm_list: mapping_data_vm_obj_mini.vm_list
  });

  if (is_bool(migration_plan.wait_for_state("Started"))) {
    migration_plan.in_progress({plan_elapsed_time: 240});
    let request_details_list = migration_plan.get_plan_vm_list({wait_for_migration: false});
    let vm_detail = request_details_list.read()[0];
    request_details_list.cancel_migration(vm_detail, {confirmed: true});

    wait_for(() => !request_details_list.is_in_progress(vm_detail), {
      delay: 10,
      num_sec: 600,
      message: "migration plan is in progress, be patient please"
    })
  } else {
    pytest.skip("Migration plan failed to start")
  };

  yield(migration_plan);
  migration_plan.delete_completed_plan()
};

function test_dual_vm_cancel_migration(request, appliance, soft_assert, provider, source_type, dest_type, template_type, mapping_data_multiple_vm_obj_single_datastore) {
  // 
  //   Polarion:
  //       assignee: sshveta
  //       initialEstimate: 1/2h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: V2V
  //       testSteps:
  //           1. Add source and target provider
  //           2. Create infra map and migration plan
  //           3. Start migration plan and cancel.
  //   
  let cancel_migration_after_percent = 20;
  let infrastructure_mapping_collection = appliance.collections.v2v_infra_mappings;
  let mapping_data = mapping_data_multiple_vm_obj_single_datastore.infra_mapping_data;
  let mapping = infrastructure_mapping_collection.create({None: mapping_data});
  let _cleanup = () => infrastructure_mapping_collection.delete(mapping);
  let migration_plan_collection = appliance.collections.v2v_migration_plans;

  let migration_plan = migration_plan_collection.create({
    name: fauxfactory.gen_alphanumeric({start: "plan_"}),
    description: fauxfactory.gen_alphanumeric({start: "plan_desc_"}),
    infra_map: mapping.name,
    target_provider: provider,
    vm_list: mapping_data_multiple_vm_obj_single_datastore.vm_list
  });

  if (!migration_plan.wait_for_state("Started")) throw new ();
  let request_details_list = migration_plan.get_plan_vm_list({wait_for_migration: false});
  let vms = request_details_list.read();

  let _get_plan_status_and_cancel = () => {
    let migration_plan_in_progress_tracker = [];

    for (let vm in vms) {
      let clock_reading1 = request_details_list.get_clock(vm);
      time.sleep(1);

      if (request_details_list.progress_percent(vm) > cancel_migration_after_percent) {
        request_details_list.cancel_migration(vm, {confirmed: true})
      };

      let clock_reading2 = request_details_list.get_clock(vm);
      migration_plan_in_progress_tracker.push(request_details_list.is_in_progress(vm) && clock_reading1 < clock_reading2)
    };

    return !migration_plan_in_progress_tracker.is_any
  };

  wait_for({
    func: _get_plan_status_and_cancel,
    message: "migration plan is in progress,be patient please",
    delay: 5,
    num_sec: 3600
  });

  for (let vm in vms) {
    soft_assert(request_details_list.is_cancelled(vm));
    soft_assert(request_details_list.progress_percent(vm) < 100.0 || !request_details_list.get_message_text(vm).include("Virtual machine migrated"))
  }
};

function test_cancel_migration_attachments(cancel_migration_plan, soft_assert, provider) {
  // 
  //   Test to cancel migration and check attached instance, volume and port is removed from provider
  //   Polarion:
  //       assignee: sshveta
  //       initialEstimate: 1/2h
  //       caseimportance: high
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: V2V
  //   
  let migration_plan = cancel_migration_plan;
  let request_details_list = migration_plan.get_plan_vm_list({wait_for_migration: false});
  let vm_name = request_details_list.read()[0];
  let vm_on_dest = provider.mgmt.find_vms({name: vm_name});
  soft_assert.call(!vm_on_dest);

  if (is_bool(provider.one_of(OpenStackProvider) && vm_on_dest)) {
    let server = provider.mgmt.get_vm({name: vm_name});
    soft_assert.call(!server.attached_volumes);
    if (!provider.mgmt.get_ports({uuid: server.uuid})) throw new ()
  }
};

function test_retry_migration_plan(appliance, cancel_migration_plan, source_type, dest_type, template_type) {
  // 
  //   Test to cancel migration and then retry migration
  //   Polarion:
  //       assignee: sshveta
  //       initialEstimate: 1/4h
  //       caseimportance: medium
  //       caseposneg: positive
  //       testtype: functional
  //       startsin: 5.10
  //       casecomponent: V2V
  // 
  //   Bugzilla:
  //       1755632
  //       1746592
  //       1807770
  //   
  let migration_plan = cancel_migration_plan;

  try {
    let view = navigate_to(migration_plan, "Complete")
  } catch ($EXCEPTION) {
    if ($EXCEPTION instanceof NoSuchElementException) {
      let view = navigate_to(migration_plan, "Complete")
    } else {
      throw $EXCEPTION
    }
  };

  view.plans_completed_list.migrate_plan(migration_plan.name);
  if (!migration_plan.wait_for_state("Started")) throw new ();
  let retry_interval = (appliance.version < "5.11" ? 60 : 15);

  let retry_interval_log = LogValidator(
    "/var/www/miq/vmdb/log/evm.log",
    {matched_patterns: [`.*to Automate for delivery in \\[${retry_interval}\\] seconds.*`]}
  );

  retry_interval_log.start_monitoring();
  if (!retry_interval_log.validate({wait: "150s"})) throw new ();
  if (!migration_plan.wait_for_state("In_Progress")) throw new ();
  if (!migration_plan.wait_for_state("Completed")) throw new ();
  if (!migration_plan.wait_for_state("Successful")) throw new ()
}
