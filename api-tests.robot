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
        List Should Contain Value    ${json["ues"]}    ${ue_id}
    END

Verify Bearer Lifecycle For UE
    [Arguments]    ${ue_id}    ${bearer_id}
    Create API Session
    Reset Simulator State
    Attach UE    ${ue_id}
    ${add_resp}=    POST On Session    api    /ues/${ue_id}/bearers    json={"bearer_id": ${bearer_id}}
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
    ${response}=    POST On Session    api    /ues/${ue_id}/bearers    json={"bearer_id": ${bearer_id}}    expected_status=any
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
    ${payload}=    Create Dictionary    ue_id=${ue_id}
    POST On Session    api    /ues    json=${payload}