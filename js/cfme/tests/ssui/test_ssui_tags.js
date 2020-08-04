require_relative("cfme");
include(Cfme);
let pytestmark = [test_requirements.tag];

// 
//   Polarion:
//       assignee: prichard
//       casecomponent: SelfServiceUI
//       caseimportance: medium
//       initialEstimate: 1/8h
//       testSteps:
//           1.Create groups with tag
//           2. Create user and assign it to group
//           3. As admin create service catalog and catalog item
//           4. Log in as user to ssui
//           5. Check catalog item list -> User should not see any items
//           6. As admin set tag to catalog item
//           7. As user, check visibility -> User should see tagged catalog item
//   
// pass
function test_tagvis_ssui_catalog_items() {}
