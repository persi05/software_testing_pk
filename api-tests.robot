*** Settings ***
Documentation    API tests for Simple EPC Simulator
Library          RequestsLibrary

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Test Cases ***
Test List UEs Initially Empty
    [Documentation]    Initinially List of UEs is empty
    Verify UEs List Is Empty

Test List Connected UEs
    [Documentation]    After attaching 3 UEs, returns exactly those IDs
    Verify UEs List Contains Exactly    1    5    20

*** Keywords ***
Verify UEs List Is Empty
    Create API Session
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
    POST On Session    api    /ues    json={"ue_id": ${ue_id}}