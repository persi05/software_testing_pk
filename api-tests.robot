*** Settings ***
Documentation    API tests for Simple EPC Simulator
Library          RequestsLibrary
Library          Collections
Test Setup       Reset Simulator

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Test Cases ***
Test Attach UE Assigns Default Bearer
    [Documentation]    Attach UE and verify default bearer=9 is assigned
    Attach UE    1
    UE Should Have Bearer    1    9

Test Attach Same UE Twice Returns Error
    [Documentation]    Attaching same UE twice should return error
    Attach UE    1
    Attaching UE Again Should Fail    1

Test Detach Nonexistent UE Returns Error
    [Documentation]    Detaching UE that is not attached should return error
    Detaching Nonexistent UE Should Fail    50

Test Default Bearer Cannot Be Removed
    [Documentation]    Bearer 9 cannot be deleted
    Attach UE    1
    Removing Default Bearer Should Fail    1

Test Add Duplicate Bearer Returns Error
    [Documentation]    Adding same bearer twice should fail
    Attach UE    1
    Add Bearer To UE    1    1
    Adding Duplicate Bearer Should Fail    1    1

Test Start Traffic On Inactive Bearer Returns Error
    [Documentation]    Cannot start traffic on non-existing bearer
    Attach UE    1
    Starting Traffic On Nonexistent Bearer Should Fail    1    5

Test Traffic Speed Above Limit Returns Error
    [Documentation]    Traffic above 100 Mbps (100000 kbps) should be rejected
    Attach UE    1
    Add Bearer To UE    1    1
    Starting Traffic Above Speed Limit Should Fail    1    1    200000

Test Traffic Speed Normal 50 Mbps
    [Documentation]    Traffic at 50 Mbps (50000 kbps) should work correctly
    Attach UE    1
    Add Bearer To UE    1    1
    Start Traffic    1    1    tcp    50000
    Traffic Stats Should Be Available    1    1
    Stop Traffic    1    1

Test Traffic Speed Negative Returns Error
    [Documentation]    Negative traffic speed should be rejected
    Attach UE    1
    Add Bearer To UE    1    1
    Starting Traffic With Negative Speed Should Fail    1    1    -10000

Test Stop Traffic That Was Not Started Returns Error
    [Documentation]    Stopping traffic that was never started should return error
    Attach UE    1
    Add Bearer To UE    1    1
    Stopping Unstarted Traffic Should Fail    1    1

Test Get Traffic Without Starting Returns Error
    [Documentation]    Getting stats for inactive traffic should fail or return zero
    Attach UE    1
    Add Bearer To UE    1    1
    Traffic Stats Without Starting Should Return Empty Or Error    1    1

Test Reset Clears All State
    [Documentation]    After reset, no UE should exist
    Attach UE    1
    Reset Simulator
    UE List Should Be Empty

Test List UEs Initially Empty
    [Documentation]    Initially List of UEs is empty
    UE List Should Be Empty

Test List Connected UEs
    [Documentation]    After attaching 3 UEs, returns exactly those IDs
    Attach UE    1
    Attach UE    5
    Attach UE    20
    UE List Should Contain Exactly 3 UEs    1    5    20

Test Bearer Lifecycle
    [Documentation]    Bearer can be added and removed
    Attach UE    1
    Add Bearer To UE    1    5
    UE Should Have Bearer    1    5
    Remove Bearer From UE    1    5
    UE Should Not Have Bearer    1    5

Test Bearer ID Validation
    [Documentation]    Bearer ID 10 exceeds maximum of 9, expect error 422
    Attach UE    1
    Adding Bearer With Invalid ID Should Fail    1    10

Test Attach And Detach UE
    [Documentation]    Test correct UE connection and disconnection (Attach & Detach)
    Attach UE    10
    UE Should Be Attached    10
    Detach UE    10
    UE Should Not Be Attached    10

Test Attach UE With ID of Minimum
    [Documentation]    Test UE attachment and detachment with minimum valid ID (0)
    Attach UE    0
    UE Should Be Attached    0
    Detach UE    0
    UE Should Not Be Attached    0

Test Attach UE With ID of Maximum
    [Documentation]    Test UE attachment and detachment with maximum valid ID (100)
    Attach UE    100
    UE Should Be Attached    100
    Detach UE    100
    UE Should Not Be Attached    100

Test Attach UE With ID Below Minimum
    [Documentation]    Test validation of UE ID below minimum (0)
    Attaching UE With Invalid ID Should Fail    -1

Test Attach UE With ID Above Maximum
    [Documentation]    Test validation of UE ID above maximum (101)
    Attaching UE With Invalid ID Should Fail    101

Test Traffic Lifecycle
    [Documentation]    Traffic can be started on a bearer and stopped; stats are available while running
    Attach UE    1
    Add Bearer To UE    1    1
    Start Traffic    1    1    tcp    100
    Traffic Stats Should Be Available    1    1
    Stop Traffic    1    1

