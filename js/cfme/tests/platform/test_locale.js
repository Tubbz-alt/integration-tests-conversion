require_relative("cfme");
include(Cfme);

// 
//   Having the automatic locale selection selected, the appliance\"s locale
//   changes accordingly with user\"s preferred locale in the browser.
// 
//   Polarion:
//       assignee: jhenner
//       casecomponent: Appliance
//       caseimportance: medium
//       initialEstimate: 1/8h
//   
// pass
function test_automated_locale_switching() {}
