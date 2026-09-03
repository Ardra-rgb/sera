const { chromium } = require("playwright-core");

(async () => {
  const browserServer = await chromium.launchServer({
    channel: "chrome",
    headless: false,
    host: "127.0.0.1",
    port: 8080,
    wsPath: "/ws"
  });

  console.log("SERVER:", browserServer.wsEndpoint());

  const browser = await chromium.connect(browserServer.wsEndpoint());

  const page = await browser.newPage();

  await page.goto("https://example.com");

  console.log("PAGE:", await page.title());

  await new Promise(() => {});
})();