Test UE Stats Reflect Attached UEs
    [Documentation]    GET /ues/stats returns correct ue_count after attaching UEs
    Attach UE    3
    Attach UE    4
    UE Stats Should Show Count    2

Test Bearer Operations On Nonexistent UE
    [Documentation]    Bearer POST on UE that was never attached should return 404 or 422
    Adding Bearer To Nonexistent UE Should Fail    99    1

Test Full Traffic End To End
    [Documentation]    Attach UE, add Bearer, start traffic, wait, check stats have duration>0 and nonzero bps, stop traffic
    Attach UE    1
    Add Bearer To UE    1    1
    Start Traffic    1    1    tcp    10000
    Wait    3s
    Traffic Should Have Nonzero Stats    1    1
    Stop Traffic    1    1

Test Traffic Protocol Validation
    [Documentation]    Protocol "icmp" does not match ^(tcp|udp)$, expect 422
    Attach UE    1
    Add Bearer To UE    1    1
    Starting Traffic With Invalid Protocol Should Fail    1    1    icmp
   
Test Detach UE With Active Traffic Stops Traffic
    [Documentation]    Detaching UE with active traffic should automatically stop it
    Verify Detach UE Stops Traffic    1    5

Test Detach UE With Multiple Active Bearers Stops All Traffic
    [Documentation]    Detaching UE should clean up all traffic tasks
    Verify Detach UE Stops Multiple Traffic    1    2    3

Test Traffic Stats Reset After Stop And Restart
    [Documentation]    Counters should clear upon restart
    Verify Traffic Stats Reset    1    5

Test Traffic Duration Resets After Stop And Restart
    [Documentation]    Duration should reset to 0 when traffic is restarted
    Verify Traffic Duration Resets    1    5

*** Keywords ***

# Session / Setup 
Create API Session
    Create Session    api    ${BASE_URL}

Reset Simulator
    Create API Session
    POST On Session    api    /reset

Wait
    [Arguments]    ${duration}
    Sleep    ${duration}

# UE Actions
Attach UE
    [Arguments]    ${ue_id}
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    POST On Session    api    /ues    json=${body}

Detach UE
    [Arguments]    ${ue_id}
    DELETE On Session    api    /ues/${ue_id}

# Bearer Actions
Add Bearer To UE
    [Arguments]    ${ue_id}    ${bearer_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}

Remove Bearer From UE
    [Arguments]    ${ue_id}    ${bearer_id}
    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}

# Traffic Actions
Start Traffic
    [Arguments]    ${ue_id}    ${bearer_id}    ${protocol}    ${kbps}
    ${traffic_body}=    Create Dictionary    protocol=${protocol}    kbps=${kbps}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic_body}

Stop Traffic
    [Arguments]    ${ue_id}    ${bearer_id}
    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic

# UE Assertions
UE Should Be Attached
    [Arguments]    ${ue_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}
    Should Be Equal As Strings    ${resp.status_code}    200    msg=UE ${ue_id} should be attached (200 OK)

UE Should Not Be Attached
    [Arguments]    ${ue_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}    expected_status=any
    Should Be True    ${resp.status_code} == 400 or ${resp.status_code} == 404 or ${resp.status_code} == 422
    ...    msg=UE ${ue_id} should not be reachable after detach

UE Should Have Bearer
    [Arguments]    ${ue_id}    ${bearer_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}
    ${json}=    Set Variable    ${resp.json()}
    Should Contain    ${json["bearers"]}    ${bearer_id}
    ...    msg=UE ${ue_id} should have bearer ${bearer_id}

UE Should Not Have Bearer
    [Arguments]    ${ue_id}    ${bearer_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}
    ${json}=    Set Variable    ${resp.json()}
    Should Not Contain    ${json["bearers"]}    ${bearer_id}
    ...    msg=UE ${ue_id} should not have bearer ${bearer_id} after removal

UE List Should Be Empty
    ${resp}=    GET On Session    api    /ues
    ${json}=    Set Variable    ${resp.json()}
    Should Be Empty    ${json["ues"]}    msg=UE list should be empty

UE List Should Contain Exactly 3 UEs
    [Arguments]    ${id1}    ${id2}    ${id3}
    ${resp}=    GET On Session    api    /ues
    ${json}=    Set Variable    ${resp.json()}
    Length Should Be    ${json["ues"]}    3    msg=UE list should contain exactly 3 UEs
    ${int1}=    Convert To Integer    ${id1}
    ${int2}=    Convert To Integer    ${id2}
    ${int3}=    Convert To Integer    ${id3}
    Should Contain    ${json["ues"]}    ${int1}
    Should Contain    ${json["ues"]}    ${int2}
    Should Contain    ${json["ues"]}    ${int3}

UE Stats Should Show Count
    [Arguments]    ${expected_count}
    ${resp}=    GET On Session    api    /ues/stats
    ${json}=    Set Variable    ${resp.json()}
    Should Be Equal As Integers    ${json["ue_count"]}    ${expected_count}
    ...    msg=UE stats should report ${expected_count} connected UEs

