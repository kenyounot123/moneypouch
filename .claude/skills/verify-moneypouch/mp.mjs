#!/usr/bin/env node
import { spawn, spawnSync } from "node:child_process"
import fs from "node:fs"
import net from "node:net"
import path from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..")
const STATE_ROOT = path.join(ROOT, "tmp/verify")
const CHROME = process.env.MP_CHROME || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
].find(fs.existsSync)
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const die = (msg) => { console.error(`mp: ${msg}`); process.exit(1) }

const KEYS = {
  Enter: { code: "Enter", vk: 13, text: "\r" }, Escape: { code: "Escape", vk: 27 },
  Tab: { code: "Tab", vk: 9 }, Backspace: { code: "Backspace", vk: 8 }, Delete: { code: "Delete", vk: 46 },
  ArrowUp: { code: "ArrowUp", vk: 38 }, ArrowDown: { code: "ArrowDown", vk: 40 },
  ArrowLeft: { code: "ArrowLeft", vk: 37 }, ArrowRight: { code: "ArrowRight", vk: 39 },
  Home: { code: "Home", vk: 36 }, End: { code: "End", vk: 35 }, " ": { code: "Space", vk: 32, text: " " },
}
const MODS = { Alt: 1, Control: 2, Ctrl: 2, Meta: 4, Cmd: 4, Shift: 8 }

function freePort(from = 0) {
  return new Promise((resolve, reject) => {
    const srv = net.createServer()
    srv.once("error", reject)
    srv.listen(from, "127.0.0.1", () => { const { port } = srv.address(); srv.close(() => resolve(port)) })
  })
}
const portFree = (p) => freePort(p).then(() => true, () => false)
const alive = (pid) => { try { process.kill(pid, 0); return true } catch { return false } }
const dirFor = (port) => path.join(STATE_ROOT, String(port))
const readState = (port) => { try { return JSON.parse(fs.readFileSync(path.join(dirFor(port), "state.json"), "utf8")) } catch { return null } }
const writeState = (port, s) => { fs.mkdirSync(dirFor(port), { recursive: true }); fs.writeFileSync(path.join(dirFor(port), "state.json"), JSON.stringify(s, null, 2)) }

function parseArgs(argv) {
  const flags = {}, rest = []
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) {
      const key = argv[i].slice(2)
      const next = argv[i + 1]
      flags[key] = key === "port" ? argv[++i] : (next === undefined || next.startsWith("--") ? true : argv[++i])
    } else rest.push(argv[i])
  }
  return { flags, rest }
}

function resolvePort(flags) {
  if (flags.port) return Number(flags.port)
  if (process.env.MP_PORT) return Number(process.env.MP_PORT)
  const known = fs.existsSync(STATE_ROOT) ? fs.readdirSync(STATE_ROOT) : []
  const live = known.filter((p) => { const s = readState(p); return s && alive(s.serverPid) })
  if (live.length === 1) return Number(live[0])
  die(live.length ? `several instances running (${live.join(", ")}); pass --port N` : "no instance running; run: mp.mjs boot")
}

async function cdpSession(port) {
  const s = readState(port)
  if (!s || !alive(s.chromePid)) die(`no browser for port ${port}; run: mp.mjs boot --port ${port}`)
  const targets = await (await fetch(`http://127.0.0.1:${s.cdpPort}/json/list`)).json()
  const page = targets.find((t) => t.type === "page")
  const ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej })
  let id = 0
  const pending = new Map(), waiters = []
  ws.onmessage = ({ data }) => {
    const m = JSON.parse(data)
    if (m.id && pending.has(m.id)) {
      const { res, rej } = pending.get(m.id)
      pending.delete(m.id)
      m.error ? rej(new Error(m.error.message)) : res(m.result)
    } else if (m.method) waiters.filter((w) => w.method === m.method).forEach((w) => w.res(m.params))
  }
  const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })) })
  const once = (method, ms = 15000) => new Promise((res, rej) => {
    const timer = setTimeout(() => rej(new Error(`timeout waiting for ${method}`)), ms)
    waiters.push({ method, res: (p) => { clearTimeout(timer); res(p) } })
  })
  await send("Page.enable")
  const viewport = (v) => send("Emulation.setDeviceMetricsOverride", { width: v.width, height: v.height, deviceScaleFactor: 1, mobile: v.width < 500 })
  await viewport(s.viewport)
  const evaluate = async (expression) => {
    const r = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text)
    return r.result.value
  }
  const settle = async () => {
    await sleep(400)
    for (let i = 0; i < 50 && (await evaluate("document.readyState")) !== "complete"; i++) await sleep(100)
  }
  const goto = async (url) => { const loaded = once("Page.loadEventFired"); await send("Page.navigate", { url }); await loaded; await sleep(300) }
  const key = async (spec) => {
    const parts = spec.length > 1 ? spec.split("+") : [spec]
    const name = parts.pop()
    const modifiers = parts.reduce((m, p) => m | (MODS[p] ?? die(`unknown modifier ${p}`)), 0)
    const def = KEYS[name] ?? (name.length === 1
      ? { code: /[a-z]/i.test(name) ? `Key${name.toUpperCase()}` : "", vk: name.toUpperCase().charCodeAt(0), text: name }
      : die(`unknown key ${name}`))
    const text = modifiers & ~8 ? undefined : def.text
    const base = { key: name, code: def.code, windowsVirtualKeyCode: def.vk, modifiers }
    await send("Input.dispatchKeyEvent", { type: text ? "keyDown" : "rawKeyDown", ...base, text })
    await send("Input.dispatchKeyEvent", { type: "keyUp", ...base })
  }
  const focus = (selector) => evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); if (!e) return false; e.focus(); return true })()`)
  return { send, evaluate, goto, settle, key, focus, viewport, close: () => ws.close() }
}

async function signIn(b, port, user, password) {
  await b.goto(`http://localhost:${port}/`)
  if (!(await b.evaluate("location.pathname")).startsWith("/session")) return
  for (const [selector, value] of [["#username", user], ["#password", password]]) {
    await b.focus(selector)
    await b.send("Input.insertText", { text: value })
  }
  await b.key("Enter")
  for (let i = 0; i < 100; i++) {
    await sleep(100)
    try {
      if ((await b.evaluate("location.pathname + document.readyState")) !== "/session/newcomplete" && (await b.evaluate("document.readyState")) === "complete") break
    } catch {}
  }
  await b.settle()
}

