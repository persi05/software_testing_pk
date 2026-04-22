*** Settings ***
Documentation    API tests for Simple EPC Simulator
Library          RequestsLibrary
Library          Collections

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Test Cases ***
Test List UEs Initially Empty
    [Documentation]    Initinially List of UEs is empty
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

*** Keywords ***
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
    Should Be Equal As Strings    ${response.status_code}    422

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
    [Documentation]    Verify UE attach validation: IDs outside range 1-100 should return 422 Validation Error
    [Arguments]    ${invalid_ue_id}
    Create API Session
    Reset Simulator State
    ${int_id}=    Convert To Integer    ${invalid_ue_id}
    ${body}=    Create Dictionary    ue_id=${int_id}
    ${response}=    POST On Session    api    /ues    json=${body}    expected_status=any
    Should Be Equal As Strings    ${response.status_code}    422    msg=Invalid UE ID should return 422 Validation Error

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
    Should Be Equal As Strings    ${response.status_code}    422
    ...    msg=Bearer POST on nonexistent UE should return 422
    
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
    Should Be Equal As Strings    ${response.status_code}    422
    ...    msg=Unsupported protocol "${invalid_protocol}" should return 422 Validation Error