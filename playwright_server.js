const { chromium } = require("playwright-core");

(async () => {
  const browserServer = await chromium.launchServer({
    headless: false,
    host: "127.0.0.1",
    port: 8080,
    wsPath: "/ws"
  });

  console.log(browserServer.wsEndpoint());

  process.on("SIGINT", async () => {
    await browserServer.close();
    process.exit(0);
  });
})();