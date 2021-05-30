// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../shared/BaseDataInsurerController.sol";
import "../shared/PayableContract.sol";
import "./DataOperationalContract.sol";

abstract contract DataInsurerController is PayableContract, DataOperationalContract, BaseDataInsurerController, DataContract {

    // configurable parameters by contract owner
    uint private insurerFee = 10 ether;
    uint private numberOfFullyQualifiedInsurersRequiredForMultiParityConsensus = 5;

    enum InsurerState{
        UNREGISTERED, // 0
        REGISTERED, // 1
        APPROVED, // 2
        FULLY_QUALIFIED // 3
    }

    struct InsurerProfile {
        string name;
        InsurerState state;
        uint amountPaid;
        uint16 approversCtr;
        mapping(address => bool) approvers;
    }

    uint16 fullyQualifiedInsurersCtr;
    mapping(address => InsurerProfile) private insurers;

    /**
    * API
    */

    event InsurerStateChanged(address insurerAddress, string name, uint state);

    function setInsurerConfigParams(uint _insurerFee, uint _numberOfFullyQualifiedInsurersRequiredForMultiParityConsensus) external override requireContractOwner {
        insurerFee = _insurerFee;
        numberOfFullyQualifiedInsurersRequiredForMultiParityConsensus = _numberOfFullyQualifiedInsurersRequiredForMultiParityConsensus;
    }

    function registerInsurer(address insurerAddress, string memory insurerName) external override requireIsOperational requiredFullyQualifiedInsurer requiredAuthorizedCaller {
        require(insurers[insurerAddress].state == InsurerState.UNREGISTERED, "Insurer is already registered");

        insurers[insurerAddress].name = insurerName;
        insurers[insurerAddress].state = InsurerState.REGISTERED;

        triggerInsurerStateChange(insurerAddress);
    }

    function approveInsurer(address insurerAddress) external override requireIsOperational requiredFullyQualifiedInsurer requiredAuthorizedCaller {
        require(insurers[insurerAddress].state == InsurerState.REGISTERED, "Insurer is not yet registered or has been already approved");
        require(insurers[insurerAddress].approvers[msg.sender] == false, "Insurer has been already approved by this caller");

        insurers[insurerAddress].approvers[msg.sender] = true;
        insurers[insurerAddress].approversCtr++;

        if (isInsurerApproved(insurerAddress)) {
            insurers[insurerAddress].state = InsurerState.APPROVED;
            triggerInsurerStateChange(insurerAddress);
        }
    }

    function payInsurerFee() external payable override requireIsOperational giveChangeBack(insurerFee) requiredAuthorizedCaller {
        require(insurers[msg.sender].state == InsurerState.APPROVED, "Insurer is not yet approved or has been already approved");
        require(msg.value >= insurerFee, "Insufficient insurer's fee");

        insurers[msg.sender].state = InsurerState.FULLY_QUALIFIED;
        insurers[msg.sender].amountPaid = getInsurerPaidAmount();
        fullyQualifiedInsurersCtr++;

        triggerInsurerStateChange(msg.sender);
    }

    /**
    * Modifiers and private methods
    */

    modifier requiredFullyQualifiedInsurer(){
        require(insurers[msg.sender].state == InsurerState.FULLY_QUALIFIED, "Caller is not a fully qualified insurer");
        _;
    }

    function getInsurerPaidAmount() private view returns (uint){
        if (msg.value >= insurerFee) {
            return insurerFee;
        }

        return msg.value;
    }

    function isInsurerApproved(address insurerAddress) private view returns (bool) {
        if (fullyQualifiedInsurersCtr < numberOfFullyQualifiedInsurersRequiredForMultiParityConsensus) {
            return true;
        }

        return insurers[insurerAddress].approversCtr * 2 >= fullyQualifiedInsurersCtr;
    }

    function triggerInsurerStateChange(address insurerAddress) private {
        emit InsurerStateChanged(insurerAddress, insurers[insurerAddress].name, uint(insurers[insurerAddress].state));
    }

}
