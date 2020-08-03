require_relative 'wait_for'
include Wait_for
require_relative 'cfme'
include Cfme
require_relative 'cfme/cloud/provider'
include Cfme::Cloud::Provider
require_relative 'cfme/common/provider'
include Cfme::Common::Provider
require_relative 'cfme/containers/provider/openshift'
include Cfme::Containers::Provider::Openshift
require_relative 'cfme/exceptions'
include Cfme::Exceptions
require_relative 'cfme/infrastructure/provider/rhevm'
include Cfme::Infrastructure::Provider::Rhevm
require_relative 'cfme/infrastructure/provider/scvmm'
include Cfme::Infrastructure::Provider::Scvmm
require_relative 'cfme/infrastructure/provider/virtualcenter'
include Cfme::Infrastructure::Provider::Virtualcenter
require_relative 'cfme/markers/env_markers/provider'
include Cfme::Markers::Env_markers::Provider
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
require_relative 'cfme/utils/generators'
include Cfme::Utils::Generators
require_relative 'cfme/utils/log'
include Cfme::Utils::Log
require_relative 'cfme/utils/providers'
include Cfme::Utils::Providers
pytestmark = [pytest.mark.usefixtures("uses_infra_providers", "uses_cloud_providers", "provider"), pytest.mark.tier(2), pytest.mark.provider(gen_func: providers, filters: [ProviderFilter(classes: [BaseProvider]), ProviderFilter(classes: [SCVMMProvider, RHEVMProvider, OpenshiftProvider], inverted: true)], scope: "module"), test_requirements.genealogy]
def create_vm_with_clone(request, create_vm, provider, appliance)
  # Fixture to provision a VM and clone it
  first_name = fauxfactory.gen_alphanumeric()
  last_name = fauxfactory.gen_alphanumeric()
  email = "{first_name}.{last_name}@test.com"
  provision_type = "VMware"
  vm_name = random_vm_name(context: nil, max_length: 15)
  create_vm.clone_vm(email, first_name, last_name, vm_name, provision_type)
  vm2 = appliance.collections.infra_vms.instantiate(vm_name, provider)
  Wait_for::wait_for(lambda{|| vm2.exists}, timeout: 120)
  _cleanup = lambda do
    vm2.cleanup_on_provider()
    provider.refresh_provider_relationships()
  end
  return [create_vm, vm2]
end
def test_vm_genealogy_detected(request, setup_provider, provider, small_template, soft_assert, from_edit, create_vm)
  # Tests vm genealogy from what CFME can detect.
  # 
  #   Prerequisities:
  #       * A provider that is set up and having suitable templates for provisioning.
  # 
  #   Steps:
  #       * Provision the VM
  #       * Then, depending on whether you want to check it via ``Genealogy`` or edit page:
  #           * Open the edit page of the VM and you can see the parent template in the dropdown.
  #               Assert that it corresponds with the template the VM was deployed from.
  #           * Open VM Genealogy via details page and see the the template being an ancestor of the
  #               VM.
  # 
  #   Note:
  #       The cloud providers appear to not have Genealogy option available in the details view. So
  #       the only possibility available is to do the check via edit form.
  # 
  #   Metadata:
  #       test_flag: genealogy, provision
  # 
  #   Polarion:
  #       assignee: spusater
  #       casecomponent: Infra
  #       caseimportance: medium
  #       initialEstimate: 1/4h
  #   
  if is_bool(from_edit)
    create_vm.open_edit()
    view = navigate_to(create_vm, "Edit")
    opt = view.form.parent_vm.all_selected_options[0]
    parent = opt.strip()
    raise "The parent template not detected!" unless parent.startswith(small_template.name)
  else
    begin
      vm_crud_ancestors = create_vm.genealogy.ancestors
    rescue NameError
      logger.exception("The parent template not detected!")
      pytest.fail("The parent template not detected!")
    end
    raise  unless vm_crud_ancestors.include?(small_template.name)
  end
end
def test_genealogy_comparison(create_vm_with_clone, soft_assert)
  # 
  #   Test that compare button is enabled and the compare page is loaded when 2 VM's are compared
  # 
  #   Polarion:
  #       assignee: spusater
  #       casecomponent: Infra
  #       caseimportance: medium
  #       initialEstimate: 1/6h
  #       startsin: 5.10.4
  #       setup:
  #           1. Have a provider with some VMs added
  #       testSteps:
  #           1. Set the parent-child relationship for at least two VMs
  #           2. Open one of the VM's genealogy screen from its summary
  #           3. Check at least two checkboxes in the genealogy tree
  #       expectedResults:
  #           1. Genealogy set
  #           2. Genealogy screen displayed
  #           3. Compare button enabled
  #   Bugzilla:
  #       1694712
  #   
  begin
    compare_view = create_vm_with_clone[0].genealogy.compare(*create_vm_with_clone)
    raise unless compare_view.is_displayed
  rescue ToolbarOptionGreyedOrUnavailable
    logger.exception("The compare button is disabled or unavailable")
    pytest.fail("The compare button is disabled or unavailable")
  end
end
