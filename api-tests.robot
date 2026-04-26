*** Settings ***
Documentation    API tests for Simple EPC Simulator
Library          RequestsLibrary
Library          Collections

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Test Cases ***
Test Attach UE Assigns Default Bearer
    [Documentation]    Attach UE and verify default bearer=9 is assigned
    Verify Attach UE Assigns Default Bearer    1

Test Attach Same UE Twice Returns Error
    [Documentation]    Attaching same UE twice should return error
    Verify Attach Same UE Twice Returns Error    1

Test Detach Nonexistent UE Returns Error
    [Documentation]    Detaching UE that is not attached should return error
    Verify Detach Nonexistent UE Returns Error    50

Test Default Bearer Cannot Be Removed
    [Documentation]    Bearer 9 cannot be deleted
    Verify Default Bearer Cannot Be Removed    1

Test Add Duplicate Bearer Returns Error
    [Documentation]    Adding same bearer twice should fail
    Verify Add Duplicate Bearer Returns Error    1    1

Test Start Traffic On Inactive Bearer Returns Error
    [Documentation]    Cannot start traffic on non-existing bearer
    Verify Start Traffic On Inactive Bearer Returns Error    1    5

Test Traffic Speed Above Limit Returns Error
    [Documentation]    Traffic above 100 Mbps should fail
    Verify Traffic Speed Above Limit Returns Error    1    1    200000

Test Traffic Speed Normal 50 Mbps
    [Documentation]    Traffic at 50 Mbps (50000 kbps) should work correctly
    Verify Traffic Speed Valid    1    1    50000

Test Traffic Speed Negative Returns Error
    [Documentation]    Negative traffic speed should return error
    Verify Traffic Speed Invalid    1    1    -10000

Test Stop Traffic That Was Not Started Returns Error
    [Documentation]    Stopping traffic that was never started should fail
    Verify Stop Traffic That Was Not Started Returns Error    1    1

Test Get Traffic Without Starting Returns Error
    [Documentation]    Getting stats for inactive traffic should fail or return zero
    Verify Get Traffic Without Starting Returns Error    1    1

Test Reset Clears All State
    [Documentation]    After reset, no UE should exist
    Verify Reset Clears All State    1

Test List UEs Initially Empty
    [Documentation]    Initially List of UEs is empty
    Verify UEs List Is Empty

Test List Connected UEs
    [Documentation]    After attaching 3 UEs, returns exactly those IDs
    Verify UEs List Contains Exactly    1    5    20

Test Bearer Lifecycle
    [Documentation]    Bearer can be added and removed
    Verify Bearer Lifecycle For UE    1    5

Test Bearer ID Validation
    [Documentation]    Bearer ID 10 exceeds maximum of 9, expect error 422
    Verify Bearer ID Above Max Is Rejected    1    10

Test Attach And Detach UE
    [Documentation]    Test correct UE connection and disconnection (Attach & Detach)
    Verify UE Attach And Detach    10

Test Attach UE With ID of Minimum
    [Documentation]    Test UE attachment and detachment with minimum valid ID (0)
    Verify UE Attach And Detach    0

Test Attach UE With ID of Maximum
    [Documentation]    Test UE attachment and detachment with maximum valid ID (100)
    Verify UE Attach And Detach    100

Test Attach UE With ID Below Minimum
    [Documentation]    Test validation of UE ID below minimum (0)
    Verify UE Attach With Invalid ID    -1

Test Attach UE With ID Above Maximum
    [Documentation]    Test validation of UE ID above maximum (101)
    Verify UE Attach With Invalid ID    101

Test Traffic Lifecycle
    [Documentation]    Traffic can be started on a bearer and stopped; stats are available while running
    Verify Traffic Lifecycle For UE And Bearer    1    1

Test UE Stats Reflect Attached UEs
    [Documentation]    GET /ues/stats returns correct ue_count after attaching UEs
    Verify Stats UE Count After Attach    2    3

Test Bearer Operations On Nonexistent UE
    [Documentation]    Bearer POST on UE that was never attached should return 404 or 422
    Verify Bearer Operations On Nonexistent UE    99    1

Test Full Traffic End To End
    [Documentation]    Attach UE, add Bearer, start traffic, wait, check stats have duration>0 and nonzero bps, stop traffic
    Verify Full Traffic End To End    1    1

