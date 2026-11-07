import { describe, expect, test } from "bun:test";

import { pendingSessionReader } from "./sessionReader.js";

describe("pendingSessionReader", () => {
  // covers: AC-5
  test("returns no principal for any token until sign in lands", async () => {
    expect(await pendingSessionReader.read("any-token")).toBeNull();
    expect(await pendingSessionReader.read("")).toBeNull();
  });
});
