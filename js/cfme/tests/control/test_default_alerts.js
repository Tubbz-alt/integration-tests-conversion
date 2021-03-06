require_relative("cfme/utils/path");
include(Cfme.Utils.Path);

function default_alerts(appliance) {
  let file_name = ("ui/control/default_alerts.yaml".data_path.join).strpath;
  let alerts = {};

  if (is_bool(os.path.exists(file_name))) {
    open(file_name, (f) => {
      let all_alerts = yaml.safe_load(f);
      alerts = all_alerts.get("v5.10")
    })
  } else {
    pytest.skip(`Could not find ${file_name}, skipping test.`)
  };

  let alert_collection = appliance.collections.alerts;

  let default_alerts = alerts.to_a().map((key, alert) => (
    alert_collection.instantiate({
      description: alert.get("Description"),
      active: alert.get("Active"),
      based_on: alert.get("Based On"),
      evaluate: alert.get("What is evaluated"),
      emails: alert.get("Email"),
      snmp_trap: alert.get("SNMP"),
      timeline_event: alert.get("Event on Timeline"),
      mgmt_event: alert.get("Management Event Raised")
    })
  ));

  return default_alerts
};

function test_default_alerts(appliance, default_alerts) {
  //  Tests the default pre-configured alerts on the appliance and
  //       ensures that they have not changed between versions.
  // 
  //   Polarion:
  //       assignee: dgaikwad
  //       initialEstimate: 1/4h
  //       casecomponent: Control
  //   
  let alerts = appliance.collections.alerts.all();
  if (sorted(default_alerts) != sorted(alerts)) throw new ()
}
