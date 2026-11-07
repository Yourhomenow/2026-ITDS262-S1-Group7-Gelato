import { describe, expect, test } from "bun:test";

const SERVER_ROOT = new URL("../../", import.meta.url).pathname;

interface ConfigShape {
  clientsOrigin: string;
  sessionCookieName: string;
  port: number;
  env: string;
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string | undefined;
  };
}

const READ_CONFIG = `
import { config } from "./src/config/index.ts";
console.log(JSON.stringify(config));
`;

/**
 * The config module reads the environment once when it loads, so each case
 * runs in a fresh process with only the environment it is given.
 */
function readConfig(env: Record<string, string>): ConfigShape {
  const result = Bun.spawnSync({
    cmd: [process.execPath, "-e", READ_CONFIG],
    cwd: SERVER_ROOT,
    env: {
      PATH: process.env.PATH ?? "",
      HOME: process.env.HOME ?? "",
      ...env,
    },
    stdout: "pipe",
    stderr: "pipe",
  });

  if (result.exitCode !== 0) {
    throw new Error(`config process failed: ${result.stderr.toString()}`);
  }

  return JSON.parse(result.stdout.toString().trim()) as ConfigShape;
}

const EMPTY_HTTP_ENV = {
  CLIENTS_ORIGIN: "",
  SESSION_COOKIE_NAME: "",
  PORT: "",
  NODE_ENV: "",
};

describe("config defaults", () => {
  // covers: AC-8
  test("falls back to the documented HTTP and database defaults", () => {
    const config = readConfig(EMPTY_HTTP_ENV);

    expect(config.clientsOrigin).toBe("http://localhost:3000");
    expect(config.sessionCookieName).toBe("gelato_session");
    expect(config.port).toBe(3005);
    expect(config.env).toBe("development");
    expect(config.database).toMatchObject({
      host: "localhost",
      port: 5432,
      name: "gelato",
      user: "postgres",
    });
    expect(config.database.password).toBeUndefined();
  });

  // covers: AC-8
  test("reads the CORS origin, cookie name, port and node env from the environment", () => {
    const config = readConfig({
      CLIENTS_ORIGIN: "https://shop.example",
      SESSION_COOKIE_NAME: "custom_session",
      PORT: "4321",
      NODE_ENV: "production",
    });

    expect(config.clientsOrigin).toBe("https://shop.example");
    expect(config.sessionCookieName).toBe("custom_session");
    expect(config.port).toBe(4321);
    expect(config.env).toBe("production");
  });

  // covers: AC-8
  test("a non numeric PORT falls back to 3005", () => {
    const config = readConfig({ ...EMPTY_HTTP_ENV, PORT: "not-a-number" });

    expect(config.port).toBe(3005);
  });
});