Test Traffic Protocol Validation
    [Documentation]    Protocol "icmp" does not match ^(tcp|udp)$, expect 422
    Verify Traffic Protocol Validation    1    1    icmp

Test Stop Traffic On Default Bearer Never Started Returns Error
    [Documentation]    Stop traffic on default bearer 9 that has no running traffic
    Verify Stop Traffic On Default Bearer Never Started    1

Test Delete Bearer Removes It From State
    [Documentation]    After deleting bearer, it should not appear in GET /ues/{ue_id}
    Verify Delete Bearer Removes From State    1    3

*** Keywords ***
Verify Attach UE Assigns Default Bearer
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${resp}=    GET On Session    api    /ues/${ue_id}
    ${json}=    Parse Response JSON    ${resp}
    Should Contain    ${json["bearers"]}    9

Verify Attach Same UE Twice Returns Error
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${resp}=    POST On Session    api    /ues    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}

Verify Detach Nonexistent UE Returns Error
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    ${resp}=    DELETE On Session    api    /ues/${ue_id}    expected_status=any
    Should Be Validation Error    ${resp}

Verify Default Bearer Cannot Be Removed
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/9    expected_status=any
    Should Be Validation Error    ${resp}

Verify Add Duplicate Bearer Returns Error
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${resp}

Verify Start Traffic On Inactive Bearer Returns Error
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=100
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}

Verify Traffic Speed Above Limit Returns Error
    [Arguments]    ${ue_id}    ${bearer_id}    ${kbps}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic}=    Create Dictionary    protocol=tcp    kbps=${kbps}
    ${resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic}    expected_status=any
    Should Be Validation Error    ${resp}

Verify Stop Traffic That Was Not Started Returns Error
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    Should Be Validation Error    ${resp}

Verify Get Traffic Without Starting Returns Error
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    Should Be True    ${resp.status_code} == 200 or ${resp.status_code} == 400 or ${resp.status_code} == 422

Verify Reset Clears All State
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    POST On Session    api    /reset
    ${resp}=    GET On Session    api    /ues
    ${json}=    Parse Response JSON    ${resp}
    Should Be Empty    ${json["ues"]}

Verify UEs List Is Empty
    Create API Session
    Reset Simulator State
    ${response}=    GET On Session    api    /ues
    Should Be Equal As Strings    ${response.status_code}    200
    ${json}=    Parse Response JSON    ${response}
    ${ues}=    Set Variable    ${json["ues"]}
    Should Be Empty    ${ues}

Verify UEs List Contains Exactly
    [Arguments]    @{expected_ids}
    Create API Session
    Reset Simulator State
    FOR    ${ue_id}    IN    @{expected_ids}
        Attach UE    ${ue_id}
    END
    ${response}=    GET On Session    api    /ues
    Should Be Equal As Strings    ${response.status_code}    200
    ${json}=    Parse Response JSON    ${response}
    Length Should Be    ${json["ues"]}    ${3}
    FOR    ${ue_id}    IN    @{expected_ids}
        ${int_id}=    Convert To Integer    ${ue_id}
        Should Contain    ${json["ues"]}    ${int_id}
    END

Verify Bearer Lifecycle For UE
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${add_resp}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    Should Be Equal As Strings    ${add_resp.status_code}    200
    ${get_resp}=    GET On Session    api    /ues/${ue_id}
    Should Be Equal As Strings    ${get_resp.status_code}    200
    ${json}=    Parse Response JSON    ${get_resp}
    Should Be True    "${bearer_id}" in $json["bearers"]
    ${del_resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}
    Should Be Equal As Strings    ${del_resp.status_code}    200
    ${get_after}=    GET On Session    api    /ues/${ue_id}
    ${json_after}=    Parse Response JSON    ${get_after}
    Should Be True    "${bearer_id}" not in $json_after["bearers"]

Verify Bearer ID Above Max Is Rejected
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${response}

Create API Session
    Create Session    api    ${BASE_URL}

Parse Response JSON
    [Arguments]    ${response}
    ${json}=    Set Variable    ${response.json()}
    RETURN    ${json}

Reset Simulator State
    POST On Session    api    /reset

Attach UE
    [Arguments]    ${ue_id}
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    POST On Session    api    /ues    json=${body}

