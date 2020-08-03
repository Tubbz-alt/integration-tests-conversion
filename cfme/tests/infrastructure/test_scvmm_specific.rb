require_relative 'urllib/request'
include Urllib::Request
require_relative 'cfme'
include Cfme
require_relative 'cfme/infrastructure/provider/scvmm'
include Cfme::Infrastructure::Provider::Scvmm
require_relative 'cfme/utils'
include Cfme::Utils
require_relative 'cfme/utils/appliance'
include Cfme::Utils::Appliance
require_relative 'cfme/utils/appliance/implementations/ui'
include Cfme::Utils::Appliance::Implementations::Ui
require_relative 'cfme/utils/blockers'
include Cfme::Utils::Blockers
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
require_relative 'cfme/utils/wait'
include Cfme::Utils::Wait
pytestmark = [pytest.mark.provider([SCVMMProvider], scope: "module"), pytest.mark.usefixtures("setup_provider_modscope"), test_requirements.scvmm]
SIZES = {"KB" => 1024, "MB" => 1024 ** 2, "GB" => 1024 ** 3, "TB" => 1024 ** 4}
def get_vhd_name(url, pattern: "hyperv")
  #  Given URL finds VHD file name 
  html = urlopen(url).read().decode("utf-8")
  files = (re.findall("href=\"(.*vhd)\"", html)) || (re.findall("href=\"(.*zip)\"", html))
  image_name = nil
  for name in files
    if name.include?(pattern)
      image_name = name
      break
    end
  end
  return image_name
end
def vm(provider, small_template)
  vm_name = fauxfactory.gen_alpha(18, start: "test-scvmm-")
  vm = provider.appliance.collections.infra_vms.instantiate(vm_name, provider, small_template.name)
  vm.create_on_provider(find_in_cfme: true)
  yield vm
  vm.cleanup_on_provider()
end
def cfme_vhd(provider, appliance)
  #  Given a stream from the appliance, gets the cfme vhd
  stream = appliance.version.stream()
  begin
    url = ("{}/").format(conf.cfme_data["basic_info"]["cfme_images_url"][stream])
  rescue KeyError
    pytest.skip()
  end
  image_name = get_vhd_name(url)
  if is_bool(!image_name)
    pytest.skip()
  end
  if appliance.version > "5.10"
    unzip = true
    cfme_vhd = image_name.gsub(".zip", ".vhd")
  else
    unzip = false
    cfme_vhd = image_name
  end
  provider.mgmt.download_file(url + image_name, image_name, unzip: unzip)
  provider.mgmt.update_scvmm_library()
  begin
    wait_for(lambda{|| provider.mgmt.list_vhds().include?(cfme_vhd)}, delay: 20, num_sec: 180)
  rescue TimedOutError
    pytest.fail("VHD was not downloaded properly in SCVMM library!")
  end
  yield cfme_vhd
