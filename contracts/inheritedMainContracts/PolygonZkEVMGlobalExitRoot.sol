// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.20;

import "../interfaces/IPolygonZkEVMGlobalExitRoot.sol";
import "../lib/GlobalExitRootLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * Contract responsible for managing the exit roots across multiple networks
 */
contract PolygonZkEVMGlobalExitRoot is IPolygonZkEVMGlobalExitRoot, Initializable {
    // PolygonZkEVMBridge address
    address public bridgeAddress;

    // Rollup contract address
    address public rollupAddress;

    // Rollup exit root, this will be updated every time a batch is verified
    bytes32 public lastRollupExitRoot;

    // Mainnet exit root, this will be updated every time a deposit is made in mainnet
    bytes32 public lastMainnetExitRoot;

    // Store every global exit root: Root --> timestamp
    mapping(bytes32 => uint256) public globalExitRootMap;

    /**
     * @dev Emitted when the global exit root is updated
     */
    event UpdateGlobalExitRoot(
        bytes32 indexed mainnetExitRoot,
        bytes32 indexed rollupExitRoot
    );

    /**
     * @param _rollupAddress Rollup contract address
     * @param _bridgeAddress PolygonZkEVMBridge contract address
     */
    function initialize(address _rollupAddress, address _bridgeAddress, bytes32 _lastMainnetExitRoot, bytes32 _lastRollupExitRoot) public virtual onlyInitializing {
        rollupAddress = _rollupAddress;
        bridgeAddress = _bridgeAddress;
        lastMainnetExitRoot = _lastMainnetExitRoot;
        lastRollupExitRoot = _lastRollupExitRoot;
        if(_lastMainnetExitRoot != bytes32(0) || _lastRollupExitRoot != bytes32(0)){
            _updateGlobalExitRootHash(_lastMainnetExitRoot, _lastRollupExitRoot);
        }
    }

    /**
     * @notice Update the exit root of one of the networks and the global exit root
     * @param newRoot new exit tree root
     */
    function updateExitRoot(bytes32 newRoot) external {
        // Store storage variables into temporal variables since will be used multiple times
        bytes32 cacheLastRollupExitRoot = lastRollupExitRoot;
        bytes32 cacheLastMainnetExitRoot = lastMainnetExitRoot;

        if (msg.sender == bridgeAddress) {
            lastMainnetExitRoot = newRoot;
            cacheLastMainnetExitRoot = newRoot;
        } else if (msg.sender == rollupAddress) {
            lastRollupExitRoot = newRoot;
            cacheLastRollupExitRoot = newRoot;
        } else {
            revert OnlyAllowedContracts();
        }

        _updateGlobalExitRootHash(cacheLastMainnetExitRoot, cacheLastRollupExitRoot);
    }

    /**
     * @notice Update the global exit root
        * @param cacheLastMainnetExitRoot last mainnet exit root
        * @param cacheLastRollupExitRoot last rollup exit root
     */
    function _updateGlobalExitRootHash(bytes32 cacheLastMainnetExitRoot, bytes32 cacheLastRollupExitRoot) internal {
        bytes32 newGlobalExitRoot = GlobalExitRootLib.calculateGlobalExitRoot(
            cacheLastMainnetExitRoot,
            cacheLastRollupExitRoot
        );

        // If it already exists, do not modify the timestamp
        if (globalExitRootMap[newGlobalExitRoot] == 0) {
            globalExitRootMap[newGlobalExitRoot] = block.timestamp;
            emit UpdateGlobalExitRoot(
                cacheLastMainnetExitRoot,
                cacheLastRollupExitRoot
            );
        }
    }

    /**
     * @notice Return last global exit root
     */
    function getLastGlobalExitRoot() public view returns (bytes32) {
        return
            GlobalExitRootLib.calculateGlobalExitRoot(
                lastMainnetExitRoot,
                lastRollupExitRoot
            );
    }
}