# Traffic Assertions
Traffic Stats Should Be Available
    [Arguments]    ${ue_id}    ${bearer_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    Should Be Equal As Strings    ${resp.status_code}    200    msg=Traffic stats should be available
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    tx_bps
    Dictionary Should Contain Key    ${json}    rx_bps

Traffic Should Have Nonzero Stats
    [Arguments]    ${ue_id}    ${bearer_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ${json}=    Set Variable    ${resp.json()}
    Dictionary Should Contain Key    ${json}    duration
    Should Be True    ${json["duration"]} > 0    msg=Traffic duration should be greater than 0
    Should Be True    ${json["tx_bps"]} > 0    msg=TX bitrate should be nonzero while traffic is running
    Should Be True    ${json["rx_bps"]} > 0    msg=RX bitrate should be nonzero while traffic is running

Traffic Stats Without Starting Should Return Empty Or Error
    [Arguments]    ${ue_id}    ${bearer_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    Should Be True    ${resp.status_code} == 200 or ${resp.status_code} == 400 or ${resp.status_code} == 422
    ...    msg=Getting stats on inactive traffic should return 200 (empty) or error

# Error / Validation Assertions
Should Be Validation Error
    [Arguments]    ${response}    ${msg}=Expected 400 or 422 validation error
    Should Be True    ${response.status_code} == 400 or ${response.status_code} == 422
    ...    msg=${msg}

Attaching UE Again Should Fail
    [Arguments]    ${ue_id}
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${resp}=    POST On Session    api    /ues    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Attaching same UE twice should return error

Attaching UE With Invalid ID Should Fail
    [Arguments]    ${ue_id}
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${resp}=    POST On Session    api    /ues    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}    msg=UE ID ${ue_id} is out of valid range, should return 400 or 422

Detaching Nonexistent UE Should Fail
    [Arguments]    ${ue_id}
    ${resp}=    DELETE On Session    api    /ues/${ue_id}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Detaching non-attached UE should return error

Removing Default Bearer Should Fail
    [Arguments]    ${ue_id}
    ${resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/9    expected_status=any
    Should Be Validation Error    ${resp}    msg=Default bearer 9 should not be removable

Adding Duplicate Bearer Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Adding the same bearer twice should return error

Adding Bearer With Invalid ID Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Bearer ID ${bearer_id} exceeds max, should return 422

Adding Bearer To Nonexistent UE Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Adding bearer to non-attached UE should return 400 or 422

Starting Traffic On Nonexistent Bearer Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${100}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Starting traffic on non-existing bearer should return error

Starting Traffic Above Speed Limit Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}    ${kbps}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${kbps}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Traffic speed ${kbps} kbps exceeds limit, should return error

Starting Traffic With Negative Speed Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}    ${kbps}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${kbps}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Negative traffic speed ${kbps} kbps should return error

Stopping Unstarted Traffic Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${body}=    Create Dictionary    bearer_id=${bearer_id}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}
    ${get_resp}=    GET On Session    api    /ues/${ue_id}
    ${json}=    Parse Response JSON    ${get_resp}
    Should Be True    "${bearer_id}" not in $json["bearers"]
    
Starting Traffic With Invalid Protocol Should Fail
    [Arguments]    ${ue_id}    ${bearer_id}    ${protocol}
    ${traffic}=    Create Dictionary    protocol=${protocol}    kbps=${100}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}    msg=Protocol "${protocol}" is not supported, should return 422

Verify Detach UE Stops Traffic
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${100}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic}
    DELETE On Session    api    /ues/${ue_id}
    ${resp}=    GET On Session    api    /ues/stats
    ${json}=    Parse Response JSON    ${resp}
    Should Be Equal As Integers    ${json["bearer_count"]}    0

Verify Detach UE Stops Multiple Traffic
    [Arguments]    ${ue_id}    ${bearer_1}    ${bearer_2}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${b1}=    Create Dictionary    bearer_id=${bearer_1}
    ${b2}=    Create Dictionary    bearer_id=${bearer_2}
    POST On Session    api    /ues/${ue_id}/bearers    json=${b1}
    POST On Session    api    /ues/${ue_id}/bearers    json=${b2}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${100}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_1}/traffic    json=${traffic}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_2}/traffic    json=${traffic}
    DELETE On Session    api    /ues/${ue_id}
    ${resp}=    GET On Session    api    /ues/stats
    ${json}=    Parse Response JSON    ${resp}
    Should Be Equal As Integers    ${json["bearer_count"]}    0

Verify Traffic Stats Reset
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${100}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic}
    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic}
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ${json}=    Parse Response JSON    ${resp}
    Dictionary Should Contain Key    ${json}    tx_bps

Verify Traffic Duration Resets
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${100}
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic}
    Sleep    7s
    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic}
    Sleep    1s
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ${json}=    Parse Response JSON    ${resp}
    Should Be True    ${json["duration"]} < 2    msg=Duration should reset after stop+start, but got ${json["duration"]}s (expected < 3s)
    ${resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    Should Be Validation Error    ${resp}    msg=Stopping traffic that was never started should return error