function demoPassword() {
  const m = fs.readFileSync(path.join(ROOT, "db/seeds.rb"), "utf8").match(/demo_password\s*=\s*"([^"]+)"/)
  return m ? m[1] : die("demo_password not found in db/seeds.rb")
}

function rails(args) {
  const r = spawnSync("bin/rails", args, { cwd: ROOT, encoding: "utf8" })
  if (r.status !== 0) die(`bin/rails ${args[0]} failed\n${(r.stdout + r.stderr).split("\n").slice(0, 6).join("\n")}`)
  return r.stdout
}

async function waitUp(port, ms = 90000) {
  const end = Date.now() + ms
  while (Date.now() < end) {
    try { if ((await fetch(`http://127.0.0.1:${port}/up`)).status === 200) return } catch {}
    await sleep(300)
  }
  die(`server on ${port} did not answer /up within ${ms / 1000}s; see ${dirFor(port)}/server.log`)
}

async function boot(flags) {
  const port = flags.port ? Number(flags.port) : await (async () => { for (let p = 3100; ; p++) if (await portFree(p)) return p })()
  let s = readState(port)
  const ours = s && alive(s.serverPid)
  if (!ours && !(await portFree(port))) die(`port ${port} is in use by a process this skill did not start`)
  fs.mkdirSync(dirFor(port), { recursive: true })
  if (!ours) {
    if (!fs.existsSync(path.join(ROOT, "app/assets/builds/tailwind.css"))) rails(["tailwindcss:build"])
    rails(["db:prepare"])
    rails(["db:seed"])
    fs.rmSync(path.join(ROOT, `tmp/pids/verify-${port}.pid`), { force: true })
    const log = fs.openSync(path.join(dirFor(port), "server.log"), "a")
    const server = spawn("bin/rails", ["server", "-b", "127.0.0.1", "-p", String(port), "-P", `tmp/pids/verify-${port}.pid`], { cwd: ROOT, detached: true, stdio: ["ignore", log, log] })
    server.unref()
    s = { port, serverPid: server.pid, viewport: { width: 1280, height: 800 } }
    writeState(port, s)
  }
  await waitUp(port)
  if (!s.chromePid || !alive(s.chromePid)) {
    if (!CHROME) die("no Chrome found; set MP_CHROME to a Chrome or Chromium binary")
    const cdpPort = await freePort()
    const log = fs.openSync(path.join(dirFor(port), "chrome.log"), "a")
    const chrome = spawn(CHROME, ["--headless=new", `--remote-debugging-port=${cdpPort}`, `--user-data-dir=${path.join(dirFor(port), "profile")}`, "--no-first-run", "--no-default-browser-check", "about:blank"], { detached: true, stdio: ["ignore", log, log] })
    chrome.unref()
    s = { ...s, chromePid: chrome.pid, cdpPort }
    writeState(port, s)
    for (let i = 0; i < 100; i++) {
      try { await fetch(`http://127.0.0.1:${cdpPort}/json/version`); break } catch { await sleep(100) }
    }
  }
  const b = await cdpSession(port)
  await signIn(b, port, "demo", demoPassword())
  const url = await b.evaluate("location.href")
  b.close()
  if (new URL(url).pathname.startsWith("/session")) die(`sign-in failed, ended at ${url}`)
  console.log(`${url} port=${port} user=demo`)
}

async function stop(flags) {
  const port = resolvePort(flags)
  const s = readState(port)
  if (!s) return console.log(`nothing recorded for ${port}`)
  for (const pid of [s.chromePid, s.serverPid]) if (pid && alive(pid)) process.kill(pid, "SIGTERM")
  for (let i = 0; i < 50 && alive(s.serverPid); i++) await sleep(100)
  fs.rmSync(dirFor(port), { recursive: true, force: true })
  console.log(`stopped ${port}`)
}

