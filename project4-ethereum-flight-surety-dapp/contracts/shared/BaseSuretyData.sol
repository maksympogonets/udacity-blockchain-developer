// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseOperationalContract.sol";
import "./BaseDataContract.sol";
import "./BaseDataInsurerController.sol";
import "./BaseDataInsuranceController.sol";

interface BaseSuretyData is BaseOperationalContract, BaseDataContract, BaseDataInsurerController, BaseDataInsuranceController {
}

