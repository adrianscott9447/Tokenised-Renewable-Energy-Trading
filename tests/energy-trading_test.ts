import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;

describe("Energy Trading Contract", () => {
  beforeEach(() => {
    // Setup runs before each test
  });

  describe("Producer Registration", () => {
    it("should allow producer registration", () => {
      const { result } = simnet.callPublicFn(
        "energy-trading",
        "register-producer",
        [
          Cl.stringAscii("Solar Farm Co"),
          Cl.stringAscii("solar")
        ],
        wallet_1
      );
      expect(result).toBeOk(Cl.bool(true));
    });

    it("should prevent empty name registration", () => {
      const { result } = simnet.callPublicFn(
        "energy-trading",
        "register-producer", 
        [
          Cl.stringAscii(""),
          Cl.stringAscii("solar")
        ],
        wallet_1
      );
      expect(result).toBeErr(Cl.uint(108));
    });
  });

  describe("Token Functions", () => {
    it("should return correct token name", () => {
      const { result } = simnet.callReadOnlyFn(
        "energy-trading",
        "get-name",
        [],
        deployer
      );
      expect(result).toBeOk(Cl.stringAscii("Green Energy Token"));
    });

    it("should return correct token symbol", () => {
      const { result } = simnet.callReadOnlyFn(
        "energy-trading",
        "get-symbol", 
        [],
        deployer
      );
      expect(result).toBeOk(Cl.stringAscii("GET"));
    });

    it("should return correct decimals", () => {
      const { result } = simnet.callReadOnlyFn(
        "energy-trading",
        "get-decimals",
        [],
        deployer
      );
      expect(result).toBeOk(Cl.uint(6));
    });
  });

  describe("Energy Production", () => {
    beforeEach(() => {
      // Register and verify producer
      simnet.callPublicFn(
        "energy-trading",
        "register-producer",
        [
          Cl.stringAscii("Solar Farm Co"),
          Cl.stringAscii("solar")
        ],
        wallet_1
      );
      
      simnet.callPublicFn(
        "energy-trading", 
        "verify-producer",
        [Cl.principal(wallet_1)],
        deployer
      );
    });

    it("should allow verified producer to record production", () => {
      const { result } = simnet.callPublicFn(
        "energy-trading",
        "record-production",
        [
          Cl.uint(1000),
          Cl.stringAscii("solar"),
          Cl.stringAscii("cert123abc")
        ],
        wallet_1
      );
      expect(result).toBeOk(Cl.uint(1000));
    });

    it("should mint tokens for production", () => {
      simnet.callPublicFn(
        "energy-trading",
        "record-production",
        [
          Cl.uint(1000),
          Cl.stringAscii("solar"),
          Cl.stringAscii("cert123abc")
        ],
        wallet_1
      );

      const { result } = simnet.callReadOnlyFn(
        "energy-trading",
        "get-balance",
        [Cl.principal(wallet_1)],
        deployer
      );
      expect(result).toBeOk(Cl.uint(1000));
    });
  });

  describe("Energy Trading", () => {
    beforeEach(() => {
      // Setup producer with tokens
      simnet.callPublicFn(
        "energy-trading",
        "register-producer", 
        [
          Cl.stringAscii("Solar Farm Co"),
          Cl.stringAscii("solar")
        ],
        wallet_1
      );
      
      simnet.callPublicFn(
        "energy-trading",
        "verify-producer",
        [Cl.principal(wallet_1)],
        deployer
      );
      
      simnet.callPublicFn(
        "energy-trading",
        "record-production",
        [
          Cl.uint(1000),
          Cl.stringAscii("solar"),
          Cl.stringAscii("cert123abc")
        ],
        wallet_1
      );
    });

    it("should create energy listing", () => {
      const { result } = simnet.callPublicFn(
        "energy-trading",
        "create-listing",
        [
          Cl.uint(500),
          Cl.uint(100),
          Cl.uint(144) // ~1 day in blocks
        ],
        wallet_1
      );
      expect(result).toBeOk(Cl.uint(1));
    });

    it("should prevent self-purchase", () => {
      // Create listing
      simnet.callPublicFn(
        "energy-trading", 
        "create-listing",
        [
          Cl.uint(500),
          Cl.uint(100),
          Cl.uint(144)
        ],
        wallet_1
      );

      // Try to purchase own listing
      const { result } = simnet.callPublicFn(
        "energy-trading",
        "purchase-energy",
        [Cl.uint(1)],
        wallet_1
      );
      expect(result).toBeErr(Cl.uint(105)); // ERR_SELF_PURCHASE
    });
  });
});