async function doctor(flags) {
  const port = resolvePort(flags)
  const s = readState(port)
  const out = { port, serverAlive: !!s && alive(s.serverPid), chromeAlive: !!s && alive(s.chromePid) }
  try { out.up = (await fetch(`http://127.0.0.1:${port}/up`)).status } catch { out.up = null }
  if (out.chromeAlive) {
    const b = await cdpSession(port)
    out.url = await b.evaluate("location.href")
    out.theme = await b.evaluate("document.documentElement.dataset.theme")
    out.viewport = s.viewport
    b.close()
  }
  console.log(JSON.stringify(out))
  if (!out.serverAlive || out.up !== 200) process.exit(1)
}

const USAGE = `usage: mp.mjs <command> [--port N]
  boot [--port N]                    start server + headless Chrome, sign in as demo, print the Overview URL (idempotent)
  stop                               stop this instance and remove its state
  doctor                             print instance health as JSON, exit 1 if unhealthy
  goto <path>                        navigate, e.g. /session/new
  type <selector> <text> [--clear]   focus the element and type text key by key
  key <Key>                          Enter, Escape, Tab, ArrowDown, Backspace, a, Meta+k, Shift+Tab
  click <selector>                   click the element's center
  shot <file.png> [--full]           screenshot the viewport
  resize <w> <h>                     set the viewport, persists across commands
  theme light|dark                   click the sidebar theme button
  signin <user> <password>           sign in through the form
  signout                            DELETE /session and land on the sign-in page
  js <expr>                            evaluate JS in the page, print the JSON result
  text [selector]                    print visible text
  query <ruby>                       read-only Rails runner expression, writes raise`

async function main() {
  const { flags, rest } = parseArgs(process.argv.slice(2))
  const [cmd, ...args] = rest
  if (cmd === "boot") return boot(flags)
  if (cmd === "stop") return stop(flags)
  if (cmd === "doctor") return doctor(flags)
  if (cmd === "query") {
    if (!args[0]) die("query needs a Ruby expression")
    return console.log(rails(["runner", `puts ActiveRecord::Base.while_preventing_writes { (${args[0]}).inspect }`]).trim())
  }
  if (!["goto", "type", "key", "click", "shot", "resize", "theme", "signin", "signout", "js", "text"].includes(cmd)) {
    console.error(USAGE)
    process.exit(cmd ? 1 : 0)
  }
  const port = resolvePort(flags)
  const b = await cdpSession(port)
  const origin = `http://localhost:${port}`
  try {
    if (cmd === "goto") {
      await b.goto(new URL(args[0], origin).href)
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "type") {
      if (!(await b.focus(args[0]))) die(`no element matches ${args[0]}`)
      if (flags.clear) {
        await b.evaluate("document.activeElement.select()")
        await b.key("Backspace")
      }
      for (const ch of args[1]) await b.key(ch)
      console.log(JSON.stringify(await b.evaluate("document.activeElement.value")))
    } else if (cmd === "key") {
      await b.key(args[0])
      await sleep(200)
      console.log(`pressed ${args[0]}`)
    } else if (cmd === "click") {
      const box = await b.evaluate(`(() => { const e = document.querySelector(${JSON.stringify(args[0])}); if (!e) return null; e.scrollIntoView({ block: "center" }); const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 } })()`)
      if (!box) die(`no element matches ${args[0]}`)
      for (const type of ["mousePressed", "mouseReleased"]) await b.send("Input.dispatchMouseEvent", { type, ...box, button: "left", clickCount: 1 })
      await b.settle()
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "shot") {
      const { data } = await b.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: !!flags.full })
      fs.mkdirSync(path.dirname(path.resolve(args[0])), { recursive: true })
      fs.writeFileSync(args[0], Buffer.from(data, "base64"))
      console.log(path.resolve(args[0]))
    } else if (cmd === "resize") {
      const s = readState(port)
      s.viewport = { width: Number(args[0]), height: Number(args[1]) }
      writeState(port, s)
      await b.viewport(s.viewport)
      console.log(`${s.viewport.width}x${s.viewport.height} scrollWidth=${await b.evaluate("document.documentElement.scrollWidth")}`)
    } else if (cmd === "theme") {
      if (!["light", "dark"].includes(args[0])) die("theme takes light or dark")
      await b.goto(`${origin}/`)
      await b.evaluate(`document.querySelector('button[data-theme="${args[0]}"]')?.click()`)
      await b.settle()
      console.log(await b.evaluate("document.documentElement.dataset.theme"))
    } else if (cmd === "signin") {
      await signIn(b, port, args[0], args[1])
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "signout") {
      await b.goto(`${origin}/session/new`)
      await b.evaluate(`fetch("/session", { method: "DELETE", headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content } })`)
      await b.goto(`${origin}/session/new`)
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "js") {
      console.log(JSON.stringify(await b.evaluate(args[0])))
    } else if (cmd === "text") {
      console.log(await b.evaluate(`document.querySelector(${JSON.stringify(args[0] || "body")}).innerText`))
    }
  } finally {
    b.close()
  }
}
main().catch((e) => die(e.message))