end
def scvmm_appliance(provider, cfme_vhd)
  #  Create an appliance from the VHD provided on SCVMM 
  version = re.findall("\\d+", cfme_vhd)[0...4].join(".")
  template_name = 
  vhd_path = provider.data.get("vhd_path")
  small_disk = provider.data.get("small_disk")
  if is_bool(!vhd_path)
    pytest.skip("vhd_path not present in yamls, skipping test")
  end
  if is_bool(!small_disk)
    pytest.skip("No small_disk vhd specified, skipping test")
  end
  template_script = ("
        $networkName = \"cfme2\"
        $templateName = \"{template_name}\"
        $templateOwner = \"{domain}\\{user}\"
        $maxMemorySizeMb = 12288
        $startMemeorySizeMb = 4096
        $minMemorySizeMb = 128
        $cpuCount = 4
        $srcName = \"{image}\"
        $srcPath = \"{vhd_path}\\$srcName\"
        $dbDiskName = \"{small_disk}\"
        $dbDiskSrcPath = \"{vhd_path}\\$dbDiskName\"
        $scvmmFqdn = \"{hostname}\"

        $JobGroupId01 = [Guid]::NewGuid().ToString()
        $LogicalNet = Get-SCLogicalNetwork -Name $networkName
        New-SCVirtualNetworkAdapter -JobGroup $JobGroupId01 -MACAddressType Dynamic            -LogicalNetwork $LogicalNet -Synthetic
        New-SCVirtualSCSIAdapter -JobGroup $JobGroupId01 -AdapterID 6 -Shared $False
        New-SCHardwareProfile -Name $templateName -Owner $templateOwner -Description            \'Temp profile used to create a VM Template\' -DynamicMemoryEnabled $True            -DynamicMemoryMaximumMB $maxMemorySizeMb -DynamicMemoryMinimumMB $minMemorySizeMb            -CPUCount $cpuCount -JobGroup $JobGroupId01
        $JobGroupId02 = [Guid]::NewGuid().ToString()
        $VHD = Get-SCVirtualHardDisk -Name $srcName
        New-SCVirtualDiskDrive -IDE -Bus 0 -LUN 0 -JobGroup $JobGroupId02 -VirtualHardDisk $VHD
        $DBVHD = Get-SCVirtualHardDisk -Name $dbDiskName
        New-SCVirtualDiskDrive -IDE -Bus 1 -LUN 0 -JobGroup $JobGroupId02 -VirtualHardDisk $DBVHD
        $HWProfile = Get-SCHardwareProfile | where {{ $_.Name -eq $templateName }}
        New-SCVMTemplate -Name $templateName -Owner $templateOwner -HardwareProfile $HWProfile         -JobGroup $JobGroupId02 -RunAsynchronously -Generation 1 -NoCustomization
        Remove-HardwareProfile -HardwareProfile $templateName
    ").format(domain: provider.mgmt.domain, user: provider.mgmt.user, image: cfme_vhd, hostname: provider.mgmt.host, template_name: template_name, vhd_path: vhd_path, small_disk: small_disk)
  provider.mgmt.run_script(template_script)
  scvmm_appliance = provision_appliance(provider.key, version: version, template: template_name, vm_name_prefix: "test-cfme")
  delete_zip = scvmm_appliance.version >= "5.11"
  yield scvmm_appliance
  scvmm_appliance.destroy()
  template = provider.mgmt.get_template(template_name)
  template.delete()
  provider.mgmt.delete_vhd(cfme_vhd)
  if is_bool(delete_zip)
    provider.mgmt.delete_app_package(Cfme::cfme_vhd.gsub(".vhd", ".zip"))
  end
  provider.mgmt.update_scvmm_library()
end
def test_no_dvd_ruins_refresh(provider, vm)
  # 
  #   Polarion:
  #       assignee: jdupuy
  #       initialEstimate: 1/4h
  #       casecomponent: Infra
  #       caseimportance: high
  #   
  vm.mgmt.disconnect_dvd_drives()
  provider.refresh_provider_relationships()
  vm.wait_to_appear()
end
def test_vm_mac_scvmm(provider)
  # 
  #   Bugzilla:
  #       1514461
  # 
  #   Test case covers this BZ - we can't get MAC ID of VM at the moment
  # 
  #   Polarion:
  #       assignee: jdupuy
  #       casecomponent: Infra
  #       caseimportance: low
  #       initialEstimate: 1/20h
  #       testSteps:
  #           1. Add SCVMM to CFME
  #           2. Navigate to the details page of a VM (e.g. cu-24x7)
  #       expectedResults:
  #           1.
  #           2. MAC Address should match what is in SCVMM
  #   
  collection = provider.appliance.provider_based_collection(provider)
  vm = collection.all()[0]
  mac_addresses = vm.mgmt.raw["VirtualNetworkAdapters"].map{|entry| entry["PhysicalAddress"]}
  view = navigate_to(vm, "Details", use_resetter: false)
  begin
    mac_address = view.entities.summary("Properties").get_text_of("MAC Address")
  rescue NameError
    mac_address = view.entities.summary("Properties").get_text_of("MAC Addresses")
  end
  raise unless mac_addresses.include?(mac_address)
end
def test_create_appliance_on_scvmm_using_the_vhd_image(scvmm_appliance)
  # 
  #   View the documentation at access.redhat.com for help with this.
  # 
  #   Polarion:
  #       assignee: jdupuy
  #       casecomponent: Appliance
  #       initialEstimate: 1/4h
  #       subtype1: usability
  #       upstream: yes
  #       testSteps:
  #           1. Download VHD image
  #           2. Attach disk and deploy template
  #       expectedResults:
  #           1.
  #           2. CFME should be running in SCVMM
  #   
  scvmm_appliance.configure(fix_ntp_clock: false)
end
def test_check_disk_allocation_size_scvmm(vm)
  # 
  #   Test datastore used space is the correct value, c.f.
  #       https://github.com/ManageIQ/manageiq-providers-scvmm/issues/17
  #   Note, may have to edit settings on hyper-v host for checkpoint type:
  #       if set to production, try setting to standard
  # 
  #   Bugzilla:
  #       1490440
  #       1700909
  # 
  #   Polarion:
  #       assignee: jdupuy
  #       casecomponent: Infra
  #       caseimportance: medium
  #       initialEstimate: 1/2h
  #       testSteps:
  #           1. Provision VM and check it\'s \"Total Datastore Used Space\"
  #           2. go to VMM and create Vm\'s Checkpoint
  #           3. open VM Details check - \"Total Datastore Used Space\"
  #       expectedResults:
  #           1.
  #           2.
  #           3. The value should match what is in SCVMM
  #   
  view = navigate_to(vm, "Details")
  usage_before = view.entities.summary("Datastore Actual Usage Summary").get_text_of("Total Datastore Used Space")
  vm.mgmt.create_snapshot()
  vm.refresh_relationships(from_details: true)
  view = navigate_to(vm, "Details", force: true)
  usage_after = view.entities.summary("Datastore Actual Usage Summary").get_text_of("Total Datastore Used Space")
  msg = 
  vb,kb = usage_before.split()
  va,ka = usage_after.split()
  usage_before = vb.to_f * SIZES[kb]
  usage_after = va.to_f * SIZES[ka]
  raise msg unless usage_after > usage_before
  usage_snapshots = view.entities.summary("Datastore Actual Usage Summary").get_text_of("Snapshots")
  raise unless usage_snapshots.split()[0] > 0
end
