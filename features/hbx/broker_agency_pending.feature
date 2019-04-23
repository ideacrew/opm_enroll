Feature: HBX Admin should be able to send the broker application to pending state

  Scenario: Broker can enter ACH information
    When Primary Broker visits the HBX Broker Registration form
    Given a valid ach record exists
    Given Primary Broker has not signed up as an HBX user
    Then Primary Broker should see the New Broker Agency form
    When Primary Broker enters personal information
    And Primary Broker enters broker agency information for SHOP markets
    And Primary Broker enters office location for default_office_location
    Then Primary Broker should see bank information

  Scenario: HBX Admin sends a Broker Applicant to a pending state
    When Primary Broker visits the HBX Broker Registration form
    Given a valid ach record exists
    Given Primary Broker has not signed up as an HBX user
    Then Primary Broker should see the New Broker Agency form
    When Primary Broker enters personal information
    And Primary Broker enters broker agency information for SHOP markets
    And Primary Broker enters office location for default_office_location
    And Primary Broker clicks on Create Broker Agency
    Then Primary Broker should see broker registration successful message
    Given Hbx Admin exists
    When Hbx Admin logs on to the Hbx Portal
    And I select the all security question and give the answer
    When I have submitted the security questions
    And Hbx Admin clicks on the Brokers dropdown
    And Hbx Admin clicks on the Broker Applications option
    Then Hbx Admin should see the list of broker applicants
    When Hbx Admin clicks on the current broker applicant show button
    Then Hbx Admin should see the broker application with carrier appointments
    And Hbx Admin checks FCHP
    And Hbx Admin checks Guardian
    When Hbx Admin clicks pending button
    Then Hbx Admin sees a successful message
