import { describe, expect, it } from "vitest";
import { readFileSync } from "fs";
import { resolve } from "path";

describe("Energy Trading Contract", () => {
  it("should have energy-trading contract file", () => {
    const contractPath = resolve("contracts/energy-trading.clar");
    const contractContent = readFileSync(contractPath, "utf8");
    
    expect(contractContent).toContain("define-fungible-token green-energy-token");
    expect(contractContent).toContain("Green Energy Token");
    expect(contractContent).toContain("register-producer");
    expect(contractContent).toContain("record-production");
    expect(contractContent).toContain("create-listing");
  });

  it("should have energy-certificates contract file", () => {
    const contractPath = resolve("contracts/energy-certificates.clar");
    const contractContent = readFileSync(contractPath, "utf8");
    
    expect(contractContent).toContain("Energy Certificates Contract");
    expect(contractContent).toContain("register-issuer");
    expect(contractContent).toContain("issue-certificate");
    expect(contractContent).toContain("retire-certificate");
  });

  it("should have proper error constants defined", () => {
    const contractPath = resolve("contracts/energy-trading.clar");
    const contractContent = readFileSync(contractPath, "utf8");
    
    expect(contractContent).toContain("ERR_UNAUTHORIZED");
    expect(contractContent).toContain("ERR_INSUFFICIENT_BALANCE");
    expect(contractContent).toContain("ERR_INVALID_AMOUNT");
    expect(contractContent).toContain("ERR_LISTING_NOT_FOUND");
  });

  it("should have SIP-010 standard functions", () => {
    const contractPath = resolve("contracts/energy-trading.clar");
    const contractContent = readFileSync(contractPath, "utf8");
    
    expect(contractContent).toContain("get-name");
    expect(contractContent).toContain("get-symbol");
    expect(contractContent).toContain("get-decimals");
    expect(contractContent).toContain("get-balance");
    expect(contractContent).toContain("get-total-supply");
    expect(contractContent).toContain("transfer");
  });

  it("should have proper data structures", () => {
    const contractPath = resolve("contracts/energy-trading.clar");
    const contractContent = readFileSync(contractPath, "utf8");
    
    expect(contractContent).toContain("define-map energy-producers");
    expect(contractContent).toContain("define-map energy-listings");
    expect(contractContent).toContain("define-map production-records");
    expect(contractContent).toContain("define-map trading-history");
  });
});
