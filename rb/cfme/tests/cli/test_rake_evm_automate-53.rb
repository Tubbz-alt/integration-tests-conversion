# This module contains tests that are supposed to test CFME's CLI functionality.
require_relative 'cfme/automate/explorer/domain'
include Cfme::Automate::Explorer::Domain
require_relative 'cfme/utils/path'
include Cfme::Utils::Path
require_relative 'cfme/utils/update'
include Cfme::Utils::Update
cli_path = "cli".data_path.join
def rake(appliance)
  appliance.ssh_client.run_rake_command("evm:automate:clear")
  appliance.ssh_client.run_rake_command("evm:automate:reset")
  yield(lambda{|command| appliance.ssh_client.run_rake_command(command)})
  appliance.ssh_client.run_rake_command("evm:automate:clear")
  appliance.ssh_client.run_rake_command("evm:automate:reset")
end
def qe_ae_data(request, appliance, rake)
  appliance.ssh_client.put_file("QECliTesting.yaml".cli_path.join.strpath, "/root/QECliTesting.yaml")
  result = rake.("evm:automate:import DOMAIN=QECliTesting YAML_FILE=/root/QECliTesting.yaml PREVIEW=false ENABLED=true SYSTEM=false")
  raise result.output unless result.success
  qe_cli_testing = DomainCollection(appliance).instantiate(name: "QECliTesting")
  request.addfinalizer(qe_cli_testing.delete_if_exists)
  if is_bool(!qe_cli_testing.enabled)
    update(qe_cli_testing) {
      qe_cli_testing.enabled = true
    }
  end
end
def test_evm_automate_import_export_works_upstream(appliance, rake, soft_assert)
  # This test checks whether CLI import and export works.
  # 
  #   Prerequisities:
  #       * ``data/cli/QECliTesting.yaml`` file
  # 
  #   Steps:
  #       * Upload the ``QECliTesting.yaml`` file to an appliance
  #       * Use ``evm:automate:import`` rake task to import the testing file.
  #       * Use ``evm:automate:export`` rake task to export the data to another file.
  #       * Verify the file exists.
  # 
  #   Polarion:
  #       assignee: sbulage
  #       casecomponent: Automate
  #       initialEstimate: 1/3h
  #   
  appliance.ssh_client.put_file("QECliTesting.yaml".cli_path.join.strpath, "/root/QECliTesting.yaml")
  result = rake.("evm:automate:import DOMAIN=QECliTesting YAML_FILE=/root/QECliTesting.yaml PREVIEW=false SYSTEM=false")
  raise result.output unless result.success
  appliance.ssh_client.run_command("rm -f /root/QECliTesting.yaml")
  result = rake.("evm:automate:export DOMAIN=QECliTesting YAML_FILE=/root/QECliTesting.yaml")
  raise result.output unless result.success
  raise "Could not verify export!" unless (appliance.ssh_client.run_command("ls /root/QECliTesting.yaml")).success
end
def test_evm_automate_simulate_upstream(rake, qe_ae_data, appliance)
  # This test checks whether CLI simulation works.
  # 
  #   Prerequisities:
  #       * ``data/cli/QECliTesting.yaml`` file imported
  # 
  #   Steps:
  #       * Run ``evm:automate:simulate DOMAIN=QECliTesting NAMESPACE=System CLASS=Request
  #           INSTANCE=touch`` rake task
  #       * Verify the file ``/var/www/miq/vmdb/check_file`` exists and it contains string
  #           ``check content``
  # 
  #   Polarion:
  #       assignee: sbulage
  #       caseimportance: low
  #       casecomponent: Automate
  #       initialEstimate: 1/4h
  #   
  appliance.ssh_client.run_command("rm -f /var/www/miq/vmdb/check_file")
  result = rake.("evm:automate:simulate DOMAIN=QECliTesting NAMESPACE=System CLASS=Request INSTANCE=touch")
  raise result.output unless result.success
  result = appliance.ssh_client.run_command("cat /var/www/miq/vmdb/check_file")
  raise "Could not find the file created by AE policy" unless result.success
  raise "The file has wrong contents" unless result.output.strip() == "check content"
end
def test_evm_automate_convert(request, rake, appliance)
  # This test checks whether conversion from older XML format works.
  # 
  #   Prerequisities:
  #       * ``data/qe_event_handler.xml`` file.
  # 
  #   Steps:
  #       * Upload the testing file to the appliance.
  #       * Convert the file to ZIP using ``evm:automate:convert`` rake task
  #       * Import the ZIP file using ``evm:automate_import`` rake task.
  #       * Use ``evm:automate:extract_methods FOLDER=/some_folder`` and verify that a file named
  #           ``relay_events.rb`` is present in the directory hierarchy.
  # 
  #   Polarion:
  #       assignee: sbulage
  #       casecomponent: Automate
  #       initialEstimate: 1/6h
  #   
  appliance.ssh_client.put_file("qe_event_handler.xml".data_path.join.strpath, "/root/convert_test.xml")
  request.addfinalizer(lambda{|| appliance.ssh_client.run_command("rm -f /root/convert_test.xml")})
  result = rake.("evm:automate:convert DOMAIN=Default FILE=/root/convert_test.xml ZIP_FILE=/root/convert_test.zip")
  request.addfinalizer(lambda{|| appliance.ssh_client.run_command("rm -f /root/convert_test.zip")})
  raise result.output unless result.success
  result = appliance.ssh_client.run_command("ls -l /root/convert_test.zip")
  raise result.output unless result.success
  result = rake.("evm:automate:import ZIP_FILE=/root/convert_test.zip DOMAIN=Default OVERWRITE=true PREVIEW=false SYSTEM=false")
  raise result.output unless result.success
  result = rake.("evm:automate:extract_methods FOLDER=/root/automate_methods")
  request.addfinalizer(lambda{|| appliance.ssh_client.run_command("rm -rf /root/automate_methods")})
  raise result.output unless result.success
  result = appliance.ssh_client.run_command("find /root/automate_methods | grep 'relay_events[.]rb$'")
  raise "Could not find the method in the extracted methods directory" unless result.success
end