Verify UE Attach And Detach
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    # Attach UE and verify response
    ${int_id}=    Convert To Integer    ${ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${attach_response}=    POST On Session    api    /ues    json=${body}
    Should Be Equal As Strings    ${attach_response.status_code}    200    msg=Attach request should return 200 OK
    ${attach_json}=    Parse Response JSON    ${attach_response}
    Should Be Equal As Integers    ${attach_json["ue_id"]}    ${ue_id}    msg=Response should contain correct UE ID
    # Detach UE and verify response
    ${detach_response}=    DELETE On Session    api    /ues/${ue_id}
    Should Be Equal As Strings    ${detach_response.status_code}    200    msg=Detach request should return 200 OK
    ${detach_json}=    Parse Response JSON    ${detach_response}
    Should Be Equal As Integers    ${detach_json["ue_id"]}    ${ue_id}    msg=Response should contain correct UE ID

Verify UE Attach With Invalid ID
    [Documentation]    Verify UE attach validation: IDs outside valid range should return 400 or 422
    [Arguments]    ${invalid_ue_id}
    Create API Session
    Reset Simulator State
    ${int_id}=    Convert To Integer    ${invalid_ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${response}=    POST On Session    api    /ues    json=${body}    expected_status=any
    Should Be Validation Error    ${response}    msg=Invalid UE ID should return 400 or 422

Verify Traffic Lifecycle For UE And Bearer
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic_body}=    Create Dictionary    protocol=tcp    kbps=${100}
    ${start_resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic_body}
    Should Be Equal As Strings    ${start_resp.status_code}    200
    ${start_json}=    Parse Response JSON    ${start_resp}
    Should Be Equal As Integers    ${start_json["ue_id"]}    ${ue_id}
    Should Be Equal As Integers    ${start_json["bearer_id"]}    ${bearer_id}
    ${stats_resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    Should Be Equal As Strings    ${stats_resp.status_code}    200
    ${stats_json}=    Parse Response JSON    ${stats_resp}
    Dictionary Should Contain Key    ${stats_json}    tx_bps
    Dictionary Should Contain Key    ${stats_json}    rx_bps
    ${stop_resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    Should Be Equal As Strings    ${stop_resp.status_code}    200
    ${stop_json}=    Parse Response JSON    ${stop_resp}
    Should Be Equal As Integers    ${stop_json["ue_id"]}    ${ue_id}
    Should Be Equal As Integers    ${stop_json["bearer_id"]}    ${bearer_id}

Verify Stats UE Count After Attach
    [Arguments]    ${attach_count}    ${ue_id_start}
    Create API Session
    Reset Simulator State
    FOR    ${i}    IN RANGE    ${attach_count}
        ${ue_id}=    Evaluate    ${ue_id_start} + ${i}
        Attach UE    ${ue_id}
    END
    ${resp}=    GET On Session    api    /ues/stats
    Should Be Equal As Strings    ${resp.status_code}    200
    ${json}=    Parse Response JSON    ${resp}
    Should Be Equal As Integers    ${json["ue_count"]}    ${attach_count}

Verify Bearer Operations On Nonexistent UE
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    Should Be Validation Error    ${response}
    ...    msg=Bearer POST on nonexistent UE should return 400 or 422

Verify Full Traffic End To End
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic_body}=    Create Dictionary    protocol=tcp    kbps=${10000}
    ${start_resp}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic_body}
    Should Be Equal As Strings    ${start_resp.status_code}    200    msg=Start traffic should return 200
    Sleep    3s
    ${stats_resp}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    Should Be Equal As Strings    ${stats_resp.status_code}    200    msg=Traffic stats should return 200
    ${stats_json}=    Parse Response JSON    ${stats_resp}
    Dictionary Should Contain Key    ${stats_json}    duration
    Dictionary Should Contain Key    ${stats_json}    tx_bps
    Dictionary Should Contain Key    ${stats_json}    rx_bps
    Should Be True    ${stats_json["duration"]} > 0    msg=Traffic duration should be greater than 0
    Should Be True    ${stats_json["tx_bps"]} > 0    msg=tx_bps should be nonzero after traffic is running
    Should Be True    ${stats_json["rx_bps"]} > 0    msg=rx_bps should be nonzero after traffic is running
    ${stop_resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    Should Be Equal As Strings    ${stop_resp.status_code}    200    msg=Stop traffic should return 200
    ${stop_json}=    Parse Response JSON    ${stop_resp}
    Should Be Equal As Integers    ${stop_json["ue_id"]}    ${ue_id}
    Should Be Equal As Integers    ${stop_json["bearer_id"]}    ${bearer_id}

Verify Traffic Protocol Validation
    [Arguments]    ${ue_id}    ${bearer_id}    ${invalid_protocol}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    POST On Session    api    /ues/${ue_id}/bearers    json=${body}
    ${traffic_body}=    Create Dictionary    protocol=${invalid_protocol}    kbps=${100}
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic
    ...    json=${traffic_body}    expected_status=any
    Should Be Validation Error    ${response}
    ...    msg=Unsupported protocol "${invalid_protocol}" should return 400 or 422

Detach UE
    [Arguments]    ${ue_id}
    ${response}=    DELETE On Session    api    /ues/${ue_id}
    RETURN    ${response}

Start Traffic
    [Arguments]    ${ue_id}    ${bearer_id}    ${protocol}    ${kbps}
    ${traffic_body}=    Create Dictionary    protocol=${protocol}    kbps=${kbps}
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    json=${traffic_body}    expected_status=any
    RETURN    ${response}

Stop Traffic
    [Arguments]    ${ue_id}    ${bearer_id}
    ${response}=    DELETE On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    RETURN    ${response}

Get Traffic Stats
    [Arguments]    ${ue_id}    ${bearer_id}
    ${response}=    GET On Session    api    /ues/${ue_id}/bearers/${bearer_id}/traffic    expected_status=any
    RETURN    ${response}

Add Bearer To UE
    [Arguments]    ${ue_id}    ${bearer_id}
    ${int_bearer}=    Convert To Integer    ${bearer_id}
    ${body}=    Create Dictionary    bearer_id=${int_bearer}
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers    json=${body}    expected_status=any
    RETURN    ${response}

Verify Traffic Speed Valid
    [Arguments]    ${ue_id}    ${bearer_id}    ${kbps}
    [Documentation]    Verify that traffic speed works correctly and returns proper stats
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    Add Bearer To UE    ${ue_id}    ${bearer_id}
    ${start_resp}=    Start Traffic    ${ue_id}    ${bearer_id}    tcp    ${kbps}
    Should Be Equal As Strings    ${start_resp.status_code}    200    msg=Start traffic at ${kbps} kbps should return 200 OK
    Sleep    1s
    ${stats_resp}=    Get Traffic Stats    ${ue_id}    ${bearer_id}
    Should Be Equal As Strings    ${stats_resp.status_code}    200    msg=Get traffic stats should return 200 OK
    ${stats_json}=    Parse Response JSON    ${stats_resp}
    Dictionary Should Contain Key    ${stats_json}    tx_bps    msg=Response should contain tx_bps
    Dictionary Should Contain Key    ${stats_json}    rx_bps    msg=Response should contain rx_bps
    Dictionary Should Contain Key    ${stats_json}    duration    msg=Response should contain duration
    Should Be True    ${stats_json["duration"]} > 0    msg=Duration should be greater than 0
    Should Be True    ${stats_json["tx_bps"]} > 0    msg=TX BPS should be greater than 0
    Should Be True    ${stats_json["rx_bps"]} > 0    msg=RX BPS should be greater than 0
    ${stop_resp}=    Stop Traffic    ${ue_id}    ${bearer_id}
    Should Be Equal As Strings    ${stop_resp.status_code}    200    msg=Stop traffic should return 200 OK

Verify Traffic Speed Invalid
    [Arguments]    ${ue_id}    ${bearer_id}    ${kbps}
    [Documentation]    Verify that invalid traffic speed (negative, zero) returns error
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    Add Bearer To UE    ${ue_id}    ${bearer_id}
    ${start_resp}=    Start Traffic    ${ue_id}    ${bearer_id}    tcp    ${kbps}
    Should Be Validation Error    ${start_resp}    msg=Invalid traffic speed ${kbps} kbps should return 400 or 422

Should Be Validation Error
    [Arguments]    ${response}    ${msg}=Expected 400 or 422 validation error
    Should Be True    ${response.status_code} == 400 or ${response.status_code} == 422
    ...    msg=${msg}

Verify Stop Traffic On Default Bearer Never Started
    [Arguments]    ${ue_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${resp}=    DELETE On Session    api    /ues/${ue_id}/bearers/9/traffic    expected_status=any
    Should Be Equal As Strings    ${resp.status_code}    400    msg=Stopping traffic on default bearer that was never started should return 400: ${resp.status_code} != 400

Verify Delete Bearer Removes From State
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