*** Settings ***
Documentation    API tests for Simple EPC Simulator
Library          RequestsLibrary

*** Variables ***
${BASE_URL}    http://localhost:8000

*** Test Cases ***
Test List UEs Initially Empty
    [Documentation]    Initinially List of UEs is empty
    Verify UEs List Is Empty

*** Keywords ***
Verify UEs List Is Empty
    Create API Session
    ${response}=    GET On Session    api    /ues
    Should Be Equal As Strings    ${response.status_code}    200
    ${json}=    Parse Response JSON    ${response}
    ${ues}=    Set Variable    ${json["ues"]}
    Should Be Empty    ${ues}

Create API Session
    Create Session    api    ${BASE_URL}

Parse Response JSON
    [Arguments]    ${response}
    ${json}=    Set Variable    ${response.json()}
    RETURN    ${json}