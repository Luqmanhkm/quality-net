import { describe, it, expect } from "vitest";
import { evaluateSpeedResult, DEFAULT_THRESHOLDS } from "./internetSpeedTest";

describe("evaluateSpeedResult", () => {
  it("passes when download, upload, and ping all meet the threshold", () => {
    const result = evaluateSpeedResult(10, 5, 100, DEFAULT_THRESHOLDS);
    expect(result).toBe(true);
  });

  it("upload of 1.04 Mbps now passes with the adjusted threshold (BUG-004 fix)", () => {
    // Kasus nyata dari audit: upload 1.04 Mbps dulu gagal saat threshold masih 4 Mbps,
    // sekarang lolos setelah threshold diturunkan jadi 1 Mbps.
    const result = evaluateSpeedResult(55.75, 1.04, 33, DEFAULT_THRESHOLDS);
    expect(result).toBe(true);
  });

  it("would have failed under the original threshold of 4 Mbps (documents the original bug)", () => {
      const originalThresholds = { ...DEFAULT_THRESHOLDS, minUploadMbps: 4 };
      const result = evaluateSpeedResult(55.75, 1.04, 33, originalThresholds);
      expect(result).toBe(false);
  });

  it("passes with the adjusted lower upload threshold", () => {
    const adjustedThresholds = { ...DEFAULT_THRESHOLDS, minUploadMbps: 1 };
    const result = evaluateSpeedResult(55.75, 1.04, 33, adjustedThresholds);
    expect(result).toBe(true);
  });

  it("fails when ping exceeds the max threshold", () => {
    const result = evaluateSpeedResult(20, 10, 500, DEFAULT_THRESHOLDS);
    expect(result).toBe(false);
  });

  it("fails when download is below the threshold", () => {
    const result = evaluateSpeedResult(2, 10, 50, DEFAULT_THRESHOLDS);
    expect(result).toBe(false);
  });
});