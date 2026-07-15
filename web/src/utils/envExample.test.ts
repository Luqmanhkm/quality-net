import { describe, it, expect } from "vitest";
import { readFileSync } from "fs";
import { resolve } from "path";

describe(".env.example config sanity (regression test for BUG-001)", () => {
  const envExample = readFileSync(resolve(__dirname, "../../.env.example"), "utf-8");

  it("points VITE_API_BASE_URL to the backend's actual port (3001), not 3000", () => {
    expect(envExample).toMatch(/VITE_API_BASE_URL=http:\/\/localhost:3001\/api\/v1/);
  });

  it("points VITE_WS_BASE_URL to the backend's actual port (3001), not 3000", () => {
    expect(envExample).toMatch(/VITE_WS_BASE_URL=ws:\/\/localhost:3001/);
  });
});